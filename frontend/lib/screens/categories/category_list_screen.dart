import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/ledger_refresh.dart';
import '../../models/category.dart';
import '../../providers/category_provider.dart';
import '../../widgets/confirm_delete_dialog.dart';
import '../../widgets/icon_color_picker.dart';
import '../../widgets/item_action_sheet.dart';
import '../../widgets/loading_view.dart';

class CategoryListScreen extends StatelessWidget {
  const CategoryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CategoryProvider>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Danh mục'),
              Text(
                'Nhấn giữ để sửa hoặc xóa',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          bottom: const TabBar(
              tabs: [Tab(text: 'Chi tiêu'), Tab(text: 'Thu nhập')]),
        ),
        body: provider.isLoading
            ? const LoadingView()
            : TabBarView(
                children: [
                  _CategoryGrid(categories: provider.expenseCategories),
                  _CategoryGrid(categories: provider.incomeCategories),
                ],
              ),
        floatingActionButton: FloatingActionButton(
          heroTag: null,
          onPressed: () => context.push(AppRoutes.categoryAdd),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final List<TransactionCategory> categories;
  const _CategoryGrid({required this.categories});

  void _showActions(BuildContext context, TransactionCategory c) {
    showItemActionSheet(
      context,
      title: c.categoryName,
      actions: [
        ItemAction(
          Icons.edit_outlined,
          'Sửa',
          () => context.push(AppRoutes.categoryEditPath(c.id)),
        ),
        ItemAction(
          Icons.delete_outline,
          'Xóa',
          () async {
            final confirmed =
                await confirmDelete(context, itemLabel: c.categoryName);
            if (confirmed && context.mounted) {
              final refresh = LedgerRefresh.of(context);
              await context.read<CategoryProvider>().deleteCategory(c.id);
              await refresh.run();
            }
          },
          danger: true,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const Center(
          child: Text('Chưa có danh mục',
              style: TextStyle(color: AppColors.textSecondary)));
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, AppSpacing.fabClearanceSingle),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final c = categories[index];
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: c.isSystemDefault
              ? null
              : () => context.push(AppRoutes.categoryEditPath(c.id)),
          onLongPress: c.isSystemDefault
              ? null
              : () => _showActions(context, c),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: colorFromHex(c.color).withValues(alpha: 0.15),
                child: Icon(iconFromName(c.icon), color: colorFromHex(c.color)),
              ),
              const SizedBox(height: 6),
              Text(c.categoryName,
                  style: const TextStyle(fontSize: 12),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        );
      },
    );
  }
}
