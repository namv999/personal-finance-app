import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:personal_finance_app/core/constants/app_routes.dart';
import 'package:personal_finance_app/models/category.dart';
import 'package:personal_finance_app/models/transaction.dart';
import 'package:personal_finance_app/models/transaction_filter.dart';
import 'package:personal_finance_app/models/wallet.dart';
import 'package:personal_finance_app/providers/auth_provider.dart';
import 'package:personal_finance_app/providers/budget_provider.dart';
import 'package:personal_finance_app/providers/category_provider.dart';
import 'package:personal_finance_app/providers/pet_streak_provider.dart';
import 'package:personal_finance_app/providers/saving_goal_provider.dart';
import 'package:personal_finance_app/providers/transaction_provider.dart';
import 'package:personal_finance_app/providers/transfer_provider.dart';
import 'package:personal_finance_app/providers/wallet_provider.dart';
import 'package:personal_finance_app/routes/app_router.dart';

class _Auth extends ChangeNotifier implements AuthProvider {
  @override
  AuthStatus status = AuthStatus.authenticated;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Wallets extends ChangeNotifier implements WalletProvider {
  final _items = [
    Wallet(
      id: 'w1',
      userId: 'u1',
      walletName: 'Ví chính',
      walletType: 'SPENDING',
      currentBalance: 500000,
    ),
  ];

  @override
  List<Wallet> get wallets => _items;

  @override
  bool isLoaded = true;

  @override
  bool isLoading = false;

  @override
  Future<void> load() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Categories extends ChangeNotifier implements CategoryProvider {
  @override
  List<TransactionCategory> get incomeCategories => const [];

  @override
  List<TransactionCategory> get expenseCategories => const [];

  @override
  TransactionCategory? byId(String? id) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Transactions extends ChangeNotifier implements TransactionProvider {
  final List<FinanceTransaction> _items = [];

  @override
  List<FinanceTransaction> get transactions => _items;

  @override
  bool isLoading = false;

  @override
  bool get isFiltering => false;

  @override
  List<FinanceTransaction> get searchResults => const [];

  @override
  TransactionFilter get filter => const TransactionFilter();

  @override
  Future<void> addTransaction({
    required String walletId,
    String? categoryId,
    required CategoryType type,
    required int amount,
    String? note,
    required DateTime date,
  }) async {
    _items.add(FinanceTransaction(
      id: 't1',
      userId: 'u1',
      walletId: walletId,
      categoryId: categoryId,
      type: type,
      amount: amount,
      note: note,
      transactionDate: date,
      createdAt: DateTime.now(),
    ));
    notifyListeners();
  }

  @override
  Future<void> load() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SavingGoals extends ChangeNotifier implements SavingGoalProvider {
  @override
  Future<void> load() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Budgets extends ChangeNotifier implements BudgetProvider {
  @override
  Future<void> load({DateTime? month}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PetStreak extends ChangeNotifier implements PetStreakProvider {
  @override
  Future<void> load() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Transfers extends ChangeNotifier implements TransferProvider {
  @override
  Future<void> load() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late GoRouter router;
  late _Auth auth;
  late _Transactions transactions;
  late _Wallets wallets;

  setUp(() {
    auth = _Auth();
    wallets = _Wallets();
    transactions = _Transactions();
    router = buildRouter(auth, wallets)..go(AppRoutes.transactionAdd);
  });

  tearDown(() => router.dispose());

  testWidgets('creating a transaction returns to the transaction list',
      (tester) async {
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<WalletProvider>.value(value: wallets),
        ChangeNotifierProvider<TransactionProvider>.value(value: transactions),
        ChangeNotifierProvider<CategoryProvider>.value(value: _Categories()),
        ChangeNotifierProvider<SavingGoalProvider>.value(value: _SavingGoals()),
        ChangeNotifierProvider<BudgetProvider>.value(value: _Budgets()),
        ChangeNotifierProvider<PetStreakProvider>.value(value: _PetStreak()),
        ChangeNotifierProvider<TransferProvider>.value(value: _Transfers()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '120000');
    await tester.ensureVisible(find.text('Thêm giao dịch'));
    await tester.tap(find.text('Thêm giao dịch'));
    await tester.pumpAndSettle();

    expect(transactions.transactions, hasLength(1));
    expect(
        router.routeInformationProvider.value.uri.path, AppRoutes.transactions);
    expect(find.text('Giao dịch').first, findsOneWidget);
    expect(find.text('Giao dịch mới'), findsNothing);
  });
}
