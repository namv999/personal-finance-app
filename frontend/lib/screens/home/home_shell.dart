import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_routes.dart';
import '../saving_goals/saving_goal_list_screen.dart';
import '../transactions/transaction_list_screen.dart';
import '../wallets/wallet_list_screen.dart';
import 'home_screen.dart';
import 'more_menu_screen.dart';

/// Bottom navigation shell. Keeps each tab's own Scaffold/AppBar so nested
/// pages (e.g. wallet detail) can still push on top cleanly via go_router.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _tabs = [
    HomeScreen(),
    TransactionListScreen(embedded: true),
    WalletListScreen(embedded: true),
    SavingGoalListScreen(embedded: true),
    MoreMenuScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      floatingActionButton: _index == 1
          ? FloatingActionButton(
              onPressed: () => context.push(AppRoutes.transactionAdd),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Tổng quan'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Giao dịch'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Ví'),
          NavigationDestination(icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag), label: 'Mục tiêu'),
          NavigationDestination(icon: Icon(Icons.more_horiz), selectedIcon: Icon(Icons.more_horiz), label: 'Thêm'),
        ],
      ),
    );
  }
}
