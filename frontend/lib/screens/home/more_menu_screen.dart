import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_routes.dart';
import '../../providers/auth_provider.dart';

class MoreMenuScreen extends StatelessWidget {
  const MoreMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final items = <_MenuItem>[
      _MenuItem(Icons.swap_horiz, 'Chuyển khoản', 'Chuyển tiền giữa các ví', AppRoutes.transfers),
      _MenuItem(Icons.category_outlined, 'Danh mục', 'Quản lý danh mục thu/chi', AppRoutes.categories),
      _MenuItem(Icons.pie_chart_outline, 'Ngân sách', 'Hạn mức chi tiêu theo tháng', AppRoutes.budgets),
      _MenuItem(Icons.pets, 'Thú cưng', 'Chăm sóc thú cưng tiết kiệm', AppRoutes.pet),
      _MenuItem(Icons.auto_awesome_outlined, 'Gợi ý AI', 'Lời khuyên tài chính hàng tháng', AppRoutes.aiSuggestions),
      _MenuItem(Icons.settings_outlined, 'Cài đặt', 'Tài khoản & tùy chọn', AppRoutes.settings),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Thêm')),
      body: ListView(
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(user?.fullName ?? ''),
            subtitle: Text(user?.email ?? ''),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.profile),
          ),
          const Divider(height: 1),
          for (final item in items)
            ListTile(
              leading: Icon(item.icon),
              title: Text(item.title),
              subtitle: Text(item.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(item.route),
            ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  _MenuItem(this.icon, this.title, this.subtitle, this.route);
}
