import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pending_provider.dart';
import '../../widgets/user_avatar.dart';

class MoreMenuScreen extends StatelessWidget {
  const MoreMenuScreen({super.key});

  Widget _buildGroupHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final pendingCount = context.watch<PendingProvider>().pendingCount;

    return Scaffold(
      appBar: AppBar(title: const Text('Thêm')),
      body: ListView(
        children: [
          ListTile(
            leading: UserAvatar(user: user, radius: 20),
            title: Text(user?.fullName ?? ''),
            subtitle: Text(user?.email ?? ''),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.profile),
          ),
          const Divider(height: 1),

          // Nhóm 1: Nhập nhanh AI (nổi bật)
          _buildGroupHeader('Nhập nhanh AI'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Material(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.12),
                      child: const Icon(Icons.sms_outlined,
                          color: AppColors.primary, size: 20),
                    ),
                    title: const Text('Quét SMS'),
                    subtitle: const Text('Đọc tin nhắn ngân hàng'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/pending?action=sms'),
                  ),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.12),
                      child: const Icon(Icons.receipt_long_outlined,
                          color: AppColors.primary, size: 20),
                    ),
                    title: const Text('Chụp hóa đơn'),
                    subtitle: const Text('Đọc hóa đơn bằng AI'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/pending?action=image'),
                  ),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.12),
                      child: const Icon(Icons.content_paste,
                          color: AppColors.primary, size: 20),
                    ),
                    title: const Text('Dán tin nhắn'),
                    subtitle: const Text('Dán nội dung để AI phân tích'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.pasteMessage),
                  ),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.12),
                      child: const Icon(Icons.inbox_outlined,
                          color: AppColors.primary, size: 20),
                    ),
                    title: const Text('Hộp thư chờ duyệt'),
                    subtitle: const Text('Đề xuất chờ bạn kiểm tra'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Badge.count(
                          count: pendingCount,
                          isLabelVisible: pendingCount > 0,
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => context.push(AppRoutes.pendingInbox),
                  ),
                ],
              ),
            ),
          ),

          // Nhóm 2: Trợ lý AI
          _buildGroupHeader('Trợ lý AI'),
          ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: const Text('Gợi ý AI'),
            subtitle: const Text('Dự kiến thu chi tuần/tháng tới'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.aiSuggestions),
          ),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('Hỏi đáp AI'),
            subtitle: const Text('Hỏi về chi tiêu của bạn'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.aiChat),
          ),

          // Nhóm 3: Tiền bạc
          _buildGroupHeader('Tiền bạc'),
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: const Text('Chuyển khoản'),
            subtitle: const Text('Chuyển tiền giữa các ví'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.transfers),
          ),
          ListTile(
            leading: const Icon(Icons.event_repeat),
            title: const Text('Giao dịch hẹn trước'),
            subtitle: const Text('Lên lịch thu chi sắp tới'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.scheduled),
          ),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Danh mục'),
            subtitle: const Text('Quản lý danh mục thu/chi'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.categories),
          ),
          ListTile(
            leading: const Icon(Icons.pie_chart_outline),
            title: const Text('Ngân sách'),
            subtitle: const Text('Hạn mức chi tiêu theo tháng'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.budgets),
          ),

          // Nhóm 4: Khác
          _buildGroupHeader('Khác'),
          ListTile(
            leading: const Icon(Icons.pets),
            title: const Text('Thú cưng'),
            subtitle: const Text('Chăm sóc thú cưng tiết kiệm'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.pet),
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Cài đặt'),
            subtitle: const Text('Tài khoản & tùy chọn'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.settings),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
