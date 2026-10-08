import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_routes.dart';
import '../providers/auth_provider.dart';
import '../screens/ai_suggestions/ai_suggestion_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/budgets/budget_form_screen.dart';
import '../screens/budgets/budget_list_screen.dart';
import '../screens/categories/category_form_screen.dart';
import '../screens/categories/category_list_screen.dart';
import '../screens/home/home_shell.dart';
import '../screens/pet/pet_screen.dart';
import '../screens/saving_goals/saving_goal_detail_screen.dart';
import '../screens/saving_goals/saving_goal_form_screen.dart';
import '../screens/saving_goals/saving_goal_list_screen.dart';
import '../screens/settings/profile_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/transactions/transaction_form_screen.dart';
import '../screens/transactions/transaction_list_screen.dart';
import '../screens/transfers/transfer_form_screen.dart';
import '../screens/transfers/transfer_list_screen.dart';
import '../screens/wallets/wallet_detail_screen.dart';
import '../screens/wallets/wallet_form_screen.dart';
import '../screens/wallets/wallet_list_screen.dart';

/// Central route table. Each path corresponds 1:1 with the future Spring
/// Boot REST resource of the same name (see [AppRoutes] docs).
GoRouter buildRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: authProvider,
    redirect: (context, state) {
      final loggingIn = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register;
      final atSplash = state.matchedLocation == AppRoutes.splash;

      if (authProvider.status == AuthStatus.unknown) return atSplash ? null : AppRoutes.splash;
      if (authProvider.status == AuthStatus.unauthenticated) {
        return loggingIn ? null : AppRoutes.login;
      }
      // Authenticated:
      if (loggingIn || atSplash) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (c, s) => const SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (c, s) => const LoginScreen()),
      GoRoute(path: AppRoutes.register, builder: (c, s) => const RegisterScreen()),

      GoRoute(path: AppRoutes.home, builder: (c, s) => const HomeShell()),

      GoRoute(path: AppRoutes.wallets, builder: (c, s) => const WalletListScreen()),
      GoRoute(path: AppRoutes.walletAdd, builder: (c, s) => const WalletFormScreen()),
      GoRoute(
        path: AppRoutes.walletEdit,
        builder: (c, s) => WalletFormScreen(walletId: s.pathParameters['id']),
      ),
      GoRoute(
        path: AppRoutes.walletDetail,
        builder: (c, s) => WalletDetailScreen(walletId: s.pathParameters['id']!),
      ),

      GoRoute(path: AppRoutes.categories, builder: (c, s) => const CategoryListScreen()),
      GoRoute(path: AppRoutes.categoryAdd, builder: (c, s) => const CategoryFormScreen()),
      GoRoute(
        path: AppRoutes.categoryEdit,
        builder: (c, s) => CategoryFormScreen(categoryId: s.pathParameters['id']),
      ),

      GoRoute(path: AppRoutes.transactions, builder: (c, s) => const TransactionListScreen()),
      GoRoute(path: AppRoutes.transactionAdd, builder: (c, s) => const TransactionFormScreen()),
      GoRoute(
        path: AppRoutes.transactionEdit,
        builder: (c, s) => TransactionFormScreen(transactionId: s.pathParameters['id']),
      ),

      GoRoute(path: AppRoutes.transfers, builder: (c, s) => const TransferListScreen()),
      GoRoute(path: AppRoutes.transferAdd, builder: (c, s) => const TransferFormScreen()),

      GoRoute(path: AppRoutes.savingGoals, builder: (c, s) => const SavingGoalListScreen()),
      GoRoute(path: AppRoutes.savingGoalAdd, builder: (c, s) => const SavingGoalFormScreen()),
      GoRoute(
        path: AppRoutes.savingGoalDetail,
        builder: (c, s) => SavingGoalDetailScreen(goalId: s.pathParameters['id']!),
      ),

      GoRoute(path: AppRoutes.budgets, builder: (c, s) => const BudgetListScreen()),
      GoRoute(path: AppRoutes.budgetAdd, builder: (c, s) => const BudgetFormScreen()),

      GoRoute(path: AppRoutes.pet, builder: (c, s) => const PetScreen()),
      GoRoute(path: AppRoutes.aiSuggestions, builder: (c, s) => const AiSuggestionScreen()),

      GoRoute(path: AppRoutes.settings, builder: (c, s) => const SettingsScreen()),
      GoRoute(path: AppRoutes.profile, builder: (c, s) => const ProfileScreen()),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Không tìm thấy trang: ${state.uri}')),
    ),
  );
}
