import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/utils/formatters.dart';
import '../../models/category.dart';
import '../../models/transaction.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/icon_color_picker.dart';
import '../../widgets/loading_view.dart';

class TransactionListScreen extends StatelessWidget {
  final bool embedded;
  const TransactionListScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final categories = context.watch<CategoryProvider>();

    final body = provider.isLoading
        ? const LoadingView()
        : provider.transactions.isEmpty
            ? EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Chưa có giao dịch',
                subtitle: 'Ghi lại khoản thu/chi đầu tiên của bạn',
                actionLabel: 'Thêm giao dịch',
                onAction: () => context.push(AppRoutes.transactionAdd),
              )
            : RefreshIndicator(
                onRefresh: () => provider.load(),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: _groupByDate(provider.transactions, categories, context),
                ),
              );

    if (!embedded) return body;
    return Scaffold(appBar: AppBar(title: const Text('Giao dịch')), body: body);
  }

  List<Widget> _groupByDate(
      List<FinanceTransaction> transactions, CategoryProvider categories, BuildContext context) {
    final groups = <String, List<FinanceTransaction>>{};
    for (final tx in transactions) {
      final key = Formatters.date(tx.transactionDate);
      groups.putIfAbsent(key, () => []).add(tx);
    }

    final widgets = <Widget>[];
    groups.forEach((date, txs) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(date, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
      ));
      for (final tx in txs) {
        widgets.add(Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: colorFromHex(categories.byId(tx.categoryId)?.color).withOpacity(0.15),
              child: Icon(iconFromName(categories.byId(tx.categoryId)?.icon),
                  color: colorFromHex(categories.byId(tx.categoryId)?.color), size: 18),
            ),
            title: Text(categories.byId(tx.categoryId)?.categoryName ?? 'Không phân loại'),
            subtitle: tx.note != null && tx.note!.isNotEmpty ? Text(tx.note!) : null,
            trailing: Text(
              '${tx.type == CategoryType.income ? '+' : '-'}${Formatters.currency(tx.amount)}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: tx.type == CategoryType.income ? AppColors.income : AppColors.expense,
              ),
            ),
            onTap: () => context.push(AppRoutes.transactionEditPath(tx.id)),
          ),
        ));
      }
    });
    return widgets;
  }
}
