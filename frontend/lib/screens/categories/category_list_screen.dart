import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../models/category.dart';
import '../../providers/category_provider.dart';
import '../../widgets/icon_color_picker.dart';
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
          title: const Text('Danh mục'),
          bottom: const TabBar(tabs: [Tab(text: 'Chi tiêu'), Tab(text: 'Thu nhập')]),
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

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const Center(child: Text('Chưa có danh mục', style: TextStyle(color: AppColors.textSecondary)));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.85),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final c = categories[index];
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: c.isSystemDefault ? null : () => context.push(AppRoutes.categoryEditPath(c.id)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: colorFromHex(c.color).withOpacity(0.15),
                child: Icon(iconFromName(c.icon), color: colorFromHex(c.color)),
              ),
              const SizedBox(height: 6),
              Text(c.categoryName, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        );
      },
    );
  }
}
