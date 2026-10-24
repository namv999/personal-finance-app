import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

import 'core/network/api_client.dart';
import 'core/network/api_endpoints.dart';
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
import 'repositories/sync_push_repository.dart';
import 'repositories/sync_repository.dart';
import 'repositories/transaction_repository.dart';
import 'repositories/transfer_repository.dart';
import 'repositories/wallet_repository.dart';
import 'routes/app_router.dart';
import 'repositories/sync_pull_repository.dart';
import 'repositories/sync_service.dart';

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
  late final AuthProvider _authProvider = AuthProvider(_authRepository)
    ..bootstrap();
  late final WalletRepository _walletRepository =
      WalletRepository(widget.database);
  late final WalletProvider _walletProvider =
      WalletProvider(_walletRepository, _noUser);
  late final router = buildRouter(_authProvider, _walletProvider);
  late final SyncPushRepository _syncPush = SyncPushRepository(
    SyncRepository(widget.database),
    (body) async => (await ApiClient.instance
        .post(ApiEndpoints.syncPush, body: body)) as Map<String, dynamic>,
  );
  late final SyncPullRepository _syncPull = SyncPullRepository(
    SyncRepository(widget.database),
    widget.database,
    (query) async => (await ApiClient.instance
        .get(ApiEndpoints.syncPull, query: query)) as Map<String, dynamic>,
  );
  late final SyncService _syncService = SyncService(_syncPush, _syncPull);

  @override
  void initState() {
    super.initState();
    _authProvider.onLoggedIn = _pullAfterLogin;
  }

  Future<void> _pullAfterLogin(String userId) async {
    try {
      final db = widget.database;
      final n = Sqflite.firstIntValue(await db.rawQuery(
              'SELECT COUNT(*) FROM wallets WHERE user_id = ?', [userId])) ??
          0;
      if (n == 0) await SyncRepository(db).saveCursor(userId, '0');
      await _syncService.syncAll(userId);
    } catch (_) {
      // A sync failure should not prevent the user from logging in.
    }
  }

  @override
  Widget build(BuildContext context) {
    final database = widget.database;
    return MultiProvider(
      providers: [
        // Repositories — one instance each, sharing the single DB connection.
        Provider.value(value: _authRepository),
        Provider.value(value: _walletRepository),
        Provider(create: (_) => CategoryRepository(database)),
        Provider(create: (_) => TransactionRepository(database)),
        Provider(create: (_) => TransferRepository(database)),
        Provider(create: (_) => SavingGoalRepository(database)),
        Provider(create: (_) => BudgetRepository(database)),
        Provider(create: (_) => PetRepository(database)),
        Provider(create: (_) => SavingStreakRepository(database)),
        Provider.value(value: _syncPush),
        Provider.value(value: _syncPull),
        Provider.value(value: _syncService),
        Provider(create: (_) => AiSuggestionRepository(database)),

        // Auth is the root provider everything else depends on.
        ChangeNotifierProvider.value(value: _authProvider),

        // Per-user providers rebuild automatically when the logged-in user changes.
        ChangeNotifierProxyProvider<AuthProvider, WalletProvider>(
          create: (_) => _walletProvider,
          update: (_, auth, __) =>
              _walletProvider..updateUser(auth.currentUser?.id ?? _noUser),
        ),
        ChangeNotifierProxyProvider<AuthProvider, CategoryProvider>(
          create: (ctx) =>
              CategoryProvider(ctx.read<CategoryRepository>(), _noUser),
          update: (ctx, auth, previous) {
            final id = auth.currentUser?.id ?? _noUser;
            if (previous != null && previous.userId == id) return previous;
            return CategoryProvider(ctx.read<CategoryRepository>(), id)..load();
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, TransactionProvider>(
          create: (ctx) =>
              TransactionProvider(ctx.read<TransactionRepository>(), _noUser),
          update: (ctx, auth, previous) {
            final id = auth.currentUser?.id ?? _noUser;
            if (previous != null && previous.userId == id) return previous;
            return TransactionProvider(ctx.read<TransactionRepository>(), id)
              ..load();
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, TransferProvider>(
          create: (ctx) =>
              TransferProvider(ctx.read<TransferRepository>(), _noUser),
          update: (ctx, auth, previous) {
            final id = auth.currentUser?.id ?? _noUser;
            if (previous != null && previous.userId == id) return previous;
            return TransferProvider(ctx.read<TransferRepository>(), id)..load();
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, SavingGoalProvider>(
          create: (ctx) =>
              SavingGoalProvider(ctx.read<SavingGoalRepository>(), _noUser),
          update: (ctx, auth, previous) {
            final id = auth.currentUser?.id ?? _noUser;
            if (previous != null && previous.userId == id) return previous;
            return SavingGoalProvider(ctx.read<SavingGoalRepository>(), id)
              ..load();
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, BudgetProvider>(
          create: (ctx) => BudgetProvider(ctx.read<BudgetRepository>(),
              ctx.read<TransactionRepository>(), _noUser),
          update: (ctx, auth, previous) {
            final id = auth.currentUser?.id ?? _noUser;
            if (previous != null && previous.userId == id) return previous;
            return BudgetProvider(ctx.read<BudgetRepository>(),
                ctx.read<TransactionRepository>(), id)
              ..load();
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, PetStreakProvider>(
          create: (ctx) => PetStreakProvider(ctx.read<PetRepository>(),
              ctx.read<SavingStreakRepository>(), _noUser),
          update: (ctx, auth, previous) {
            final id = auth.currentUser?.id ?? _noUser;
            if (previous != null && previous.userId == id) return previous;
            return PetStreakProvider(ctx.read<PetRepository>(),
                ctx.read<SavingStreakRepository>(), id)
              ..load();
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, AiSuggestionProvider>(
          create: (ctx) =>
              AiSuggestionProvider(ctx.read<AiSuggestionRepository>(), _noUser),
          update: (ctx, auth, previous) {
            final id = auth.currentUser?.id ?? _noUser;
            if (previous != null && previous.userId == id) return previous;
            return AiSuggestionProvider(ctx.read<AiSuggestionRepository>(), id)
              ..load();
          },
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
