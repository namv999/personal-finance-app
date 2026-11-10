import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../models/saving_goal.dart';
import '../../providers/saving_goal_provider.dart';
import '../../core/utils/ledger_refresh.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/confirm_delete_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/item_action_sheet.dart';
import '../../widgets/loading_view.dart';

class SavingGoalListScreen extends StatelessWidget {
  final bool embedded;
  const SavingGoalListScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SavingGoalProvider>();

    final body = provider.isLoading
        ? const LoadingView()
        : provider.goals.isEmpty
            ? EmptyState(
                icon: Icons.flag_outlined,
                title: 'Chưa có mục tiêu tiết kiệm',
                subtitle: 'Đặt mục tiêu để theo dõi tiến độ tiết kiệm của bạn',
                actionLabel: 'Tạo mục tiêu',
                onAction: () => context.push(AppRoutes.savingGoalAdd),
              )
            : RefreshIndicator(
                onRefresh: provider.load,
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    embedded
                        ? AppSpacing.fabClearanceDouble
                        : AppSpacing.fabClearanceSingle,
                  ),
                  itemCount: provider.goals.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final goal = provider.goals[index];
                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => context.push(AppRoutes.savingGoalDetailPath(goal.id)),
                        onLongPress: () => _showActions(context, goal),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(goal.goalName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  ),
                                  if (goal.status.value == 'COMPLETED')
                                    const Padding(
                                      padding: EdgeInsets.only(right: 4),
                                      child: Icon(Icons.check_circle, color: AppColors.income, size: 20),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textSecondary),
                                    onPressed: () => _showActions(context, goal),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: goal.progress,
                                  minHeight: 8,
                                  backgroundColor: AppColors.divider,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${Formatters.currency(goal.savedAmount)} / ${Formatters.currency(goal.targetAmount)}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  Text('${(goal.progress * 100).toStringAsFixed(0)}%',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );

    if (embedded) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mục tiêu tiết kiệm'),
        ),
        body: body,
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Mục tiêu tiết kiệm')),
      body: body,
      floatingActionButton: provider.goals.isNotEmpty
          ? FloatingActionButton(
              heroTag: null,
              onPressed: () => context.push(AppRoutes.savingGoalAdd),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _showActions(BuildContext context, SavingGoal goal) {
    showItemActionSheet(
      context,
      title: goal.goalName,
      actions: [
        ItemAction(
          Icons.visibility_outlined,
          'Xem chi tiết',
          () => context.push(AppRoutes.savingGoalDetailPath(goal.id)),
        ),
        ItemAction(
          Icons.add_circle_outline,
          'Ghi nhận tiết kiệm',
          () {
            if (context.read<WalletProvider>().wallets.length < 2) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cần ít nhất 2 ví để nạp tiền vào mục tiêu'),
                ),
              );
              return;
            }
            context.push(AppRoutes.transferAddForGoalPath(goal.id));
          },
        ),
        ItemAction(
          Icons.delete_outline,
          'Xóa',
          () async {
            final confirmed =
                await confirmDelete(context, itemLabel: goal.goalName);
            if (confirmed && context.mounted) {
              final refresh = LedgerRefresh.of(context);
              await context.read<SavingGoalProvider>().deleteGoal(goal.id);
              await refresh.run();
            }
          },
          danger: true,
        ),
      ],
    );
  }
}
