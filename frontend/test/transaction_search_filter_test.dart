import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:personal_finance_app/core/database/db_helper.dart';
import 'package:personal_finance_app/models/category.dart';
import 'package:personal_finance_app/models/transaction_filter.dart';
import 'package:personal_finance_app/models/wallet.dart';
import 'package:personal_finance_app/providers/transaction_provider.dart';
import 'package:personal_finance_app/repositories/transaction_repository.dart';
import 'package:personal_finance_app/screens/transactions/transaction_filter_sheet.dart';

void main() {
  late Database db;
  late TransactionRepository repo;
  const userId = 'u_test';
  const wallet1 = 'w_test_1';
  const wallet2 = 'w_test_2';
  const catFood = 'c_food';
  const catSalary = 'c_salary';

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await DbHelper.instance.database;

    // Clean tables
    for (final table in [
      Tables.syncQueue,
      Tables.transfers,
      Tables.transactions,
      Tables.monthlyBudgets,
      Tables.savingGoals,
      Tables.scheduledTransactions,
      Tables.wallets,
    ]) {
      await db.delete(table);
    }
    await db.delete(Tables.categories, where: 'user_id IS NOT NULL');
    await db.delete(Tables.pets);
    await db.delete(Tables.savingStreaks);
    await db.delete(Tables.users);

    // Setup base user
    await db.insert(Tables.users, {
      'id': userId,
      'full_name': 'Test User',
      'email': 'test@example.com',
      'password_hash': 'hash',
      'created_at': '2026-10-01T00:00:00.000Z',
    });

    // Setup base wallets
    await db.insert(Tables.wallets, {
      'id': wallet1,
      'user_id': userId,
      'wallet_name': 'Ví tiền mặt',
      'wallet_type': 'SPENDING',
      'current_balance': 1000000,
      'opening_balance': 1000000,
      'is_deleted': 0,
    });
    await db.insert(Tables.wallets, {
      'id': wallet2,
      'user_id': userId,
      'wallet_name': 'Ví ngân hàng',
      'wallet_type': 'SAVINGS',
      'current_balance': 5000000,
      'opening_balance': 5000000,
      'is_deleted': 0,
    });

    // Setup base categories
    await db.insert(Tables.categories, {
      'id': catFood,
      'user_id': userId,
      'category_name': 'Ăn uống',
      'type': 'EXPENSE',
      'is_deleted': 0,
    });
    await db.insert(Tables.categories, {
      'id': catSalary,
      'user_id': userId,
      'category_name': 'Lương',
      'type': 'INCOME',
      'is_deleted': 0,
    });

    repo = TransactionRepository(db);
  });

  group('TransactionRepository.getAll filtering', () {
    test('filters by type, categoryId, walletId, from and to dates', () async {
      // Create tx1: expense, food, wallet1, date: 2026-11-01
      final tx1 = await repo.create(
        userId: userId,
        walletId: wallet1,
        categoryId: catFood,
        type: CategoryType.expense,
        amount: 50000,
        note: 'Ăn Phở',
        transactionDate: DateTime(2026, 11, 1),
      );

      // Create tx2: expense, food, wallet1, date: 2026-11-05
      final tx2 = await repo.create(
        userId: userId,
        walletId: wallet1,
        categoryId: catFood,
        type: CategoryType.expense,
        amount: 35000,
        note: 'Cà phê sáng',
        transactionDate: DateTime(2026, 11, 5),
      );

      // Create tx3: income, salary, wallet2, date: 2026-11-10
      final tx3 = await repo.create(
        userId: userId,
        walletId: wallet2,
        categoryId: catSalary,
        type: CategoryType.income,
        amount: 20000000,
        note: 'Lương tháng 11',
        transactionDate: DateTime(2026, 11, 10),
      );

      // 1. Filter by type income
      final incomes = await repo.getAll(userId, type: CategoryType.income);
      expect(incomes.map((t) => t.id), equals([tx3.id]));

      // 2. Filter by type expense
      final expenses = await repo.getAll(userId, type: CategoryType.expense);
      expect(expenses.map((t) => t.id), equals([tx2.id, tx1.id]));

      // 3. Filter by category
      final foodTxs = await repo.getAll(userId, categoryId: catFood);
      expect(foodTxs.map((t) => t.id), equals([tx2.id, tx1.id]));

      // 4. Filter by wallet
      final wallet2Txs = await repo.getAll(userId, walletId: wallet2);
      expect(wallet2Txs.map((t) => t.id), equals([tx3.id]));

      // 5. Filter by date range [2026-11-02, 2026-11-06]
      final dateRangeTxs = await repo.getAll(
        userId,
        from: DateTime(2026, 11, 2),
        to: DateTime(2026, 11, 6),
      );
      expect(dateRangeTxs.map((t) => t.id), equals([tx2.id]));

      // 6. Filter by single day [2026-11-01, 2026-11-01]
      final singleDayTxs = await repo.getAll(
        userId,
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 1),
      );
      expect(singleDayTxs.map((t) => t.id), equals([tx1.id]));
    });
  });

  group('TransactionProvider search and filter', () {
    test('searches note case-insensitively with accents', () async {
      await repo.create(
        userId: userId,
        walletId: wallet1,
        categoryId: catFood,
        type: CategoryType.expense,
        amount: 55000,
        note: 'Ăn Phở',
        transactionDate: DateTime(2026, 11, 1),
      );

      await repo.create(
        userId: userId,
        walletId: wallet1,
        categoryId: catFood,
        type: CategoryType.expense,
        amount: 30000,
        note: 'Cà phê đá',
        transactionDate: DateTime(2026, 11, 2),
      );

      final provider = TransactionProvider(repo, userId);
      await provider.load();

      expect(provider.transactions.length, equals(2));
      expect(provider.isFiltering, isFalse);
      expect(provider.searchResults, isEmpty);

      // 'phở' matches 'Ăn Phở'
      await provider.applyFilter(const TransactionFilter(query: 'phở'));
      expect(provider.isFiltering, isTrue);
      expect(provider.searchResults.length, equals(1));
      expect(provider.searchResults.first.note, equals('Ăn Phở'));

      // 'PHỞ' also matches 'Ăn Phở'
      await provider.applyFilter(const TransactionFilter(query: 'PHỞ'));
      expect(provider.searchResults.length, equals(1));
      expect(provider.searchResults.first.note, equals('Ăn Phở'));

      // 'pho' does NOT match 'Ăn Phở' (accent-sensitive by design)
      await provider.applyFilter(const TransactionFilter(query: 'pho'));
      expect(provider.searchResults, isEmpty);

      // Invariant: provider.transactions is NOT modified by filtering
      expect(provider.transactions.length, equals(2));

      // Clear filter
      await provider.clearFilter();
      expect(provider.isFiltering, isFalse);
      expect(provider.searchResults, isEmpty);
      expect(provider.transactions.length, equals(2));
    });

    test('deleting a transaction updates searchResults while filtering', () async {
      final tx = await repo.create(
        userId: userId,
        walletId: wallet1,
        categoryId: catFood,
        type: CategoryType.expense,
        amount: 60000,
        note: 'Ăn Phở bò',
        transactionDate: DateTime(2026, 11, 1),
      );

      final provider = TransactionProvider(repo, userId);
      await provider.load();

      await provider.applyFilter(const TransactionFilter(query: 'phở'));
      expect(provider.searchResults.length, equals(1));

      // Delete the transaction while filter is active
      await provider.deleteTransaction(tx.id, tx.walletId);

      // searchResults must be refreshed automatically
      expect(provider.searchResults, isEmpty);
      expect(provider.transactions, isEmpty);
      expect(provider.isFiltering, isTrue);
    });
  });

  group('showTransactionFilterSheet UI test', () {
    testWidgets('renders filter sheet, selects filters and returns updated draft',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final wallets = [
        Wallet(
          id: 'w1',
          userId: 'u1',
          walletName: 'Ví tiền mặt',
          walletType: 'SPENDING',
        ),
      ];
      final categories = [
        TransactionCategory(
          id: 'c1',
          userId: 'u1',
          categoryName: 'Ăn uống',
          type: CategoryType.expense,
        ),
        TransactionCategory(
          id: 'c2',
          userId: 'u1',
          categoryName: 'Lương',
          type: CategoryType.income,
        ),
      ];

      TransactionFilter? applied;

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              applied = await showTransactionFilterSheet(
                context,
                initial: const TransactionFilter(),
                wallets: wallets,
                categories: categories,
              );
            },
            child: const Text('Mở bộ lọc'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mở bộ lọc'));
      await tester.pumpAndSettle();

      expect(find.text('Tìm kiếm và lọc'), findsOneWidget);
      expect(find.text('Tìm trong ghi chú'), findsOneWidget);
      expect(find.text('Tất cả'), findsOneWidget);
      expect(find.text('Thu'), findsOneWidget);
      expect(find.text('Chi'), findsOneWidget);

      // Select 'Chi'
      await tester.tap(find.text('Chi'));
      await tester.pump();

      // Enter query
      await tester.enterText(find.byType(TextField), 'phở');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      // Tap 'Áp dụng'
      await tester.ensureVisible(find.text('Áp dụng'));
      await tester.tap(find.text('Áp dụng'));
      await tester.pumpAndSettle();

      expect(applied, isNotNull);
      expect(applied!.query, equals('phở'));
      expect(applied!.type, equals(CategoryType.expense));
    });
  });
}
