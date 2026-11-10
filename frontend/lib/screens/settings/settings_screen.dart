import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../widgets/app_dialog.dart';
import '../../core/constants/app_routes.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/auto_sync_service.dart';
import '../../repositories/sync_pull_repository.dart';
import '../../repositories/transaction_repository.dart';
import '../../repositories/wallet_repository.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
          Builder(builder: (context) {
            final service = context.watch<AutoSyncService>();
            return ListTile(
              leading: const Icon(Icons.cloud_sync_outlined),
              title: const Text('Trạng thái đồng bộ'),
              subtitle: Text(_syncStatus(service)),
            );
          }),
          const ListTile(
            leading: Icon(Icons.cloud_outlined),
            title: Text('Máy chủ'),
            subtitle: Text(ApiEndpoints.baseUrl),
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Đồng bộ ngay'),
            onTap: () async {
              final userId = context.read<AuthProvider>().currentUser?.id;
              if (userId == null) return;
              final service = context.read<AutoSyncService>();
              final out = await service.syncNow();
              if (!context.mounted) return;
              final p = out.push;
              final message = out.error == 'BUSY'
                  ? 'Đang đồng bộ, vui lòng đợi'
                  : out.error == 'NO_TOKEN'
                      ? 'Cần đăng nhập online để đồng bộ'
                      : service.needsRelogin || out.unauthorized
                          ? 'Phiên hết hạn, cần đăng nhập lại để đồng bộ'
                          : out.error != null
                              ? 'Lỗi đồng bộ: ${out.error}'
                              : 'Push: ${p?.applied} ok, ${p?.skippedNewer} bỏ qua, '
                                  '${p?.rejected.length} từ chối. Pull: ${out.pull?.received} bản ghi';
              debugPrint(message);
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(message)));
            },
          ),
          if (kDebugMode)
            ListTile(
              leading: const Icon(Icons.speed),
              title: const Text('Tạo 600 giao dịch test và kiểm tra server'),
              subtitle: const Text('Debug · push theo lô, xác minh bằng API'),
              onTap: () => _run600TransactionCheck(context),
            ),
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: const Text('Reset cursor về 0 (debug)'),
            onTap: () async {
              final userId = context.read<AuthProvider>().currentUser?.id;
              if (userId == null) return;
              final confirmed = await showAppConfirm(
                context,
                title: 'Xác nhận',
                message: 'Bạn có chắc muốn reset cursor về 0?',
                cancelLabel: 'Hủy',
                confirmLabel: 'Đồng ý',
              );
              if (confirmed != true || !context.mounted) return;
              await context.read<SyncPullRepository>().resetCursor(userId);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                    const SnackBar(content: Text('Đã reset cursor')));
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
            title: const Text(
              'Đăng xuất',
              style: TextStyle(color: AppColors.danger),
            ),
            onTap: () async {
              await context.read<AuthProvider>().logout();
            },
          ),
        ],
      ),
    );
  }

  String _syncStatus(AutoSyncService service) {
    if (service.isRunning) return 'Đang đồng bộ...';
    if (service.needsRelogin) return 'Phiên hết hạn, cần đăng nhập lại';
    if (!ApiClient.instance.hasToken) return 'Chưa đăng nhập online';
    if (service.lastError != null) return 'Lỗi, sẽ tự thử lại';
    final time = service.lastSyncAt;
    return time == null
        ? 'Chưa đồng bộ trong phiên này'
        : 'Lần cuối: ${DateFormat('HH:mm dd/MM').format(time.toLocal())}';
  }

  Future<void> _run600TransactionCheck(BuildContext context) async {
    final confirmed = await showAppConfirm(
      context,
      title: 'Tạo giao dịch kiểm thử?',
      message:
          'Tạo 600 giao dịch chi 1 VND trong ví hiện tại, đồng bộ lên máy chủ và kiểm tra đủ 600 bản ghi.',
      cancelLabel: 'Hủy',
      confirmLabel: 'Bắt đầu',
    );
    if (confirmed != true || !context.mounted) return;

    void showResult(String text) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));
    }

    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) {
      showResult('Cần đăng nhập để tạo giao dịch kiểm thử');
      return;
    }
    if (!ApiClient.instance.hasToken) {
      showResult('Cần đăng nhập online để kiểm tra dữ liệu trên máy chủ');
      return;
    }

    try {
      final wallets = await context.read<WalletRepository>().getAll(userId);
      if (!context.mounted) return;
      if (wallets.isEmpty) {
        showResult('Tạo một ví trước khi chạy kiểm tra');
        return;
      }
      showResult('Đang tạo 600 giao dịch kiểm thử...');
      final autoSync = context.read<AutoSyncService>();
      final marker =
          await context.read<TransactionRepository>().createSyncTestBatch(
                userId: userId,
                walletId: wallets.first.id,
                count: 600,
              );
      final sync = await autoSync.syncNow();
      if (!context.mounted) return;
      if (!sync.ok) {
        showResult('Đồng bộ thất bại: ${sync.error ?? 'UNAUTHORIZED'}');
        return;
      }

      final response = await ApiClient.instance.get(
        ApiEndpoints.transactions,
        query: {'q': marker, 'page': 0, 'size': 1},
      ) as Map<String, dynamic>;
      final serverCount = (response['total_elements'] as num).toInt();
      showResult(serverCount == 600
          ? 'Máy chủ đã nhận đủ 600/600 giao dịch'
          : 'Máy chủ hiện có $serverCount/600 giao dịch kiểm thử');
    } catch (e) {
      if (context.mounted) showResult('Không thể kiểm tra 600 giao dịch: $e');
    }
  }
}
