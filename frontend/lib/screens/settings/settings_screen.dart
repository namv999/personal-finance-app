import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/network/api_endpoints.dart';
import '../../providers/auth_provider.dart';
import '../../providers/category_provider.dart';
import '../../repositories/sync_pull_repository.dart';
import '../../repositories/sync_service.dart';
import '../../core/utils/ledger_refresh.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
            leading: const Icon(Icons.sync),
            title: const Text('Đồng bộ ngay'),
            onTap: () async {
              final userId = context.read<AuthProvider>().currentUser?.id;
              if (userId == null) return;
              final out = await context.read<SyncService>().syncAll(userId);
              if (!context.mounted) return;
              if (out.ok) {
                await context.read<CategoryProvider>().load();
                if (!context.mounted) return;
                await LedgerRefresh.all(context).run();
                if (!context.mounted) return;
              }
              final p = out.push;
              final message = out.error == 'NO_TOKEN'
                  ? 'Cần đăng nhập online để đồng bộ'
                  : out.unauthorized
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
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: const Text('Reset cursor về 0 (debug)'),
            onTap: () async {
              final userId = context.read<AuthProvider>().currentUser?.id;
              if (userId == null) return;
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
