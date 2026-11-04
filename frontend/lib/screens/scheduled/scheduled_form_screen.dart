import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/utils/clock.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/occurrence.dart';
import '../../core/utils/validators.dart';
import '../../models/category.dart';
import '../../models/scheduled_transaction.dart';
import '../../providers/category_provider.dart';
import '../../providers/scheduled_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/confirm_delete_dialog.dart';

/// Màn hình thêm hoặc sửa giao dịch hẹn trước.
class ScheduledFormScreen extends StatefulWidget {
  final String? scheduledId;
  const ScheduledFormScreen({super.key, this.scheduledId});

  @override
  State<ScheduledFormScreen> createState() => _ScheduledFormScreenState();
}

class _ScheduledFormScreenState extends State<ScheduledFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _repeatEveryController = TextEditingController(text: '1');

  CategoryType _type = CategoryType.expense;
  String? _walletId;
  String? _categoryId;

  DateTime _date = DateTime.parse(businessToday());
  late TimeOfDay _time;

  bool _isRecurring = false;
  RepeatUnit _repeatUnit = RepeatUnit.month;
  DateTime? _endDate;

  ScheduledTransaction? _editing;
  bool _saving = false;
  String? _timeError;

  bool get isEditing => widget.scheduledId != null;

  @override
  void initState() {
    super.initState();
    final vn = DateTime.now().toUtc().add(const Duration(hours: 7, minutes: 5));
    _time = TimeOfDay(hour: vn.hour, minute: vn.minute);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wallets = context.read<WalletProvider>().wallets;
      if (wallets.isNotEmpty) {
        setState(() => _walletId ??= wallets.first.id);
      }

      if (isEditing) {
        final provider = context.read<ScheduledProvider>();
        final item =
            provider.items.where((s) => s.id == widget.scheduledId).firstOrNull;
        if (item == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Giao dịch hẹn trước không tồn tại')),
          );
          context.pop();
          return;
        }

        final timeParts = item.timeOfDay.split(':');
        setState(() {
          _editing = item;
          _type = item.type;
          _amountController.text = item.amount.toString();
          _walletId = item.walletId;
          _categoryId = item.categoryId;
          _noteController.text = item.note ?? '';
          _date = DateTime.parse(item.startDate);
          _time = TimeOfDay(
            hour: int.parse(timeParts[0]),
            minute: int.parse(timeParts[1]),
          );
          _isRecurring = item.isRecurring;
          _repeatUnit = item.repeatUnit ?? RepeatUnit.month;
          _repeatEveryController.text = (item.repeatEvery ?? 1).toString();
          _endDate =
              item.endDate != null ? DateTime.parse(item.endDate!) : null;
        });
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _repeatEveryController.dispose();
    super.dispose();
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  bool _isTimeUnchanged() {
    if (_editing == null) return false;
    return dateOnly(_date) == _editing!.startDate &&
        _formatTimeOfDay(_time) == _editing!.timeOfDay;
  }

  bool _validateTime() {
    if (isEditing && _isTimeUnchanged()) {
      _timeError = null;
      return true;
    }
    final today = businessToday();
    final d = dateOnly(_date);
    if (d.compareTo(today) < 0) {
      _timeError = 'Thời điểm hẹn phải ở tương lai';
      return false;
    }
    if (d == today) {
      final vn = DateTime.now().toUtc().add(const Duration(hours: 7));
      final nowMins = vn.hour * 60 + vn.minute;
      final pickedMins = _time.hour * 60 + _time.minute;
      if (pickedMins <= nowMins) {
        _timeError = 'Thời điểm hẹn phải ở tương lai';
        return false;
      }
    }
    _timeError = null;
    return true;
  }

  bool get _isScheduleModified {
    if (_editing == null) return false;
    if (dateOnly(_date) != _editing!.startDate) return true;
    if (_formatTimeOfDay(_time) != _editing!.timeOfDay) return true;
    if (_isRecurring != _editing!.isRecurring) return true;
    if (_isRecurring) {
      if (_repeatUnit != _editing!.repeatUnit) return true;
      final every = int.tryParse(_repeatEveryController.text.trim()) ?? 1;
      if (every != (_editing!.repeatEvery ?? 1)) return true;
      final endStr = _endDate != null ? dateOnly(_endDate!) : null;
      if (endStr != _editing!.endDate) return true;
    }
    return false;
  }

  Future<void> _pickDate() async {
    final today = DateTime.parse(businessToday());
    final initial = _date.isBefore(today) ? today : _date;
    final first = _date.isBefore(today) ? _date : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(2050),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        if (_endDate != null && _endDate!.isBefore(_date)) {
          _endDate = null;
        }
        _validateTime();
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) {
      setState(() {
        _time = picked;
        _validateTime();
      });
    }
  }

  Future<void> _pickEndDate() async {
    final initial =
        (_endDate != null && !_endDate!.isBefore(_date)) ? _endDate! : _date;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _date,
      lastDate: DateTime(2050),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate() || _walletId == null) {
      return;
    }
    final timeValid = _validateTime();
    if (!timeValid) {
      setState(() {});
      return;
    }

    setState(() => _saving = true);
    final provider = context.read<ScheduledProvider>();
    final amount = int.parse(_amountController.text.replaceAll(',', ''));
    final note = _noteController.text.trim().isEmpty
        ? null
        : _noteController.text.trim();
    final startDate = dateOnly(_date);
    final timeOfDay = _formatTimeOfDay(_time);
    final repeatUnit = _isRecurring ? _repeatUnit : null;
    final repeatEvery = _isRecurring
        ? (int.tryParse(_repeatEveryController.text.trim()) ?? 1)
        : null;
    final endDate =
        (_isRecurring && _endDate != null) ? dateOnly(_endDate!) : null;

    try {
      if (isEditing && _editing != null) {
        await provider.edit(
          id: _editing!.id,
          walletId: _walletId!,
          categoryId: _categoryId,
          type: _type,
          amount: amount,
          note: note,
          startDate: startDate,
          timeOfDay: timeOfDay,
          repeatUnit: repeatUnit,
          repeatEvery: repeatEvery,
          endDate: endDate,
        );
        if (mounted) context.pop();
      } else {
        final granted = await provider.add(
          walletId: _walletId!,
          categoryId: _categoryId,
          type: _type,
          amount: amount,
          note: note,
          startDate: startDate,
          timeOfDay: timeOfDay,
          repeatUnit: repeatUnit,
          repeatEvery: repeatEvery,
          endDate: endDate,
        );
        if (mounted) {
          if (!granted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Chưa cấp quyền thông báo. Bạn vẫn thấy nhắc khi mở app.'),
              ),
            );
          }
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (_editing == null) return;
    final confirmed = await confirmDelete(
      context,
      itemLabel: 'giao dịch hẹn trước này',
    );
    if (confirmed && mounted) {
      try {
        await context.read<ScheduledProvider>().remove(_editing!.id);
        if (mounted) context.pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallets = context.watch<WalletProvider>().wallets;
    if (!isEditing && wallets.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Giao dịch hẹn trước mới')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 64,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Bạn cần có ít nhất 1 ví',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Hãy tạo ví trước khi lên lịch hẹn.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.push(AppRoutes.walletAdd),
                  icon: const Icon(Icons.add),
                  label: const Text('Tạo ví mới'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_walletId == null && !isEditing && wallets.isNotEmpty) {
      _walletId = wallets.first.id;
    }

    final categories = context.watch<CategoryProvider>();
    final categoryOptions = _type == CategoryType.income
        ? categories.incomeCategories
        : categories.expenseCategories;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            isEditing ? 'Sửa giao dịch hẹn trước' : 'Thêm giao dịch hẹn trước'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Xóa',
              onPressed: _delete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. SegmentedButton Chi tiêu | Thu nhập
              SegmentedButton<CategoryType>(
                segments: const [
                  ButtonSegment(
                    value: CategoryType.expense,
                    label: Text('Chi tiêu'),
                  ),
                  ButtonSegment(
                    value: CategoryType.income,
                    label: Text('Thu nhập'),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() {
                  _type = s.first;
                  _categoryId = null;
                }),
              ),
              const SizedBox(height: 16),

              // 2. Số tiền
              AppTextField(
                label: 'Số tiền',
                controller: _amountController,
                keyboardType: TextInputType.number,
                validator: Validators.positiveAmount,
              ),
              const SizedBox(height: 14),

              // 3. Dropdown Ví
              DropdownButtonFormField<String>(
                initialValue:
                    wallets.any((w) => w.id == _walletId) ? _walletId : null,
                decoration: const InputDecoration(labelText: 'Ví'),
                items: wallets
                    .map((w) => DropdownMenuItem(
                          value: w.id,
                          child: Text(w.walletName),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _walletId = v),
                validator: (v) => v == null ? 'Vui lòng chọn ví' : null,
              ),
              const SizedBox(height: 14),

              // 4. Dropdown Danh mục
              DropdownButtonFormField<String?>(
                initialValue: categoryOptions.any((c) => c.id == _categoryId)
                    ? _categoryId
                    : null,
                decoration:
                    const InputDecoration(labelText: 'Danh mục (tùy chọn)'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Không có danh mục'),
                  ),
                  ...categoryOptions.map((c) => DropdownMenuItem<String?>(
                        value: c.id,
                        child: Text(c.categoryName),
                      )),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              const SizedBox(height: 14),

              // 5. Ghi chú
              AppTextField(
                label: 'Ghi chú (tùy chọn)',
                controller: _noteController,
                maxLines: 2,
              ),
              const SizedBox(height: 14),

              // 6. Ngày hẹn và Giờ
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Ngày hẹn',
                      controller:
                          TextEditingController(text: Formatters.date(_date)),
                      readOnly: true,
                      onTap: _pickDate,
                      prefixIcon: const Icon(Icons.calendar_today_outlined),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextField(
                          label: 'Giờ hẹn',
                          controller: TextEditingController(
                              text: _formatTimeOfDay(_time)),
                          readOnly: true,
                          onTap: _pickTime,
                          prefixIcon: const Icon(Icons.access_time_outlined),
                        ),
                        if (_timeError != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            _timeError!,
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 7. Checkbox Lặp lại
              CheckboxListTile(
                title: const Text('Lặp lại'),
                value: _isRecurring,
                onChanged: (v) => setState(() => _isRecurring = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),

              if (_isRecurring) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _repeatEveryController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Lặp mỗi'),
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          if (!_isRecurring) return null;
                          final n = int.tryParse(v ?? '');
                          if (n == null || n < 1 || n > 365) {
                            return '1 - 365';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<RepeatUnit>(
                        initialValue: _repeatUnit,
                        decoration: const InputDecoration(labelText: 'Đơn vị'),
                        items: const [
                          DropdownMenuItem(
                              value: RepeatUnit.day, child: Text('Ngày')),
                          DropdownMenuItem(
                              value: RepeatUnit.week, child: Text('Tuần')),
                          DropdownMenuItem(
                              value: RepeatUnit.month, child: Text('Tháng')),
                          DropdownMenuItem(
                              value: RepeatUnit.year, child: Text('Năm')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _repeatUnit = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Ngày kết thúc (tùy chọn)',
                  controller: TextEditingController(
                    text: _endDate != null ? Formatters.date(_endDate!) : '',
                  ),
                  readOnly: true,
                  onTap: _pickEndDate,
                  prefixIcon: const Icon(Icons.event_busy_outlined),
                ),
                if (_endDate != null) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _endDate = null),
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('Xóa ngày kết thúc (lặp mãi mãi)'),
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 24),

              // 8. Nút "Thêm giao dịch hẹn trước" / "Lưu thay đổi"
              ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: Text(
                  isEditing ? 'Lưu thay đổi' : 'Thêm giao dịch hẹn trước',
                ),
              ),

              if (isEditing && _isScheduleModified) ...[
                const SizedBox(height: 12),
                const Text(
                  'Đổi lịch sẽ tính lại từ ngày hẹn mới',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
