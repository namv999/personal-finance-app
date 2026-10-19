import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/utils/formatters.dart';
import '../../providers/budget_provider.dart';
import '../../providers/category_provider.dart';
import '../../widgets/budget_status_bar.dart';
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
        title:
            Text('Ngân sách · ${Formatters.monthYear(provider.selectedMonth)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => provider.load(
                month: DateTime(provider.selectedMonth.year,
                    provider.selectedMonth.month - 1)),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => provider.load(
                month: DateTime(provider.selectedMonth.year,
                    provider.selectedMonth.month + 1)),
          ),
        ],
      ),
      body: provider.isLoading
          ? const LoadingView()
          : provider.lines.isEmpty
              ? EmptyState(
                  icon: Icons.pie_chart_outline,
                  title: 'Chưa đặt ngân sách tháng này',
                  subtitle:
                      'Đặt hạn mức chi tiêu theo danh mục để kiểm soát tài chính tốt hơn',
                  actionLabel: 'Đặt ngân sách',
                  onAction: () => context.push(AppRoutes.budgetAdd),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Tổng ngân sách tháng',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Các danh mục đã đặt ngân sách',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${Formatters.currency(provider.totalSpent)} / ${Formatters.currency(provider.totalLimit)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              BudgetStatusBar(status: provider.overallStatus),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                        itemCount: provider.lines.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final line = provider.lines[index];
                          final category =
                              categories.byId(line.budget.categoryId);
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
                                        backgroundColor:
                                            colorFromHex(category?.color)
                                                .withValues(alpha: 0.15),
                                        child: Icon(
                                            iconFromName(category?.icon),
                                            size: 16,
                                            color:
                                                colorFromHex(category?.color)),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                          child: Text(
                                              category?.categoryName ??
                                                  'Danh mục',
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.w600))),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            size: 20),
                                        onPressed: () async {
                                          final confirmed =
                                              await confirmDelete(context,
                                                  itemLabel:
                                                      'ngân sách ${category?.categoryName ?? ''}');
                                          if (confirmed) {
                                            await provider
                                                .deleteBudget(line.budget.id);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${Formatters.currency(line.spent)} / ${Formatters.currency(line.budget.spendingLimit)}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 6),
                                  BudgetStatusBar(status: line.status),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
          onPressed: () => context.push(AppRoutes.budgetAdd),
          child: const Icon(Icons.add)),
    );
  }
}
