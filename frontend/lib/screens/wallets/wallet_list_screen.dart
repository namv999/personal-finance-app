import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../models/wallet.dart';
import '../../widgets/item_action_sheet.dart';
import '../../widgets/wallet_delete_dialog.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/icon_color_picker.dart';
import '../../widgets/loading_view.dart';

class WalletListScreen extends StatelessWidget {
  final bool embedded;
  const WalletListScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WalletProvider>();

    final body = provider.isLoading
        ? const LoadingView()
        : provider.wallets.isEmpty
            ? EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Chưa có ví nào',
                subtitle: 'Tạo ví đầu tiên để bắt đầu theo dõi chi tiêu',
                actionLabel: 'Tạo ví',
                onAction: () => context.push(AppRoutes.walletAdd),
              )
            : RefreshIndicator(
                onRefresh: provider.load,
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    embedded
                        ? AppSpacing.fabClearanceDouble
                        : AppSpacing.fabClearanceSingle,
                  ),
                  itemCount: provider.wallets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final wallet = provider.wallets[index];
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        leading: CircleAvatar(
                          backgroundColor: colorFromHex(wallet.color)
                              .withValues(alpha: 0.15),
                          child: Icon(iconFromName(wallet.icon),
                              color: colorFromHex(wallet.color)),
                        ),
                        title: Text(wallet.walletName,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(wallet.walletType),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              Formatters.currency(wallet.currentBalance),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            IconButton(
                              icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textSecondary),
                              onPressed: () => _showActions(context, wallet),
                            ),
                          ],
                        ),
                        onTap: () =>
                            context.push(AppRoutes.walletDetailPath(wallet.id)),
                        onLongPress: () => _showActions(context, wallet),
                      ),
                    );
                  },
                ),
              );

    if (embedded) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Ví của tôi'),
        ),
        body: body,
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Ví của tôi')),
      body: body,
      floatingActionButton: provider.wallets.isNotEmpty
          ? FloatingActionButton(
              heroTag: null,
              onPressed: () => context.push(AppRoutes.walletAdd),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _showActions(BuildContext context, Wallet wallet) {
    showItemActionSheet(
      context,
      title: wallet.walletName,
      actions: [
        ItemAction(
          Icons.visibility_outlined,
          'Xem chi tiết',
          () => context.push(AppRoutes.walletDetailPath(wallet.id)),
        ),
        ItemAction(
          Icons.edit_outlined,
          'Sửa',
          () => context.push(AppRoutes.walletEditPath(wallet.id)),
        ),
        ItemAction(
          Icons.delete_outline,
          'Xóa',
          () => confirmAndDeleteWallet(
            context,
            walletId: wallet.id,
            walletName: wallet.walletName,
          ),
          danger: true,
        ),
      ],
    );
  }
}
