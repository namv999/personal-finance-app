import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

import 'core/theme/app_theme.dart';
import 'providers/ai_suggestion_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/budget_provider.dart';
import 'providers/category_provider.dart';
import 'providers/pet_streak_provider.dart';
import 'providers/saving_goal_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/transfer_provider.dart';
import 'providers/wallet_provider.dart';
import 'repositories/ai_suggestion_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/budget_repository.dart';
import 'repositories/category_repository.dart';
import 'repositories/pet_repository.dart';
import 'repositories/saving_goal_repository.dart';
import 'repositories/saving_streak_repository.dart';
import 'repositories/transaction_repository.dart';
import 'repositories/transfer_repository.dart';
import 'repositories/wallet_repository.dart';
import 'routes/app_router.dart';

/// A placeholder id used only before a user logs in. Every real screen is
/// route-guarded behind authentication, so per-user providers below never
/// actually run a query with this id.
const _noUser = '_none_';

class App extends StatefulWidget {
  final Database database;
  const App({super.key, required this.database});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final AuthRepository _authRepository = AuthRepository(widget.database);
  late final AuthProvider _authProvider = AuthProvider(_authRepository)..bootstrap();
  late final router = buildRouter(_authProvider);

  @override
  Widget build(BuildContext context) {
    final database = widget.database;
    return MultiProvider(
      providers: [
        // Repositories — one instance each, sharing the single DB connection.
        Provider.value(value: _authRepository),
        Provider(create: (_) => WalletRepository(database)),
        Provider(create: (_) => CategoryRepository(database)),
        Provider(create: (_) => TransactionRepository(database)),
        Provider(create: (_) => TransferRepository(database)),
        Provider(create: (_) => SavingGoalRepository(database)),
        Provider(create: (_) => BudgetRepository(database)),
        Provider(create: (_) => PetRepository(database)),
        Provider(create: (_) => SavingStreakRepository(database)),
        Provider(create: (_) => AiSuggestionRepository(database)),

        // Auth is the root provider everything else depends on.
        ChangeNotifierProvider.value(value: _authProvider),

        // Per-user providers rebuild automatically when the logged-in user changes.
        ChangeNotifierProxyProvider<AuthProvider, WalletProvider>(
          create: (ctx) => WalletProvider(ctx.read<WalletRepository>(), _noUser),
          update: (ctx, auth, previous) =>
              WalletProvider(ctx.read<WalletRepository>(), auth.currentUser?.id ?? _noUser)..load(),
        ),
        ChangeNotifierProxyProvider<AuthProvider, CategoryProvider>(
          create: (ctx) => CategoryProvider(ctx.read<CategoryRepository>(), _noUser),
          update: (ctx, auth, previous) =>
              CategoryProvider(ctx.read<CategoryRepository>(), auth.currentUser?.id ?? _noUser)..load(),
        ),
        ChangeNotifierProxyProvider<AuthProvider, TransactionProvider>(
          create: (ctx) => TransactionProvider(
              ctx.read<TransactionRepository>(), ctx.read<PetRepository>(), _noUser),
          update: (ctx, auth, previous) => TransactionProvider(
              ctx.read<TransactionRepository>(), ctx.read<PetRepository>(), auth.currentUser?.id ?? _noUser)
            ..load(),
        ),
        ChangeNotifierProxyProvider<AuthProvider, TransferProvider>(
          create: (ctx) => TransferProvider(ctx.read<TransferRepository>(), _noUser),
          update: (ctx, auth, previous) =>
              TransferProvider(ctx.read<TransferRepository>(), auth.currentUser?.id ?? _noUser)..load(),
        ),
        ChangeNotifierProxyProvider<AuthProvider, SavingGoalProvider>(
          create: (ctx) => SavingGoalProvider(ctx.read<SavingGoalRepository>(), _noUser),
          update: (ctx, auth, previous) =>
              SavingGoalProvider(ctx.read<SavingGoalRepository>(), auth.currentUser?.id ?? _noUser)..load(),
        ),
        ChangeNotifierProxyProvider<AuthProvider, BudgetProvider>(
          create: (ctx) => BudgetProvider(
              ctx.read<BudgetRepository>(), ctx.read<TransactionRepository>(), _noUser),
          update: (ctx, auth, previous) => BudgetProvider(
              ctx.read<BudgetRepository>(), ctx.read<TransactionRepository>(), auth.currentUser?.id ?? _noUser)
            ..load(),
        ),
        ChangeNotifierProxyProvider<AuthProvider, PetStreakProvider>(
          create: (ctx) =>
              PetStreakProvider(ctx.read<PetRepository>(), ctx.read<SavingStreakRepository>(), _noUser),
          update: (ctx, auth, previous) => PetStreakProvider(
              ctx.read<PetRepository>(), ctx.read<SavingStreakRepository>(), auth.currentUser?.id ?? _noUser)
            ..load(),
        ),
        ChangeNotifierProxyProvider<AuthProvider, AiSuggestionProvider>(
          create: (ctx) => AiSuggestionProvider(ctx.read<AiSuggestionRepository>(), _noUser),
          update: (ctx, auth, previous) =>
              AiSuggestionProvider(ctx.read<AiSuggestionRepository>(), auth.currentUser?.id ?? _noUser)..load(),
        ),
      ],
      child: MaterialApp.router(
        title: 'Quản Lý Chi Tiêu',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: router,
      ),
    );
  }
}
