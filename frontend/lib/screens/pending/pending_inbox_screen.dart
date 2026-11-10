import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/sms/sms_reader.dart';
import '../../core/utils/clock.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ledger_refresh.dart';
import '../../models/category.dart';
import '../../models/pending_transaction.dart';
import '../../models/wallet.dart';
import '../../providers/category_provider.dart';
import '../../providers/pending_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../repositories/pending_transaction_repository.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/item_action_sheet.dart';
import '../../widgets/quick_action_button.dart';

class PendingInboxScreen extends StatefulWidget {
  final String? autoAction;
  const PendingInboxScreen({super.key, this.autoAction});

  @override
  State<PendingInboxScreen> createState() => _PendingInboxScreenState();
}

class _PendingInboxScreenState extends State<PendingInboxScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<PendingProvider>();
      await provider.load();
      if (mounted) {
        await provider.retryNeedsAi();
      }
      if (mounted && widget.autoAction != null) {
        if (widget.autoAction == 'sms') {
          _scanSms();
        } else if (widget.autoAction == 'image') {
          _scanImage();
        }
      }
    });
  }

  Future<void> _refresh() async {
    await context.read<PendingProvider>().retryNeedsAi();
  }

  Future<void> _scanSms() async {
    final provider = context.read<PendingProvider>();
    if (await SmsReader.status() != SmsPermission.granted) {
      if (!mounted) return;
      final confirmed = await showAppConfirm(
        context,
        title: 'Cấp quyền SMS',
        message:
            'Ứng dụng chỉ đọc SMS khi bạn bấm quét, chỉ lấy tin giống giao dịch '
            'trong 30 ngày gần đây. Số tài khoản, số thẻ, số điện thoại và số dư '
            'được che trước khi gửi phân tích. Nội dung gốc không được lưu.\n\n'
            'Bạn vẫn có thể dán tin nhắn thủ công mà không cần cấp quyền.',
        cancelLabel: 'Để sau',
        confirmLabel: 'Cấp quyền',
      );
      if (confirmed != true || !mounted) return;
    }

    final result = await provider.scanSms();
    if (!mounted) return;
    switch (result.status) {
      case SmsScanStatus.busy:
        break;
      case SmsScanStatus.denied:
        _show('Chưa cấp quyền đọc SMS. Bạn vẫn có thể dán tin nhắn.');
        break;
      case SmsScanStatus.permanentlyDenied:
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Quyền SMS đang bị chặn.'),
              action: SnackBarAction(
                label: 'Mở cài đặt',
                onPressed: openAppSettings,
              ),
            ),
          );
        break;
      case SmsScanStatus.error:
        _show('Không đọc được SMS. Thử lại hoặc dùng cách dán tin nhắn.');
        break;
      case SmsScanStatus.done:
        _show(_scanMessage(provider, result));
        break;
    }
  }

  Future<void> _scanImage() async {
    final provider = context.read<PendingProvider>();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    XFile? file;
    try {
      // Don't set maxHeight: long receipts need their full vertical detail.
      file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
    } catch (_) {
      if (mounted) _show('Không mở được camera hoặc thư viện ảnh.');
      return;
    }
    if (file == null || !mounted) return;

    final path = file.path;
    try {
      final agreed = await showAppConfirm(
        context,
        title: 'Xử lý hình ảnh',
        message:
            'Ảnh được gửi qua máy chủ của ứng dụng tới Google Gemini để đọc số tiền, ngày và nội dung. '
            'Ứng dụng và máy chủ không lưu ảnh sau khi phân tích.\n\n'
            'Số tài khoản, số điện thoại hay thông tin khác nằm trong ảnh có thể bị gửi đi, '
            'hãy che trước nếu cần. Cần có kết nối mạng.',
        cancelLabel: 'Hủy',
        confirmLabel: 'Tiếp tục',
      );
      if (agreed != true || !mounted) return;
      final bytes = await file.readAsBytes();
      final result = await provider.submitImage(bytes);
      if (mounted) _show(_imageMessage(result.status));
    } finally {
      await _deleteTemp(path);
    }
  }

  Future<void> _deleteTemp(String path) async {
    try {
      final tempPath = (await getTemporaryDirectory()).path;
      if (path.startsWith(tempPath)) await File(path).delete();
    } catch (_) {
      // The picker owns its cache cleanup if this best-effort delete fails.
    }
  }

  String _imageMessage(ImageRunStatus status) => switch (status) {
        ImageRunStatus.added =>
          'Đã thêm đề xuất từ ảnh. Kiểm tra rồi xác nhận.',
        ImageRunStatus.duplicate => 'Ảnh này đã được xử lý trước đó.',
        ImageRunStatus.notTransaction => 'Không nhận ra giao dịch trong ảnh.',
        ImageRunStatus.failed => 'Chưa đọc được ảnh. Thử ảnh rõ hơn.',
        ImageRunStatus.offline => 'Cần có mạng để phân tích ảnh.',
        ImageRunStatus.rateLimited =>
          'AI đang giới hạn lượt gọi, thử lại sau ít phút.',
        ImageRunStatus.unavailable =>
          'Dịch vụ AI tạm thời không khả dụng, thử lại sau.',
        ImageRunStatus.unauthorized =>
          'Phiên đăng nhập hết hạn, hãy đăng nhập lại.',
        ImageRunStatus.tooLarge => 'Ảnh quá lớn (tối đa 3MB). Thử ảnh khác.',
        ImageRunStatus.unsupported => 'Chỉ hỗ trợ ảnh JPEG, PNG hoặc WebP.',
        ImageRunStatus.busy => 'Đang xử lý, đợi một chút.',
        ImageRunStatus.error => 'Có lỗi, vui lòng thử lại.',
      };

  String _scanMessage(PendingProvider provider, SmsScanResult result) {
    if (result.added == 0) {
      return 'Không có tin giao dịch mới trong 30 ngày gần đây';
    }
    final base = 'Thêm ${result.added} tin giao dịch';
    switch (provider.lastRun) {
      case AiRunResult.offline:
        return '$base. Chưa có mạng, sẽ phân tích sau';
      case AiRunResult.rateLimited:
      case AiRunResult.unavailable:
        return '$base. AI đang quá tải, bấm Thử lại sau';
      default:
        return base;
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _reject(String id) async {
    try {
      await context.read<PendingProvider>().reject(id);
    } catch (e) {
      if (mounted) _show(_cleanError(e));
    }
  }

  void _openEditForm(PendingTransaction item) {
    final wallets = context.read<WalletProvider>().wallets;
    if (wallets.isEmpty) {
      _show('Bạn cần tạo ví trước khi xác nhận giao dịch.');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      builder: (ctx) => _PendingEditSheet(
        item: item,
        wallets: wallets,
      ),
    );
  }

  static String _cleanError(Object e) {
    String msg = e.toString();
    for (final prefix in [
      'Exception: ',
      'ArgumentError: ',
      'Invalid argument(s): ',
      'StateError: '
    ]) {
      if (msg.startsWith(prefix)) {
        msg = msg.substring(prefix.length);
      }
    }
    return msg;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PendingProvider>();
    final categories = context.watch<CategoryProvider>();

    final hasPending = provider.pending.isNotEmpty;
    final hasNeedsAi = provider.needsAi.isNotEmpty;
    final isEmpty = !hasPending && !hasNeedsAi;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hộp thư chờ duyệt'),
        bottom: provider.busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: QuickActionButton(
                      icon: Icons.sms_outlined,
                      label: 'Quét SMS',
                      onTap: provider.busy ? null : _scanSms,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: QuickActionButton(
                      icon: Icons.receipt_long_outlined,
                      label: 'Chụp hóa đơn',
                      onTap: provider.busy ? null : _scanImage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: QuickActionButton(
                      key: const ValueKey('paste_message_fab'),
                      icon: Icons.content_paste,
                      label: 'Dán tin nhắn',
                      onTap: () => context.push(
                        '${AppRoutes.pasteMessage}?fromInbox=true',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 80),
                        EmptyState(
                          icon: Icons.inbox_outlined,
                          title: 'Hộp thư trống',
                          subtitle:
                              'Chưa có đề xuất. Hãy quét SMS, chụp hóa đơn hoặc dán tin nhắn ở trên.',
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      children: [
                        if (hasPending) ...[
                          _SectionHeader(
                            title: 'Đề xuất cần bạn xác nhận',
                            count: provider.pending.length,
                          ),
                          for (final item in provider.pending)
                            _PendingItemCard(
                              item: item,
                              categoryName: categories
                                  .byId(item.suggestedCategoryId)
                                  ?.categoryName,
                              onConfirm: () => _openEditForm(item),
                              onReject: () => _reject(item.id),
                            ),
                          const SizedBox(height: 16),
                        ],
                        if (hasNeedsAi) ...[
                          _SectionHeader(
                            title: 'Đang chờ phân tích',
                            count: provider.needsAi.length,
                          ),
                          for (final item in provider.needsAi)
                            _NeedsAiCard(
                              item: item,
                              onRetry: provider.busy ? null : _refresh,
                              onReject: () => _reject(item.id),
                            ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          Badge.count(count: count),
        ],
      ),
    );
  }
}

class _PendingItemCard extends StatelessWidget {
  final PendingTransaction item;
  final String? categoryName;
  final VoidCallback onConfirm;
  final VoidCallback onReject;

  const _PendingItemCard({
    required this.item,
    required this.categoryName,
    required this.onConfirm,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = item.type == CategoryType.income;
    final typeColor = isIncome ? AppColors.income : AppColors.expense;
    final typeLabel = isIncome ? 'Thu nhập' : 'Chi tiêu';

    final conf = item.confidence;
    final isLowConfidence = conf != null && conf < 0.6;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onConfirm,
        onLongPress: () => _showActions(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      typeLabel,
                      style: TextStyle(
                        color: typeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      Formatters.currency(item.amount ?? 0),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: typeColor,
                          ),
                    ),
                  ),
                  if (conf != null)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      labelPadding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: -2),
                      label: Text(
                        '${(conf * 100).round()}%',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isLowConfidence ? const Color(0xFFB45309) : null,
                          fontWeight: isLowConfidence ? FontWeight.bold : null,
                        ),
                      ),
                      backgroundColor: isLowConfidence
                          ? AppColors.warning.withValues(alpha: 0.2)
                          : null,
                      side: isLowConfidence
                          ? const BorderSide(color: AppColors.warning)
                          : null,
                    ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textSecondary),
                    onPressed: () => _showActions(context),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (item.note?.isNotEmpty == true)
                Text(
                  item.note!,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                )
              else if (item.maskedContent.isNotEmpty)
                Text(
                  item.maskedContent,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (item.transactionDate != null) ...[
                    Icon(Icons.calendar_today,
                        size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      Formatters.date(item.transactionDate!),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (categoryName != null) ...[
                    Icon(Icons.category_outlined,
                        size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        categoryName!,
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: onReject,
                        child: const Text('Bỏ qua'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: onConfirm,
                        child: const Text('Kiểm tra'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    final title = item.note?.isNotEmpty == true
        ? item.note!
        : (categoryName ?? 'Đề xuất giao dịch');
    showItemActionSheet(
      context,
      title: title,
      actions: [
        ItemAction(
          Icons.fact_check_outlined,
          'Kiểm tra',
          onConfirm,
        ),
        ItemAction(
          Icons.delete_outline,
          'Bỏ qua',
          onReject,
          danger: true,
        ),
      ],
    );
  }
}

class _NeedsAiCard extends StatelessWidget {
  final PendingTransaction item;
  final VoidCallback? onRetry;
  final VoidCallback onReject;

  const _NeedsAiCard({
    required this.item,
    required this.onRetry,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.maskedContent,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onReject,
                  child: const Text('Bỏ'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onRetry,
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingEditSheet extends StatefulWidget {
  final PendingTransaction item;
  final List<Wallet> wallets;

  const _PendingEditSheet({
    required this.item,
    required this.wallets,
  });

  @override
  State<_PendingEditSheet> createState() => _PendingEditSheetState();
}

class _PendingEditSheetState extends State<_PendingEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late CategoryType _selectedType;
  late String _selectedWalletId;
  late String? _selectedCategoryId;
  late DateTime _selectedDate;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.item.amount?.toString() ?? '',
    );
    _noteController = TextEditingController(
      text: widget.item.note ?? '',
    );
    _selectedType = widget.item.type ?? CategoryType.expense;
    _selectedWalletId = widget.wallets.first.id;

    final today = DateTime.parse(businessToday());
    final itemDate = widget.item.transactionDate;
    if (itemDate != null && itemDate.isAfter(today)) {
      _selectedDate = today;
    } else {
      _selectedDate = itemDate ?? today;
    }

    _selectedCategoryId = widget.item.suggestedCategoryId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateTime.parse(businessToday());
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(today) ? today : _selectedDate,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _handleConfirm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final amount = int.tryParse(
          _amountController.text.replaceAll(RegExp(r'[^0-9]'), ''));
      if (amount == null || amount <= 0) {
        throw ArgumentError('Số tiền không hợp lệ');
      }

      await context.read<PendingProvider>().confirm(
            pendingId: widget.item.id,
            walletId: _selectedWalletId,
            amount: amount,
            type: _selectedType,
            date: _selectedDate,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
            categoryId: _selectedCategoryId,
          );

      if (!mounted) return;
      Navigator.of(context).pop();

      await LedgerRefresh.all(context).run();

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Đã tạo giao dịch')),
          );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(_PendingInboxScreenState._cleanError(e))),
          );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _handleReject() async {
    setState(() => _submitting = true);
    try {
      await context.read<PendingProvider>().reject(widget.item.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(_PendingInboxScreenState._cleanError(e))),
          );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allCategories = context.watch<CategoryProvider>().categories;
    final availableCategories = allCategories
        .where((c) => c.type == _selectedType && !c.isDeleted)
        .toList();

    final validCategoryId =
        availableCategories.any((c) => c.id == _selectedCategoryId)
            ? _selectedCategoryId
            : null;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Kiểm tra & xác nhận',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentedButton<CategoryType>(
                        segments: const [
                          ButtonSegment(
                            value: CategoryType.expense,
                            label: Text('Chi tiêu'),
                            icon: Icon(Icons.north_east),
                          ),
                          ButtonSegment(
                            value: CategoryType.income,
                            label: Text('Thu nhập'),
                            icon: Icon(Icons.south_west),
                          ),
                        ],
                        selected: {_selectedType},
                        onSelectionChanged: (set) {
                          setState(() {
                            _selectedType = set.first;
                            if (_selectedCategoryId != null) {
                              final exists = allCategories.any((c) =>
                                  c.id == _selectedCategoryId &&
                                  c.type == _selectedType);
                              if (!exists) _selectedCategoryId = null;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Số tiền *',
                          border: OutlineInputBorder(),
                          suffixText: 'VND',
                        ),
                        validator: (value) {
                          final v = int.tryParse(
                              value?.replaceAll(RegExp(r'[^0-9]'), '') ?? '');
                          if (v == null || v <= 0) {
                            return 'Nhập số tiền lớn hơn 0';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedWalletId,
                        decoration: const InputDecoration(
                          labelText: 'Ví *',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final wallet in widget.wallets)
                            DropdownMenuItem(
                              value: wallet.id,
                              child: Text(wallet.walletName),
                            ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedWalletId = val);
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String?>(
                        key: ValueKey(_selectedType),
                        initialValue: validCategoryId,
                        decoration: const InputDecoration(
                          labelText: 'Danh mục',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Không chọn danh mục'),
                          ),
                          for (final cat in availableCategories)
                            DropdownMenuItem<String?>(
                              value: cat.id,
                              child: Text(cat.categoryName),
                            ),
                        ],
                        onChanged: (val) =>
                            setState(() => _selectedCategoryId = val),
                      ),
                      const SizedBox(height: 14),
                      ListTile(
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        title: const Text('Ngày giao dịch'),
                        subtitle: Text(Formatters.date(_selectedDate)),
                        trailing: const Icon(Icons.calendar_month),
                        onTap: _pickDate,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _noteController,
                        maxLength: 200,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Ghi chú',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting ? null : _handleReject,
                      child: const Text('Bỏ qua'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submitting ? null : _handleConfirm,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Xác nhận'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
