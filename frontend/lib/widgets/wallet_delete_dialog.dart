import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_routes.dart';
import '../core/utils/formatters.dart';
import '../core/utils/ledger_refresh.dart';
import '../providers/wallet_provider.dart';
import '../repositories/wallet_repository.dart';

/// Opens the cascade delete preview dialog and coordinates deletion,
/// reloading affected providers, and navigating based on remaining wallets.
Future<void> confirmAndDeleteWallet(
  BuildContext context, {
  required String walletId,
  required String walletName,
}) async {
  final walletProvider = context.read<WalletProvider>();
  final nav = Navigator.of(context, rootNavigator: true);
  final router = GoRouter.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final refresh = LedgerRefresh.all(context);

  void showError(Object error) {
    if (!messenger.mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(error.toString().replaceFirst('Exception: ', '')),
      backgroundColor: AppColors.danger,
    ));
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _LoadingDialog('Đang kiểm tra dữ liệu liên quan...'),
  );

  WalletDeletePreview? preview;
  try {
    preview = await walletProvider.previewDelete(walletId);
  } catch (e) {
    showError(e);
  } finally {
    nav.pop();
  }
  if (preview == null || !context.mounted) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) =>
        WalletDeleteDialog(walletName: walletName, preview: preview!),
  );
  if (confirmed != true || !context.mounted) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _LoadingDialog('Đang xóa ví và cập nhật dữ liệu...'),
  );

  var deleted = false;
  try {
    await walletProvider.deleteWallet(walletId);
    await refresh.run();
    deleted = true;
  } catch (e) {
    showError(e);
  } finally {
    nav.pop();
  }

  if (!deleted) return;
  router.go(walletProvider.wallets.isEmpty
      ? AppRoutes.walletCreateRequired
      : AppRoutes.wallets);
}

class _LoadingDialog extends StatelessWidget {
  final String message;
  const _LoadingDialog(this.message);

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(message,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ),
      );
}

class WalletDeleteDialog extends StatefulWidget {
  final String walletName;
  final WalletDeletePreview preview;

  const WalletDeleteDialog({
    super.key,
    required this.walletName,
    required this.preview,
  });

  @override
  State<WalletDeleteDialog> createState() => _WalletDeleteDialogState();
}

class _WalletDeleteDialogState extends State<WalletDeleteDialog> {
  int _secondsLeft = 0;
  Timer? _timer;

  bool get _hasCascadeData =>
      widget.preview.transactionCount > 0 ||
      widget.preview.transferCount > 0 ||
      widget.preview.counterparts.isNotEmpty ||
      widget.preview.deletedGoals.isNotEmpty ||
      widget.preview.affectedGoals.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_hasCascadeData) {
      _secondsLeft = 6;
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        if (_secondsLeft > 1) {
          setState(() => _secondsLeft--);
        } else {
          timer.cancel();
          setState(() => _secondsLeft = 0);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;
    final hasCascadeData = _hasCascadeData;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: AppColors.danger, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Xác nhận xóa ví',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bạn có chắc muốn xóa ví "${widget.walletName}"? Hành động này không thể hoàn tác.',
                style:
                    const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              if (hasCascadeData) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dữ liệu sau sẽ bị ảnh hưởng:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.danger,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (preview.transactionCount > 0) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text:
                                          '${preview.transactionCount} giao dịch thu/chi',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    const TextSpan(
                                        text: ' sẽ bị xóa (tổng thu '),
                                    TextSpan(
                                      text: Formatters.currency(
                                          preview.incomeTotal),
                                      style: const TextStyle(
                                        color: AppColors.income,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const TextSpan(text: ', tổng chi '),
                                    TextSpan(
                                      text: Formatters.currency(
                                          preview.expenseTotal),
                                      style: const TextStyle(
                                        color: AppColors.expense,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const TextSpan(
                                        text:
                                            '), số liệu thống kê sẽ thay đổi.'),
                                  ],
                                ),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      if (preview.transferCount > 0) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(
                                '${preview.transferCount} lượt chuyển tiền sẽ bị xóa.',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      if (preview.counterparts.isNotEmpty) ...[
                        const Text(
                          'Số dư ví đối ứng sẽ thay đổi:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        for (final cp in preview.counterparts)
                          Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 4),
                            child: Row(
                              children: [
                                const Text('→ ',
                                    style: TextStyle(
                                        color: AppColors.textSecondary)),
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                            text:
                                                'Ví ${cp.walletName}: số dư thay đổi '),
                                        TextSpan(
                                          text:
                                              '${cp.balanceDelta > 0 ? '+' : ''}${Formatters.currency(cp.balanceDelta)}',
                                          style: TextStyle(
                                            color: cp.balanceDelta < 0
                                                ? AppColors.expense
                                                : AppColors.income,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 6),
                      ],
                      if (preview.deletedGoals.isNotEmpty) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(
                                'Mục tiêu sẽ bị xóa: ${preview.deletedGoals.join(', ')}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      if (preview.affectedGoals.isNotEmpty) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(
                                'Tiến độ mục tiêu thay đổi: ${preview.affectedGoals.join(', ')}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Hủy',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.divider,
            disabledForegroundColor: AppColors.textSecondary,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed:
              _secondsLeft > 0 ? null : () => Navigator.of(context).pop(true),
          child: Text(
            _secondsLeft > 0 ? 'Đồng ý xóa ($_secondsLeft)' : 'Đồng ý xóa',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
