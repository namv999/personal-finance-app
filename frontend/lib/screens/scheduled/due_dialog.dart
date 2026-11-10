import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ledger_refresh.dart';
import '../../core/utils/validators.dart';
import '../../models/category.dart';
import '../../providers/category_provider.dart';
import '../../providers/scheduled_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../repositories/scheduled_transaction_repository.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_text_field.dart';

/// Hiển thị hộp thoại xử lý các giao dịch hẹn trước đã đến hạn.
Future<void> showDueDialog(BuildContext context) async {
  final provider = context.read<ScheduledProvider>();
  if (provider.due.isEmpty) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const DueDialog(),
  );
}

class DueDialog extends StatefulWidget {
  const DueDialog({super.key});

  @override
  State<DueDialog> createState() => _DueDialogState();
}

class _DueDialogState extends State<DueDialog> {
  final _amountController = TextEditingController();
  String? _lastKey;
  bool _processing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _confirm(DueOccurrence occurrence) async {
    if (_processing) return;
    final amountValidation = Validators.positiveAmount(_amountController.text);
    if (amountValidation != null) {
      setState(() => _errorMessage = amountValidation);
      return;
    }
    final amount = int.parse(_amountController.text.replaceAll(',', ''));
    setState(() {
      _processing = true;
      _errorMessage = null;
    });

    final provider = context.read<ScheduledProvider>();
    final refresh = LedgerRefresh.all(context);

    try {
      await provider.confirm(occurrence, amount: amount);
      await refresh.run();
      if (!mounted) return;
      if (provider.due.isEmpty && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _cancel(DueOccurrence occurrence) async {
    if (_processing) return;
    setState(() {
      _processing = true;
      _errorMessage = null;
    });

    final provider = context.read<ScheduledProvider>();
    try {
      await provider.cancel(occurrence);
      if (!mounted) return;
      if (provider.due.isEmpty && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _skipAll(int count) async {
    if (_processing) return;
    final confirmed = await showAppConfirm(
      context,
      title: 'Bỏ qua các kỳ đã lỡ',
      message: 'Bỏ qua $count kỳ?',
      cancelLabel: 'Quay lại',
      confirmLabel: 'Bỏ qua',
      danger: true,
    );

    if (confirmed == true && mounted) {
      setState(() {
        _processing = true;
        _errorMessage = null;
      });
      final provider = context.read<ScheduledProvider>();
      try {
        await provider.skipAllDue();
        if (!mounted) return;
        if (provider.due.isEmpty && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = e.toString().replaceFirst('Exception: ', '');
          });
        }
      } finally {
        if (mounted) setState(() => _processing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Consumer<ScheduledProvider>(
        builder: (context, provider, _) {
          final due = provider.due;
          if (due.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            });
            return const SizedBox.shrink();
          }

          final occurrence = due.first;
          if (_lastKey != occurrence.key) {
            _lastKey = occurrence.key;
            _amountController.text = occurrence.item.amount.toString();
            _errorMessage = null;
          }

          final wallets = context.watch<WalletProvider>().wallets;
          final categories = context.watch<CategoryProvider>();
          final wallet =
              wallets.where((w) => w.id == occurrence.item.walletId).firstOrNull;
          final walletName = wallet?.walletName ?? 'Ví không xác định';
          final category = categories.byId(occurrence.item.categoryId);
          final categoryName = category?.categoryName;
          final isIncome = occurrence.item.type == CategoryType.income;
          final typeLabel = isIncome ? 'Thu nhập' : 'Chi tiêu';
          final typeColor = isIncome ? AppColors.income : AppColors.expense;
          final formattedDateTime =
              '${Formatters.date(DateTime.parse(occurrence.date))} ${occurrence.item.timeOfDay}';
          final note = occurrence.item.note;

          return AlertDialog(
            title: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Giao dịch hẹn trước đến hạn',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                if (due.length > 1) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '1/${due.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (note != null && note.trim().isNotEmpty) ...[
                    Text(
                      note.trim(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          typeLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: typeColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          walletName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (categoryName != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Danh mục: $categoryName',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'Thời điểm: $formattedDateTime',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Số tiền',
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    validator: Validators.positiveAmount,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Chỉ bỏ qua kỳ này, chuỗi lặp vẫn chạy tiếp.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (_processing) ...[
                    const SizedBox(height: 12),
                    const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed:
                                _processing ? null : () => _cancel(occurrence),
                            child: const Text('Bỏ qua'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: FilledButton(
                            onPressed:
                                _processing ? null : () => _confirm(occurrence),
                            child: const Text('Xác nhận'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (due.length > 1) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed:
                          _processing ? null : () => _skipAll(due.length),
                      child: const Text(
                        'Bỏ qua tất cả',
                        style: TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
