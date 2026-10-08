import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/utils/formatters.dart';
import '../../providers/budget_provider.dart';
import '../../providers/category_provider.dart';
import '../../widgets/confirm_delete_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/icon_color_picker.dart';
import '../../widgets/loading_view.dart';

class BudgetListScreen extends StatelessWidget {
  const BudgetListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BudgetProvider>();
    final categories = context.watch<CategoryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Ngân sách · ${Formatters.monthYear(provider.selectedMonth)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => provider.load(month: DateTime(provider.selectedMonth.year, provider.selectedMonth.month - 1)),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => provider.load(month: DateTime(provider.selectedMonth.year, provider.selectedMonth.month + 1)),
          ),
        ],
      ),
      body: provider.isLoading
          ? const LoadingView()
          : provider.lines.isEmpty
              ? EmptyState(
                  icon: Icons.pie_chart_outline,
                  title: 'Chưa đặt ngân sách tháng này',
                  subtitle: 'Đặt hạn mức chi tiêu theo danh mục để kiểm soát tài chính tốt hơn',
                  actionLabel: 'Đặt ngân sách',
                  onAction: () => context.push(AppRoutes.budgetAdd),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.lines.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final line = provider.lines[index];
                    final category = categories.byId(line.budget.categoryId);
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: colorFromHex(category?.color).withOpacity(0.15),
                                  child: Icon(iconFromName(category?.icon), size: 16, color: colorFromHex(category?.color)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Text(category?.categoryName ?? 'Danh mục', style: const TextStyle(fontWeight: FontWeight.w600))),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20),
                                  onPressed: () async {
                                    final confirmed = await confirmDelete(context, itemLabel: 'ngân sách ${category?.categoryName ?? ''}');
                                    if (confirmed) await provider.deleteBudget(line.budget.id);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: line.progress.clamp(0, 1).toDouble(),
                                minHeight: 8,
                                backgroundColor: AppColors.divider,
                                color: line.isOverLimit ? AppColors.danger : AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${Formatters.currency(line.spent)} / ${Formatters.currency(line.budget.spendingLimit)}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                if (line.isOverLimit)
                                  const Text('Vượt hạn mức', style: TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(onPressed: () => context.push(AppRoutes.budgetAdd), child: const Icon(Icons.add)),
    );
  }
}
