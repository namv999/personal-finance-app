import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../models/category.dart';
import '../../models/transaction.dart';
import '../../models/transaction_filter.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/icon_color_picker.dart';
import '../../core/utils/ledger_refresh.dart';
import '../../widgets/confirm_delete_dialog.dart';
import '../../widgets/item_action_sheet.dart';
import '../../widgets/loading_view.dart';
import 'transaction_filter_sheet.dart';

class TransactionListScreen extends StatelessWidget {
  final bool embedded;
  const TransactionListScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final categories = context.watch<CategoryProvider>();
    final wallets = context.watch<WalletProvider>().wallets;

    final isFiltering = provider.isFiltering;
    final list = isFiltering ? provider.searchResults : provider.transactions;

    final body = provider.isLoading
        ? const LoadingView()
        : (provider.transactions.isEmpty && !isFiltering)
            ? EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Chưa có giao dịch',
                subtitle: wallets.isEmpty
                    ? 'Bạn cần tạo ví trước khi thêm giao dịch'
                    : 'Ghi lại khoản thu/chi đầu tiên của bạn',
                actionLabel:
                    wallets.isEmpty ? 'Tạo ví' : 'Thêm giao dịch',
                onAction: () => context.push(wallets.isEmpty
                    ? AppRoutes.walletAdd
                    : AppRoutes.transactionAdd),
              )
            : RefreshIndicator(
                onRefresh: () => provider.load(),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    embedded
                        ? AppSpacing.fabClearanceDouble
                        : AppSpacing.fabClearanceSingle,
                  ),
                  children: [
                    if (isFiltering)
                      _buildFilterHeader(context, provider, list.length),
                    if (isFiltering && list.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                            child: Text('Không tìm thấy giao dịch phù hợp')),
                      ),
                    ..._groupByDate(list, categories, context),
                  ],
                ),
              );

    final actions = [
      if (provider.transactions.isNotEmpty || isFiltering)
        IconButton(
          tooltip: 'Tìm kiếm và lọc',
          icon: Badge(
            isLabelVisible: isFiltering,
            child: const Icon(Icons.filter_list),
          ),
          onPressed: () => _openFilter(context, provider),
        ),
    ];

    if (embedded) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Giao dịch'),
          actions: actions,
        ),
        body: body,
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Giao dịch'),
        actions: actions,
      ),
      body: body,
      floatingActionButton:
          (wallets.isNotEmpty && provider.transactions.isNotEmpty)
              ? FloatingActionButton(
                  heroTag: null,
                  onPressed: () => context.push(AppRoutes.transactionAdd),
                  child: const Icon(Icons.add),
                )
              : null,
    );
  }

  Widget _buildFilterHeader(
      BuildContext context, TransactionProvider provider, int count) {
    return Row(
      children: [
        Expanded(child: Text('Tìm thấy $count giao dịch')),
        TextButton(
          onPressed: () => provider.clearFilter(),
          child: const Text('Xóa lọc'),
        ),
      ],
    );
  }

  Future<void> _openFilter(
      BuildContext context, TransactionProvider provider) async {
    final TransactionFilter? result = await showTransactionFilterSheet(
      context,
      initial: provider.filter,
      wallets: context.read<WalletProvider>().wallets,
      categories: context.read<CategoryProvider>().categories,
    );
    if (result != null) await provider.applyFilter(result);
  }

  List<Widget> _groupByDate(List<FinanceTransaction> transactions,
      CategoryProvider categories, BuildContext context) {
    final groups = <String, List<FinanceTransaction>>{};
    for (final tx in transactions) {
      final key = Formatters.date(tx.transactionDate);
      groups.putIfAbsent(key, () => []).add(tx);
    }

    final widgets = <Widget>[];
    groups.forEach((date, txs) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(date,
            style: const TextStyle(
                fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
      ));
      for (final tx in txs) {
        widgets.add(Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  colorFromHex(categories.byId(tx.categoryId)?.color)
                      .withValues(alpha: 0.15),
              child: Icon(iconFromName(categories.byId(tx.categoryId)?.icon),
                  color: colorFromHex(categories.byId(tx.categoryId)?.color),
                  size: 18),
            ),
            title: Text(categories.byId(tx.categoryId)?.categoryName ??
                'Không phân loại'),
            subtitle:
                tx.note != null && tx.note!.isNotEmpty ? Text(tx.note!) : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${tx.type == CategoryType.income ? '+' : '-'}${Formatters.currency(tx.amount)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: tx.type == CategoryType.income
                        ? AppColors.income
                        : AppColors.expense,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textSecondary),
                  onPressed: () => _showActions(context, tx, categories.byId(tx.categoryId)?.categoryName ?? 'Giao dịch'),
                ),
              ],
            ),
            onTap: () => context.push(AppRoutes.transactionEditPath(tx.id)),
            onLongPress: () => _showActions(context, tx, categories.byId(tx.categoryId)?.categoryName ?? 'Giao dịch'),
          ),
        ));
      }
    });
    return widgets;
  }

  void _showActions(BuildContext context, FinanceTransaction tx, String categoryName) {
    final title = tx.note != null && tx.note!.isNotEmpty ? tx.note! : categoryName;
    showItemActionSheet(
      context,
      title: title,
      actions: [
        ItemAction(
          Icons.edit_outlined,
          'Sửa',
          () => context.push(AppRoutes.transactionEditPath(tx.id)),
        ),
        ItemAction(
          Icons.delete_outline,
          'Xóa',
          () async {
            final confirmed =
                await confirmDelete(context, itemLabel: 'giao dịch này');
            if (confirmed && context.mounted) {
              final refresh = LedgerRefresh.of(context);
              await context
                  .read<TransactionProvider>()
                  .deleteTransaction(tx.id, tx.walletId);
              await refresh.run();
            }
          },
          danger: true,
        ),
      ],
    );
  }
}
