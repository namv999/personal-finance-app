import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_routes.dart';
import '../../providers/wallet_provider.dart';
import '../saving_goals/saving_goal_list_screen.dart';
import '../transactions/transaction_list_screen.dart';
import '../wallets/wallet_list_screen.dart';
import 'home_screen.dart';
import 'more_menu_screen.dart';

/// Bottom navigation shell. Keeps each tab's own Scaffold/AppBar so nested
/// pages (e.g. wallet detail) can still push on top cleanly via go_router.
class HomeShell extends StatefulWidget {
  final int initialIndex;
  const HomeShell({super.key, this.initialIndex = 0});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index;
  final Set<int> _loadedTabs = {};

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _loadedTabs.add(_index);
  }

  @override
  void didUpdateWidget(HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      setState(() {
        _index = widget.initialIndex;
        _loadedTabs.add(_index);
      });
    }
  }

  Widget _buildTab(int tabIndex) {
    if (!_loadedTabs.contains(tabIndex)) {
      return const SizedBox.shrink();
    }
    switch (tabIndex) {
      case 0:
        return const HomeScreen();
      case 1:
        return const TransactionListScreen(embedded: true);
      case 2:
        return const WalletListScreen(embedded: true);
      case 3:
        return const SavingGoalListScreen(embedded: true);
      case 4:
        return const MoreMenuScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget? _buildFab(BuildContext context, bool hasWallets) {
    switch (_index) {
      case 0:
      case 1:
        if (!hasWallets) return null;
        return FloatingActionButton(
          key: const ValueKey('fab_transaction'),
          onPressed: () => context.push(AppRoutes.transactionAdd),
          child: const Icon(Icons.add),
        );
      case 2:
        return FloatingActionButton(
          key: const ValueKey('fab_wallet'),
          onPressed: () => context.push(AppRoutes.walletAdd),
          child: const Icon(Icons.add),
        );
      case 3:
        return FloatingActionButton(
          key: const ValueKey('fab_saving_goal'),
          onPressed: () => context.push(AppRoutes.savingGoalAdd),
          child: const Icon(Icons.add),
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasWallets =
        context.select<WalletProvider, bool>((p) => p.wallets.isNotEmpty);

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          _buildTab(0),
          _buildTab(1),
          _buildTab(2),
          _buildTab(3),
          _buildTab(4),
        ],
      ),
      floatingActionButton: _buildFab(context, hasWallets),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          _index = i;
          _loadedTabs.add(i);
        }),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Tổng quan'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Giao dịch'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Ví'),
          NavigationDestination(
              icon: Icon(Icons.flag_outlined),
              selectedIcon: Icon(Icons.flag),
              label: 'Mục tiêu'),
          NavigationDestination(
              icon: Icon(Icons.more_horiz),
              selectedIcon: Icon(Icons.more_horiz),
              label: 'Thêm'),
        ],
      ),
    );
  }
}
