import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/occurrence.dart';
import '../../models/category.dart';
import '../../models/scheduled_transaction.dart';
import '../../providers/category_provider.dart';
import '../../providers/scheduled_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/confirm_delete_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/icon_color_picker.dart';
import '../../widgets/loading_view.dart';

/// Màn hình danh sách giao dịch hẹn trước.
class ScheduledListScreen extends StatelessWidget {
  const ScheduledListScreen({super.key});

  static String _formatNextDue(ScheduledTransaction item) {
    if (item.isFinished || item.nextDueDate == null) {
      return 'Đã hoàn tất';
    }
    final date = DateTime.parse(item.nextDueDate!);
    return '${Formatters.date(date)} ${item.timeOfDay}';
  }

  static String _formatRepeat(ScheduledTransaction item) {
    if (!item.isRecurring || item.repeatUnit == null) {
      return 'Một lần';
    }
    final unitName = switch (item.repeatUnit!) {
      RepeatUnit.day => 'ngày',
      RepeatUnit.week => 'tuần',
      RepeatUnit.month => 'tháng',
      RepeatUnit.year => 'năm',
    };
    final every = item.repeatEvery ?? 1;
    var text = every == 1 ? 'Mỗi $unitName' : 'Mỗi $every $unitName';
    if (item.endDate != null) {
      final end = DateTime.parse(item.endDate!);
      text += ', đến ${Formatters.date(end)}';
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduledProvider>();
    final categories = context.watch<CategoryProvider>();
    final wallets = context.watch<WalletProvider>().wallets;

    final Widget body;
    if (provider.isLoading) {
      body = const LoadingView();
    } else if (provider.items.isEmpty) {
      body = EmptyState(
        icon: Icons.event_repeat,
        title: 'Chưa có giao dịch hẹn trước',
        subtitle: 'Lên lịch cho các khoản thu chi sắp tới',
        actionLabel: 'Thêm lịch hẹn',
        onAction: () => context.push(AppRoutes.scheduledAdd),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: () => provider.load(),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: provider.items.length,
          itemBuilder: (context, index) {
            final item = provider.items[index];
            final cat = categories.byId(item.categoryId);
            final title = (item.note != null && item.note!.trim().isNotEmpty)
                ? item.note!.trim()
                : (cat?.categoryName ?? 'Giao dịch hẹn trước');
            final isIncome = item.type == CategoryType.income;
            final sign = isIncome ? '+' : '-';
            final amountColor = isIncome ? AppColors.income : AppColors.expense;
            final amountText = '$sign${Formatters.currency(item.amount)}';
            final wallet =
                wallets.where((w) => w.id == item.walletId).firstOrNull;
            final walletName = wallet?.walletName ?? 'Ví không xác định';
            final nextDue = _formatNextDue(item);
            final repeatLabel = _formatRepeat(item);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: cat != null
                      ? colorFromHex(cat.color).withValues(alpha: 0.15)
                      : (isIncome
                          ? AppColors.income.withValues(alpha: 0.15)
                          : AppColors.expense.withValues(alpha: 0.15)),
                  child: Icon(
                    cat != null
                        ? iconFromName(cat.icon)
                        : (item.isRecurring
                            ? Icons.event_repeat
                            : Icons.schedule),
                    color: cat != null
                        ? colorFromHex(cat.color)
                        : (isIncome ? AppColors.income : AppColors.expense),
                    size: 20,
                  ),
                ),
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$nextDue · $repeatLabel',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        walletName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      amountText,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: amountColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      tooltip: 'Xóa',
                      onPressed: () async {
                        final confirmed = await confirmDelete(
                          context,
                          itemLabel: 'giao dịch hẹn trước này',
                        );
                        if (confirmed && context.mounted) {
                          try {
                            await context
                                .read<ScheduledProvider>()
                                .remove(item.id);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    e.toString().replaceFirst(
                                        'Exception: ', ''),
                                  ),
                                ),
                              );
                            }
                          }
                        }
                      },
                    ),
                  ],
                ),
                onTap: () => context.push(AppRoutes.scheduledEditPath(item.id)),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Giao dịch hẹn trước')),
      body: body,
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.scheduledAdd),
        child: const Icon(Icons.add),
      ),
    );
  }
}
