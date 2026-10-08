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
import '../../providers/wallet_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/icon_color_picker.dart';
import '../../widgets/loading_view.dart';

class WalletDetailScreen extends StatefulWidget {
  final String walletId;
  const WalletDetailScreen({super.key, required this.walletId});

  @override
  State<WalletDetailScreen> createState() => _WalletDetailScreenState();
}

class _WalletDetailScreenState extends State<WalletDetailScreen> {
  List<FinanceTransaction>? _transactions;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<TransactionProvider>();
    await repo.load(walletId: widget.walletId);
    setState(() => _transactions = repo.transactions);
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();
    final categories = context.watch<CategoryProvider>();
    final wallet = walletProvider.wallets.where((w) => w.id == widget.walletId).firstOrNull;

    if (wallet == null) {
      return const Scaffold(body: LoadingView());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(wallet.walletName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(AppRoutes.walletEditPath(wallet.id)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: colorFromHex(wallet.color).withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(iconFromName(wallet.icon), color: colorFromHex(wallet.color)),
                      const SizedBox(width: 8),
                      Text(wallet.walletType, style: const TextStyle(color: AppColors.textSecondary)),
                    ]),
                    const SizedBox(height: 8),
                    Text(Formatters.currency(wallet.currentBalance),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Lịch sử giao dịch', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (_transactions == null)
              const Padding(padding: EdgeInsets.all(24), child: LoadingView())
            else if (_transactions!.isEmpty)
              const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Chưa có giao dịch',
                subtitle: 'Các giao dịch của ví này sẽ hiện ở đây',
              )
            else
              for (final tx in _transactions!)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colorFromHex(categories.byId(tx.categoryId)?.color).withOpacity(0.15),
                      child: Icon(iconFromName(categories.byId(tx.categoryId)?.icon),
                          color: colorFromHex(categories.byId(tx.categoryId)?.color), size: 18),
                    ),
                    title: Text(categories.byId(tx.categoryId)?.categoryName ?? 'Không phân loại'),
                    subtitle: Text('${Formatters.date(tx.transactionDate)}${tx.note != null ? ' · ${tx.note}' : ''}'),
                    trailing: Text(
                      '${tx.type == CategoryType.income ? '+' : '-'}${Formatters.currency(tx.amount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: tx.type == CategoryType.income ? AppColors.income : AppColors.expense,
                      ),
                    ),
                    onTap: () => context.push(AppRoutes.transactionEditPath(tx.id)),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
