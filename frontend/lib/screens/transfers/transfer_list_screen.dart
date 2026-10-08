import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/utils/formatters.dart';
import '../../providers/transfer_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/confirm_delete_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';

class TransferListScreen extends StatelessWidget {
  const TransferListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransferProvider>();
    final wallets = context.watch<WalletProvider>().wallets;

    String walletName(String id) =>
        wallets.where((w) => w.id == id).map((w) => w.walletName).firstOrNull ?? 'Ví đã xóa';

    return Scaffold(
      appBar: AppBar(title: const Text('Chuyển khoản')),
      body: provider.isLoading
          ? const LoadingView()
          : provider.transfers.isEmpty
              ? EmptyState(
                  icon: Icons.swap_horiz,
                  title: 'Chưa có giao dịch chuyển khoản',
                  subtitle: 'Chuyển tiền giữa các ví, ví dụ để nạp vào ví tiết kiệm',
                  actionLabel: 'Chuyển khoản',
                  onAction: () => context.push(AppRoutes.transferAdd),
                )
              : RefreshIndicator(
                  onRefresh: provider.load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.transfers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final t = provider.transfers[index];
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0x1A4C7DF0),
                            child: Icon(Icons.swap_horiz, color: AppColors.transfer),
                          ),
                          title: Text('${walletName(t.sourceWalletId)} → ${walletName(t.destinationWalletId)}'),
                          subtitle: Text(Formatters.date(t.transferDate) + (t.note != null && t.note!.isNotEmpty ? ' · ${t.note}' : '')),
                          trailing: Text(Formatters.currency(t.amount),
                              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.transfer)),
                          onLongPress: () async {
                            final confirmed = await confirmDelete(context, itemLabel: 'giao dịch chuyển khoản này');
                            if (confirmed) await context.read<TransferProvider>().deleteTransfer(t);
                          },
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.transferAdd),
        child: const Icon(Icons.add),
      ),
    );
  }
}
