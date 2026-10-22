import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/network/api_endpoints.dart';
import '../../models/category.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/transaction_repository.dart';
import '../../repositories/sync_push_repository.dart';
import '../../repositories/wallet_repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _seedingBatch = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Hồ sơ cá nhân'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.profile),
          ),
          const Divider(height: 1),
          const ListTile(
            leading: Icon(Icons.cloud_sync_outlined),
            title: Text('Trạng thái đồng bộ'),
            subtitle: Text('Backend: ${ApiEndpoints.baseUrl}'),
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add),
            title: const Text('Tạo 600 giao dịch kiểm thử'),
            subtitle: Text(_seedingBatch
                ? 'Đang tạo dữ liệu kiểm thử…'
                : 'Thu nhập 1 VND/giao dịch; chỉ nhấn một lần'),
            onTap: () async {
              if (_seedingBatch) return;
              setState(() => _seedingBatch = true);
              try {
                final userId = context.read<AuthProvider>().currentUser?.id;
                if (userId == null) return;
                final wallets =
                    await context.read<WalletRepository>().getAll(userId);
                if (wallets.isEmpty) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Tạo hoặc đồng bộ một ví trước')));
                  }
                  return;
                }
                final transactions = context.read<TransactionRepository>();
                final today = DateTime.now();
                for (var i = 0; i < 600; i++) {
                  await transactions.create(
                    userId: userId,
                    walletId: wallets.first.id,
                    type: CategoryType.income,
                    amount: 1,
                    note: 'P2.6b batch test ${i + 1}',
                    transactionDate: today,
                  );
                }
                const message =
                    'Đã tạo 600 giao dịch kiểm thử. Nhấn Push để đồng bộ.';
                debugPrint(message);
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(const SnackBar(content: Text(message)));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Tạo dữ liệu thất bại: $e')));
                }
              } finally {
                if (mounted) setState(() => _seedingBatch = false);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.upload_outlined),
            title: const Text('Push dữ liệu đang chờ (debug)'),
            onTap: () async {
              final userId = context.read<AuthProvider>().currentUser?.id;
              if (userId == null) return;
              final result = await context.read<SyncPushRepository>().push(userId);
              final message = result.skippedNoToken
                  ? 'Bỏ qua: chưa có token đăng nhập online'
                  : 'applied=${result.applied}, skipped=${result.skippedNewer}, '
                      'rejected=${result.rejected.length}, err=${result.error}, '
                      '401=${result.unauthorized}';
              debugPrint(message);
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(message)));
              }
            },
          ),
          const Divider(height: 1),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Phiên bản'),
            subtitle: Text('1.0.0 (MVP · offline-first)'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.danger),
            title: const Text('Đăng xuất',
                style: TextStyle(color: AppColors.danger)),
            onTap: () async {
              await context.read<AuthProvider>().logout();
            },
          ),
        ],
      ),
    );
  }
}
