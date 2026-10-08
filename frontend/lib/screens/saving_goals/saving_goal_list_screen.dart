import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/utils/formatters.dart';
import '../../models/saving_goal.dart';
import '../../providers/saving_goal_provider.dart';
import '../../widgets/empty_state.dart';
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
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.goals.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final goal = provider.goals[index];
                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => context.push(AppRoutes.savingGoalDetailPath(goal.id)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(goal.goalName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  if (goal.status.value == 'COMPLETED')
                                    const Icon(Icons.check_circle, color: AppColors.income, size: 20),
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
          actions: [IconButton(icon: const Icon(Icons.add), onPressed: () => context.push(AppRoutes.savingGoalAdd))],
        ),
        body: body,
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Mục tiêu tiết kiệm')),
      body: body,
      floatingActionButton: FloatingActionButton(onPressed: () => context.push(AppRoutes.savingGoalAdd), child: const Icon(Icons.add)),
    );
  }
}
