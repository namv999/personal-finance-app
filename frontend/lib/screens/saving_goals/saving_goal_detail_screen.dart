import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/utils/formatters.dart';
import '../../models/saving_goal.dart';
import '../../providers/saving_goal_provider.dart';
import '../../widgets/confirm_delete_dialog.dart';
import '../../widgets/loading_view.dart';

class SavingGoalDetailScreen extends StatefulWidget {
  final String goalId;
  const SavingGoalDetailScreen({super.key, required this.goalId});

  @override
  State<SavingGoalDetailScreen> createState() => _SavingGoalDetailScreenState();
}

class _SavingGoalDetailScreenState extends State<SavingGoalDetailScreen> {
  SavingGoal? _goal;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final goal = await context.read<SavingGoalProvider>().refresh(widget.goalId);
    setState(() => _goal = goal);
  }

  Future<void> _delete() async {
    if (_goal == null) return;
    final confirmed = await confirmDelete(context, itemLabel: _goal!.goalName);
    if (confirmed) {
      await context.read<SavingGoalProvider>().deleteGoal(_goal!.id);
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final goal = _goal;
    return Scaffold(
      appBar: AppBar(
        title: Text(goal?.goalName ?? ''),
        actions: [IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete)],
      ),
      body: goal == null
          ? const LoadingView()
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: SizedBox(
                    width: 160,
                    height: 160,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 160,
                          height: 160,
                          child: CircularProgressIndicator(
                            value: goal.progress,
                            strokeWidth: 12,
                            backgroundColor: AppColors.divider,
                            color: AppColors.primary,
                          ),
                        ),
                        Text('${(goal.progress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _InfoRow(label: 'Đã tiết kiệm', value: Formatters.currency(goal.savedAmount)),
                _InfoRow(label: 'Mục tiêu', value: Formatters.currency(goal.targetAmount)),
                _InfoRow(label: 'Còn thiếu', value: Formatters.currency((goal.targetAmount - goal.savedAmount).clamp(0, goal.targetAmount))),
                if (goal.expectedCompletionDate != null)
                  _InfoRow(label: 'Ngày dự kiến', value: Formatters.date(goal.expectedCompletionDate!)),
                _InfoRow(label: 'Trạng thái', value: _statusLabel(goal.status)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.push(AppRoutes.transferAdd),
                  icon: const Icon(Icons.add),
                  label: const Text('Nạp thêm tiền vào mục tiêu này'),
                ),
              ],
            ),
    );
  }

  String _statusLabel(GoalStatus status) {
    switch (status) {
      case GoalStatus.completed:
        return 'Đã hoàn thành 🎉';
      case GoalStatus.cancelled:
        return 'Đã hủy';
      case GoalStatus.inProgress:
        return 'Đang thực hiện';
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
