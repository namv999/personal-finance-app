import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:personal_finance_app/core/utils/occurrence.dart';
import 'package:personal_finance_app/models/category.dart';
import 'package:personal_finance_app/models/scheduled_transaction.dart';
import 'package:personal_finance_app/models/user.dart';
import 'package:personal_finance_app/models/wallet.dart';
import 'package:personal_finance_app/providers/auth_provider.dart';
import 'package:personal_finance_app/providers/budget_provider.dart';
import 'package:personal_finance_app/providers/category_provider.dart';
import 'package:personal_finance_app/providers/pending_provider.dart';
import 'package:personal_finance_app/providers/pet_streak_provider.dart';
import 'package:personal_finance_app/providers/saving_goal_provider.dart';
import 'package:personal_finance_app/providers/scheduled_provider.dart';
import 'package:personal_finance_app/providers/transaction_provider.dart';
import 'package:personal_finance_app/providers/transfer_provider.dart';
import 'package:personal_finance_app/providers/wallet_provider.dart';
import 'package:personal_finance_app/repositories/scheduled_transaction_repository.dart';
import 'package:personal_finance_app/screens/home/more_menu_screen.dart';
import 'package:personal_finance_app/screens/scheduled/due_dialog.dart';
import 'package:personal_finance_app/screens/scheduled/scheduled_form_screen.dart';
import 'package:personal_finance_app/screens/scheduled/scheduled_list_screen.dart';

class FakeScheduledProvider extends ChangeNotifier
    implements ScheduledProvider {
  @override
  String get userId => 'user-1';

  @override
  List<ScheduledTransaction> items = [];

  @override
  List<DueOccurrence> due = [];

  @override
  bool isLoading = false;

  bool addCalled = false;
  bool editCalled = false;
  String? removedId;
  DueOccurrence? confirmedOccurrence;
  int? confirmedAmount;
  DueOccurrence? cancelledOccurrence;
  bool skipAllCalled = false;

  @override
  Future<void> load() async {
    notifyListeners();
  }

  @override
  Future<bool> add({
    required String walletId,
    String? categoryId,
    required CategoryType type,
    required int amount,
    String? note,
    required String startDate,
    required String timeOfDay,
    RepeatUnit? repeatUnit,
    int? repeatEvery,
    String? endDate,
  }) async {
    addCalled = true;
    final item = ScheduledTransaction(
      id: 'sched-new',
      userId: userId,
      walletId: walletId,
      categoryId: categoryId,
      type: type,
      amount: amount,
      note: note,
      startDate: startDate,
      timeOfDay: timeOfDay,
      repeatUnit: repeatUnit,
      repeatEvery: repeatEvery,
      endDate: endDate,
      nextDueDate: startDate,
      updatedAt: DateTime.now(),
    );
    items.add(item);
    notifyListeners();
    return true;
  }

  @override
  Future<void> edit({
    required String id,
    required String walletId,
    String? categoryId,
    required CategoryType type,
    required int amount,
    String? note,
    required String startDate,
    required String timeOfDay,
    RepeatUnit? repeatUnit,
    int? repeatEvery,
    String? endDate,
  }) async {
    editCalled = true;
    final index = items.indexWhere((s) => s.id == id);
    if (index != -1) {
      items[index] = ScheduledTransaction(
        id: id,
        userId: userId,
        walletId: walletId,
        categoryId: categoryId,
        type: type,
        amount: amount,
        note: note,
        startDate: startDate,
        timeOfDay: timeOfDay,
        repeatUnit: repeatUnit,
        repeatEvery: repeatEvery,
        endDate: endDate,
        nextDueDate: startDate,
        updatedAt: DateTime.now(),
      );
    }
    notifyListeners();
  }

  @override
  Future<void> remove(String id) async {
    removedId = id;
    items.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  @override
  Future<void> confirm(DueOccurrence occurrence, {int? amount}) async {
    confirmedOccurrence = occurrence;
    confirmedAmount = amount;
    due.removeWhere((d) => d.key == occurrence.key);
    notifyListeners();
  }

  @override
  Future<void> cancel(DueOccurrence occurrence) async {
    cancelledOccurrence = occurrence;
    due.removeWhere((d) => d.key == occurrence.key);
    notifyListeners();
  }

  @override
  Future<int> skipAllDue() async {
    skipAllCalled = true;
    final count = due.length;
    due.clear();
    notifyListeners();
    return count;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCategoryProvider extends ChangeNotifier implements CategoryProvider {
  final List<TransactionCategory> _cats = [
    TransactionCategory(
      id: 'cat-food',
      userId: 'user-1',
      categoryName: 'Ăn uống',
      type: CategoryType.expense,
      color: '#E0554F',
      icon: 'restaurant',
    ),
    TransactionCategory(
      id: 'cat-salary',
      userId: 'user-1',
      categoryName: 'Lương',
      type: CategoryType.income,
      color: '#2E9E5B',
      icon: 'attach_money',
    ),
  ];

  @override
  List<TransactionCategory> get expenseCategories =>
      _cats.where((c) => c.type == CategoryType.expense).toList();

  @override
  List<TransactionCategory> get incomeCategories =>
      _cats.where((c) => c.type == CategoryType.income).toList();

  @override
  TransactionCategory? byId(String? id) {
    if (id == null) return null;
    return _cats.where((c) => c.id == id).firstOrNull;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeWalletProvider extends ChangeNotifier implements WalletProvider {
  final List<Wallet> _wallets = [
    Wallet(
      id: 'wallet-1',
      userId: 'user-1',
      walletName: 'Ví tiền mặt',
      walletType: 'SPENDING',
      currentBalance: 1000000,
    ),
  ];

  @override
  List<Wallet> get wallets => _wallets;

  @override
  Future<void> load() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  AppUser? get currentUser => AppUser(
        id: 'user-1',
        email: 'test@example.com',
        fullName: 'Test User',
        passwordHash: 'hash',
        createdAt: DateTime(2026, 1, 1),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePendingProvider extends ChangeNotifier implements PendingProvider {
  @override
  int get pendingCount => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeTransactionProvider extends ChangeNotifier
    implements TransactionProvider {
  @override
  Future<void> load() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeTransferProvider extends ChangeNotifier implements TransferProvider {
  @override
  Future<void> load() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSavingGoalProvider extends ChangeNotifier
    implements SavingGoalProvider {
  @override
  Future<void> load() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeBudgetProvider extends ChangeNotifier implements BudgetProvider {
  @override
  Future<void> load({DateTime? month}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePetStreakProvider extends ChangeNotifier
    implements PetStreakProvider {
  @override
  Future<void> load() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget createTestApp({
  required Widget child,
  FakeScheduledProvider? scheduledProvider,
  FakeCategoryProvider? categoryProvider,
  FakeWalletProvider? walletProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ScheduledProvider>.value(
        value: scheduledProvider ?? FakeScheduledProvider(),
      ),
      ChangeNotifierProvider<CategoryProvider>.value(
        value: categoryProvider ?? FakeCategoryProvider(),
      ),
      ChangeNotifierProvider<WalletProvider>.value(
        value: walletProvider ?? FakeWalletProvider(),
      ),
      ChangeNotifierProvider<AuthProvider>.value(
        value: FakeAuthProvider(),
      ),
      ChangeNotifierProvider<PendingProvider>.value(
        value: FakePendingProvider(),
      ),
      ChangeNotifierProvider<TransactionProvider>.value(
        value: FakeTransactionProvider(),
      ),
      ChangeNotifierProvider<TransferProvider>.value(
        value: FakeTransferProvider(),
      ),
      ChangeNotifierProvider<SavingGoalProvider>.value(
        value: FakeSavingGoalProvider(),
      ),
      ChangeNotifierProvider<BudgetProvider>.value(
        value: FakeBudgetProvider(),
      ),
      ChangeNotifierProvider<PetStreakProvider>.value(
        value: FakePetStreakProvider(),
      ),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  testWidgets('MoreMenuScreen contains Giao dịch hẹn trước tile',
      (tester) async {
    await tester.pumpWidget(createTestApp(child: const MoreMenuScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Giao dịch hẹn trước'), findsOneWidget);
    expect(find.text('Lên lịch thu chi sắp tới'), findsOneWidget);
    expect(find.byIcon(Icons.event_repeat), findsOneWidget);
  });

  group('ScheduledListScreen', () {
    testWidgets('shows empty state when no items', (tester) async {
      final scheduled = FakeScheduledProvider();
      await tester.pumpWidget(createTestApp(
        child: const ScheduledListScreen(),
        scheduledProvider: scheduled,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Chưa có giao dịch hẹn trước'), findsOneWidget);
      expect(
          find.text('Lên lịch cho các khoản thu chi sắp tới'), findsOneWidget);
      expect(find.text('Thêm lịch hẹn'), findsOneWidget);
    });

    testWidgets(
        'displays items with note, amount, wallet, next due, and repeat',
        (tester) async {
      final scheduled = FakeScheduledProvider()
        ..items = [
          ScheduledTransaction(
            id: 'sched-1',
            userId: 'user-1',
            walletId: 'wallet-1',
            categoryId: 'cat-food',
            type: CategoryType.expense,
            amount: 50000,
            note: 'Tiền ăn trưa',
            startDate: '2026-11-10',
            timeOfDay: '12:00',
            repeatUnit: RepeatUnit.week,
            repeatEvery: 2,
            endDate: '2026-12-31',
            nextDueDate: '2026-11-10',
            updatedAt: DateTime(2026, 11, 1),
          ),
          ScheduledTransaction(
            id: 'sched-2',
            userId: 'user-1',
            walletId: 'wallet-1',
            type: CategoryType.income,
            amount: 10000000,
            startDate: '2026-11-15',
            timeOfDay: '08:00',
            nextDueDate: null, // isFinished
            updatedAt: DateTime(2026, 11, 1),
          ),
        ];

      await tester.pumpWidget(createTestApp(
        child: const ScheduledListScreen(),
        scheduledProvider: scheduled,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Tiền ăn trưa'), findsOneWidget);
      expect(find.textContaining('-50.000'), findsOneWidget);
      expect(find.text('10/11/2026 12:00 · Mỗi 2 tuần, đến 31/12/2026'),
          findsOneWidget);
      expect(find.text('Ví tiền mặt'), findsNWidgets(2));

      // sched-2 isFinished
      expect(find.textContaining('+10.000.000'), findsOneWidget);
      expect(find.text('Đã hoàn tất · Một lần'), findsOneWidget);
    });

    testWidgets('delete button opens confirm dialog and calls remove',
        (tester) async {
      final scheduled = FakeScheduledProvider()
        ..items = [
          ScheduledTransaction(
            id: 'sched-del',
            userId: 'user-1',
            walletId: 'wallet-1',
            type: CategoryType.expense,
            amount: 20000,
            note: 'Xóa tôi',
            startDate: '2026-11-10',
            timeOfDay: '09:00',
            nextDueDate: '2026-11-10',
            updatedAt: DateTime(2026, 11, 1),
          ),
        ];

      await tester.pumpWidget(createTestApp(
        child: const ScheduledListScreen(),
        scheduledProvider: scheduled,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Xác nhận xóa'), findsOneWidget);
      expect(
        find.text(
            'Bạn có chắc muốn xóa "giao dịch hẹn trước này"? Hành động này không thể hoàn tác.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Xóa'));
      await tester.pumpAndSettle();

      expect(scheduled.removedId, 'sched-del');
      expect(scheduled.items.isEmpty, isTrue);
    });
  });

  group('ScheduledFormScreen', () {
    testWidgets('renders all fields and creates one-time transaction',
        (tester) async {
      final scheduled = FakeScheduledProvider();
      await tester.pumpWidget(createTestApp(
        child: const ScheduledFormScreen(),
        scheduledProvider: scheduled,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Thêm giao dịch hẹn trước'),
          findsNWidgets(2)); // AppBar and button
      expect(find.text('Chi tiêu'), findsOneWidget);
      expect(find.text('Thu nhập'), findsOneWidget);
      expect(find.text('Số tiền'), findsOneWidget);
      expect(find.text('Ví'), findsOneWidget);
      expect(find.text('Danh mục (tùy chọn)'), findsOneWidget);
      expect(find.text('Ghi chú (tùy chọn)'), findsOneWidget);
      expect(find.text('Ngày hẹn'), findsOneWidget);
      expect(find.text('Giờ hẹn'), findsOneWidget);
      expect(find.text('Lặp lại'), findsOneWidget);

      // Enter amount
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Số tiền'), '150000');

      // Enter note
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Ghi chú (tùy chọn)'),
          'Hẹn đi siêu thị');

      // Tap submit button (last one)
      final submit =
          find.widgetWithText(ElevatedButton, 'Thêm giao dịch hẹn trước');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(scheduled.addCalled, isTrue);
      expect(scheduled.items.length, 1);
      expect(scheduled.items.first.amount, 150000);
      expect(scheduled.items.first.note, 'Hẹn đi siêu thị');
      expect(scheduled.items.first.isRecurring, isFalse);
    });

    testWidgets('checking Lặp lại shows recurrence options and end date',
        (tester) async {
      final scheduled = FakeScheduledProvider();
      await tester.pumpWidget(createTestApp(
        child: const ScheduledFormScreen(),
        scheduledProvider: scheduled,
      ));
      await tester.pumpAndSettle();

      // Tap Lặp lại checkbox
      await tester.tap(find.text('Lặp lại'));
      await tester.pumpAndSettle();

      expect(find.text('Lặp mỗi'), findsOneWidget);
      expect(find.text('Đơn vị'), findsOneWidget);
      expect(find.text('Tháng'), findsOneWidget);
      expect(find.text('Ngày kết thúc (tùy chọn)'), findsOneWidget);
    });

    testWidgets('editing schedule shows change note when schedule modified',
        (tester) async {
      final scheduled = FakeScheduledProvider()
        ..items = [
          ScheduledTransaction(
            id: 'sched-edit',
            userId: 'user-1',
            walletId: 'wallet-1',
            type: CategoryType.expense,
            amount: 80000,
            note: 'Tiền trọ',
            startDate: '2026-11-20',
            timeOfDay: '10:00',
            repeatUnit: RepeatUnit.month,
            repeatEvery: 1,
            nextDueDate: '2026-11-20',
            updatedAt: DateTime(2026, 11, 1),
          ),
        ];

      await tester.pumpWidget(createTestApp(
        child: const ScheduledFormScreen(scheduledId: 'sched-edit'),
        scheduledProvider: scheduled,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Sửa giao dịch hẹn trước'), findsOneWidget);
      expect(find.text('Tiền trọ'), findsOneWidget);
      expect(find.text('80000'), findsOneWidget);

      // Change repeat every to 2
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Lặp mỗi'), '2');
      await tester.pumpAndSettle();

      expect(find.text('Đổi lịch sẽ tính lại từ ngày hẹn mới'), findsOneWidget);
    });
  });

  group('DueDialog', () {
    testWidgets('displays due occurrence and confirms it', (tester) async {
      final scheduled = FakeScheduledProvider()
        ..due = [
          DueOccurrence(
            ScheduledTransaction(
              id: 'due-1',
              userId: 'user-1',
              walletId: 'wallet-1',
              categoryId: 'cat-food',
              type: CategoryType.expense,
              amount: 65000,
              note: 'Ăn tối',
              startDate: '2026-11-03',
              timeOfDay: '18:30',
              nextDueDate: '2026-11-03',
              updatedAt: DateTime(2026, 11, 1),
            ),
            '2026-11-03',
          ),
        ];

      await tester.pumpWidget(createTestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDueDialog(context),
            child: const Text('Mở dialog'),
          ),
        ),
        scheduledProvider: scheduled,
      ));
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.text('Mở dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Giao dịch hẹn trước đến hạn'), findsOneWidget);
      expect(find.text('Ăn tối'), findsOneWidget);
      expect(find.text('Chi tiêu'), findsOneWidget);
      expect(find.text('Danh mục: Ăn uống'), findsOneWidget);
      expect(find.text('Thời điểm: 03/11/2026 18:30'), findsOneWidget);
      expect(find.text('Chỉ bỏ qua kỳ này, chuỗi lặp vẫn chạy tiếp.'),
          findsOneWidget);

      // Tap Xác nhận
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();

      expect(scheduled.confirmedOccurrence?.key, '2026-11-03 18:30');
      expect(scheduled.confirmedAmount, 65000);
      expect(scheduled.due.isEmpty, isTrue);

      // Dialog should have popped because due is empty
      expect(find.text('Giao dịch hẹn trước đến hạn'), findsNothing);
    });

    testWidgets('multiple occurrences show progress and skip all button',
        (tester) async {
      final scheduled = FakeScheduledProvider()
        ..due = [
          DueOccurrence(
            ScheduledTransaction(
              id: 'due-1',
              userId: 'user-1',
              walletId: 'wallet-1',
              type: CategoryType.expense,
              amount: 30000,
              note: 'Kỳ 1',
              startDate: '2026-11-01',
              timeOfDay: '10:00',
              nextDueDate: '2026-11-01',
              updatedAt: DateTime(2026, 11, 1),
            ),
            '2026-11-01',
          ),
          DueOccurrence(
            ScheduledTransaction(
              id: 'due-2',
              userId: 'user-1',
              walletId: 'wallet-1',
              type: CategoryType.expense,
              amount: 30000,
              note: 'Kỳ 2',
              startDate: '2026-11-02',
              timeOfDay: '10:00',
              nextDueDate: '2026-11-02',
              updatedAt: DateTime(2026, 11, 1),
            ),
            '2026-11-02',
          ),
        ];

      await tester.pumpWidget(createTestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDueDialog(context),
            child: const Text('Mở dialog'),
          ),
        ),
        scheduledProvider: scheduled,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mở dialog'));
      await tester.pumpAndSettle();

      expect(find.text('1/2'), findsOneWidget);
      expect(find.text('Hủy tất cả các kỳ đã lỡ'), findsOneWidget);

      // Tap Hủy on the first one
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();

      expect(scheduled.cancelledOccurrence?.key, '2026-11-01 10:00');
      // Dialog transitions to next occurrence without closing
      expect(find.text('Giao dịch hẹn trước đến hạn'), findsOneWidget);
      expect(find.text('Kỳ 2'), findsOneWidget);
    });
  });
}
