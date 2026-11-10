import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/clock.dart';
import '../../core/utils/ledger_refresh.dart';
import '../../models/category.dart';
import '../../providers/auth_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/pending_provider.dart';
import '../../providers/pet_streak_provider.dart';
import '../../widgets/quick_action_button.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/icon_color_picker.dart';
import '../../widgets/loading_view.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userName = context.watch<AuthProvider>().currentUser?.fullName ?? '';
    final walletProvider = context.watch<WalletProvider>();
    final txProvider = context.watch<TransactionProvider>();
    final petStreak = context.watch<PetStreakProvider>();
    final categories = context.watch<CategoryProvider>();
    final pendingCount = context.watch<PendingProvider>().pendingCount;

    return Scaffold(
      appBar: AppBar(
        title: Text('Xin chào, $userName 👋'),
      ),
      body: RefreshIndicator(
        onRefresh: () => LedgerRefresh.all(context).run(),
        child: walletProvider.isLoading
            ? const LoadingView()
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _BalanceCard(totalBalance: walletProvider.totalBalance),
                  const SizedBox(height: 16),
                  _MonthSummaryRow(totals: txProvider.monthTotals),
                  const SizedBox(height: 16),
                  _AiQuickEntryCard(pendingCount: pendingCount),
                  const SizedBox(height: 16),
                  _PetStreakRow(pet: petStreak.pet, streak: petStreak.streak),
                  const SizedBox(height: 16),
                  _SpendingByCategoryCard(),
                  const SizedBox(height: 16),
                  _RecentTransactionsCard(
                    transactions: txProvider.transactions.take(5).toList(),
                    categories: categories,
                  ),
                  const SizedBox(height: AppSpacing.fabClearanceDouble),
                ],
              ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final int totalBalance;
  const _BalanceCard({required this.totalBalance});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tổng số dư', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Text(Formatters.currency(totalBalance),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                ),
                onPressed: () => context.push(AppRoutes.wallets),
                icon: const Icon(Icons.account_balance_wallet, size: 18),
                label: const Text('Ví của tôi'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthSummaryRow extends StatelessWidget {
  final Map<CategoryType, int> totals;
  const _MonthSummaryRow({required this.totals});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            label: 'Thu nhập tháng này',
            amount: totals[CategoryType.income] ?? 0,
            color: AppColors.income,
            icon: Icons.arrow_downward_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryTile(
            label: 'Chi tiêu tháng này',
            amount: totals[CategoryType.expense] ?? 0,
            color: AppColors.expense,
            icon: Icons.arrow_upward_rounded,
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;
  final IconData icon;
  const _SummaryTile(
      {required this.label,
      required this.amount,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                  radius: 14,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(icon, size: 16, color: color)),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary))),
            ]),
            const SizedBox(height: 10),
            Text(Formatters.currency(amount),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _PetStreakRow extends StatelessWidget {
  final dynamic pet;
  final dynamic streak;
  const _PetStreakRow({required this.pet, required this.streak});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(AppRoutes.pet),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.secondary.withValues(alpha: 0.2),
                child: const Icon(Icons.pets, color: AppColors.secondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        pet != null
                            ? '${pet.petName} · Lv.${pet.level}'
                            : 'Thú cưng',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      streak != null
                          ? 'Chuỗi tiết kiệm: ${streak.currentStreakDays} ngày 🔥'
                          : '',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpendingByCategoryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();
    final categoryProvider = context.watch<CategoryProvider>();

    return FutureBuilder<Map<String, int>>(
      future: txProvider.expenseByCategoryForMonth(DateTime.parse(businessToday())),
      builder: (context, snapshot) {
        final data = snapshot.data ?? {};
        final entries = data.entries.where((e) => e.value > 0).toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Chi tiêu theo danh mục',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                if (entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                        child: Text('Chưa có chi tiêu tháng này',
                            style: TextStyle(color: AppColors.textSecondary))),
                  )
                else
                  SizedBox(
                    height: 180,
                    child: Row(
                      children: [
                        Expanded(
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 32,
                              sections: [
                                for (final e in entries.take(6))
                                  PieChartSectionData(
                                    value: e.value.toDouble(),
                                    color: colorFromHex(
                                        categoryProvider.byId(e.key)?.color),
                                    title: '',
                                    radius: 42,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ListView(
                            children: [
                              for (final e in entries.take(6))
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 5,
                                        backgroundColor: colorFromHex(
                                            categoryProvider
                                                .byId(e.key)
                                                ?.color),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          categoryProvider
                                                  .byId(e.key)
                                                  ?.categoryName ??
                                              'Khác',
                                          style: const TextStyle(fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RecentTransactionsCard extends StatelessWidget {
  final List<dynamic> transactions;
  final CategoryProvider categories;
  const _RecentTransactionsCard(
      {required this.transactions, required this.categories});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Giao dịch gần đây',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                TextButton(
                    onPressed: () => context.push(AppRoutes.transactions),
                    child: const Text('Xem tất cả')),
              ],
            ),
            if (transactions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Chưa có giao dịch nào',
                    style: TextStyle(color: AppColors.textSecondary)),
              )
            else
              for (final tx in transactions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor:
                        colorFromHex(categories.byId(tx.categoryId)?.color)
                            .withValues(alpha: 0.15),
                    child: Icon(
                        iconFromName(categories.byId(tx.categoryId)?.icon),
                        color:
                            colorFromHex(categories.byId(tx.categoryId)?.color),
                        size: 18),
                  ),
                  title: Text(categories.byId(tx.categoryId)?.categoryName ??
                      'Không phân loại'),
                  subtitle: Text(Formatters.date(tx.transactionDate)),
                  trailing: Text(
                    '${tx.type == CategoryType.income ? '+' : '-'}${Formatters.currency(tx.amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: tx.type == CategoryType.income
                          ? AppColors.income
                          : AppColors.expense,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _AiQuickEntryCard extends StatelessWidget {
  final int pendingCount;
  const _AiQuickEntryCard({required this.pendingCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.secondary, size: 20),
              SizedBox(width: 8),
              Text(
                'Nhập nhanh bằng AI',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'AI đọc tin nhắn và hóa đơn giúp bạn',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: QuickActionButton(
                  icon: Icons.sms_outlined,
                  label: 'Quét SMS',
                  onTap: () => context.push('/pending?action=sms'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: QuickActionButton(
                  icon: Icons.receipt_long_outlined,
                  label: 'Chụp hóa đơn',
                  onTap: () => context.push('/pending?action=image'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: QuickActionButton(
                  icon: Icons.content_paste,
                  label: 'Dán tin nhắn',
                  onTap: () => context.push(AppRoutes.pasteMessage),
                ),
              ),
            ],
          ),
          if (pendingCount > 0) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () => context.push(AppRoutes.pendingInbox),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Có $pendingCount đề xuất chờ duyệt',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
