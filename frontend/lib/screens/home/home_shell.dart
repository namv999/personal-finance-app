import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../providers/saving_goal_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/wallet_provider.dart';
import '../saving_goals/saving_goal_list_screen.dart';
import '../transactions/transaction_list_screen.dart';
import '../wallets/wallet_list_screen.dart';
import 'home_screen.dart';
import 'more_menu_screen.dart';

// File-level flag to ensure the chat hint bubble is shown only once per app session
bool _chatHintShown = false;

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

  bool _showChatBubble = false;
  bool _chatBubbleVisible = false;
  Timer? _bubbleShowTimer;
  Timer? _bubbleHideTimer;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _loadedTabs.add(_index);

    if (!_chatHintShown) {
      _chatHintShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _bubbleShowTimer = Timer(const Duration(milliseconds: 600), () {
          if (!mounted) return;
          setState(() {
            _showChatBubble = true;
            _chatBubbleVisible = true;
          });
          _bubbleHideTimer = Timer(const Duration(seconds: 3), () {
            if (!mounted) return;
            setState(() => _chatBubbleVisible = false);
            Timer(const Duration(milliseconds: 200), () {
              if (mounted) setState(() => _showChatBubble = false);
            });
          });
        });
      });
    }
  }

  @override
  void dispose() {
    _bubbleShowTimer?.cancel();
    _bubbleHideTimer?.cancel();
    super.dispose();
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

  Widget? _buildAddFab(
    BuildContext context, {
    required bool hasWallets,
    required bool hasTransactions,
    required bool hasGoals,
  }) {
    switch (_index) {
      case 0:
        if (!hasWallets) return null;
        return FloatingActionButton(
          key: const ValueKey('fab_transaction'),
          heroTag: null,
          onPressed: () => context.push(AppRoutes.transactionAdd),
          child: const Icon(Icons.add),
        );
      case 1:
        if (!hasWallets || !hasTransactions) return null;
        return FloatingActionButton(
          key: const ValueKey('fab_transaction'),
          heroTag: null,
          onPressed: () => context.push(AppRoutes.transactionAdd),
          child: const Icon(Icons.add),
        );
      case 2:
        if (!hasWallets) return null;
        return FloatingActionButton(
          key: const ValueKey('fab_wallet'),
          heroTag: null,
          onPressed: () => context.push(AppRoutes.walletAdd),
          child: const Icon(Icons.add),
        );
      case 3:
        if (!hasGoals) return null;
        return FloatingActionButton(
          key: const ValueKey('fab_saving_goal'),
          heroTag: null,
          onPressed: () => context.push(AppRoutes.savingGoalAdd),
          child: const Icon(Icons.add),
        );
      default:
        return null;
    }
  }

  Widget _buildChatBubble(BuildContext context) {
    if (!_showChatBubble) return const SizedBox.shrink();

    return IgnorePointer(
      ignoring: !_chatBubbleVisible,
      child: AnimatedOpacity(
        opacity: _chatBubbleVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.only(left: 12, right: 4, top: 4, bottom: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => context.push(AppRoutes.aiChat),
                child: const Text(
                  'Chat với Bot!',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  _bubbleHideTimer?.cancel();
                  setState(() {
                    _showChatBubble = false;
                    _chatBubbleVisible = false;
                  });
                },
                child: const SizedBox(
                  width: 32,
                  height: 32,
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatRow(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildChatBubble(context),
        FloatingActionButton.small(
          key: const ValueKey('fab_chat'),
          heroTag: null,
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          tooltip: 'Chat với Bot',
          onPressed: () => context.push(AppRoutes.aiChat),
          child: const Icon(Icons.auto_awesome),
        ),
      ],
    );
  }

  Widget? _buildFab(
    BuildContext context, {
    required bool hasWallets,
    required bool hasTransactions,
    required bool hasGoals,
  }) {
    if (_index == 4) return null;

    final addFab = _buildAddFab(
      context,
      hasWallets: hasWallets,
      hasTransactions: hasTransactions,
      hasGoals: hasGoals,
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) {
        return ScaleTransition(
          scale: animation,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: Column(
        key: ValueKey('fab_group_$_index'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildChatRow(context),
          if (addFab != null) ...[
            const SizedBox(height: 12),
            addFab,
          ],
        ],
      ),
    );
  }

  bool _getHasWallets(BuildContext context) {
    try {
      return context.select<WalletProvider, bool>((p) => p.wallets.isNotEmpty);
    } catch (_) {
      return true;
    }
  }

  bool _getHasTransactions(BuildContext context) {
    if (_index != 1) return true;
    try {
      return context.select<TransactionProvider, bool>(
          (p) => p.transactions.isNotEmpty);
    } catch (_) {
      return true;
    }
  }

  bool _getHasGoals(BuildContext context) {
    if (_index != 3) return true;
    try {
      return context
          .select<SavingGoalProvider, bool>((p) => p.goals.isNotEmpty);
    } catch (_) {
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasWallets = _getHasWallets(context);
    final hasTransactions = _getHasTransactions(context);
    final hasGoals = _getHasGoals(context);

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
      floatingActionButton: _buildFab(
        context,
        hasWallets: hasWallets,
        hasTransactions: hasTransactions,
        hasGoals: hasGoals,
      ),
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
