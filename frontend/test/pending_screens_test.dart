import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:personal_finance_app/core/constants/app_colors.dart';
import 'package:personal_finance_app/core/constants/app_routes.dart';
import 'package:personal_finance_app/models/category.dart';
import 'package:personal_finance_app/models/pending_transaction.dart';
import 'package:personal_finance_app/models/user.dart';
import 'package:personal_finance_app/models/wallet.dart';
import 'package:personal_finance_app/providers/auth_provider.dart';
import 'package:personal_finance_app/providers/budget_provider.dart';
import 'package:personal_finance_app/providers/category_provider.dart';
import 'package:personal_finance_app/providers/pending_provider.dart';
import 'package:personal_finance_app/providers/pet_streak_provider.dart';
import 'package:personal_finance_app/providers/saving_goal_provider.dart';
import 'package:personal_finance_app/providers/transaction_provider.dart';
import 'package:personal_finance_app/providers/transfer_provider.dart';
import 'package:personal_finance_app/providers/wallet_provider.dart';
import 'package:personal_finance_app/repositories/pending_transaction_repository.dart';
import 'package:personal_finance_app/screens/home/more_menu_screen.dart';
import 'package:personal_finance_app/screens/pending/paste_message_screen.dart';
import 'package:personal_finance_app/screens/pending/pending_inbox_screen.dart';
import 'package:personal_finance_app/widgets/empty_state.dart';

class FakePendingProvider extends ChangeNotifier implements PendingProvider {
  @override
  String get userId => 'user-1';

  List<PendingTransaction> fakePending = [];
  List<PendingTransaction> fakeNeedsAi = [];
  PasteOutcome nextOutcome = PasteOutcome.parsed;
  PendingTransaction? parsedPending;
  AiRunResult fakeLastRun = AiRunResult.done;
  bool fakeBusy = false;

  bool loadCalled = false;
  bool retryNeedsAiCalled = false;
  String? submittedText;
  String? confirmedPendingId;
  String? rejectedPendingId;

  @override
  List<PendingTransaction> get pending => fakePending;

  @override
  List<PendingTransaction> get needsAi => fakeNeedsAi;

  @override
  int get pendingCount => fakePending.length;

  @override
  bool get busy => fakeBusy;

  @override
  AiRunResult get lastRun => fakeLastRun;

  @override
  set lastRun(AiRunResult value) {
    fakeLastRun = value;
  }

  @override
  Future<void> load() async {
    loadCalled = true;
    notifyListeners();
  }

  @override
  Future<PasteOutcome> submitText(String raw) async {
    submittedText = raw;
    if (raw.trim().isEmpty || raw.length > 1000) {
      return PasteOutcome.invalid;
    }
    if (nextOutcome == PasteOutcome.parsed && parsedPending != null) {
      fakePending.add(parsedPending!);
      notifyListeners();
    }
    return nextOutcome;
  }

  @override
  Future<ImageRunResult> submitImage(Uint8List bytes) async =>
      const ImageRunResult(ImageRunStatus.error);

  @override
  Future<void> retryNeedsAi() async {
    retryNeedsAiCalled = true;
    notifyListeners();
  }

  @override
  Future<SmsScanResult> scanSms({int maxNew = 30}) async =>
      const SmsScanResult(SmsScanStatus.done);

  @override
  Future<void> confirm({
    required String pendingId,
    required String walletId,
    required int amount,
    required CategoryType type,
    required DateTime date,
    String? note,
    String? categoryId,
  }) async {
    confirmedPendingId = pendingId;
    fakePending.removeWhere((item) => item.id == pendingId);
    notifyListeners();
  }

  @override
  Future<void> reject(String pendingId) async {
    rejectedPendingId = pendingId;
    fakePending.removeWhere((item) => item.id == pendingId);
    fakeNeedsAi.removeWhere((item) => item.id == pendingId);
    notifyListeners();
  }
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

class FakeWalletProvider extends ChangeNotifier implements WalletProvider {
  List<Wallet> fakeWallets = [
    Wallet(
      id: 'wallet-1',
      userId: 'user-1',
      walletName: 'Ví tiền mặt',
      walletType: 'SPENDING',
      currentBalance: 500000,
      color: '0xFF2E7D6B',
    ),
  ];

  @override
  List<Wallet> get wallets => fakeWallets;

  @override
  Future<void> load() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCategoryProvider extends ChangeNotifier implements CategoryProvider {
  List<TransactionCategory> fakeCategories = [
    TransactionCategory(
      id: 'cat-1',
      categoryName: 'Ăn uống',
      type: CategoryType.expense,
      icon: 'fastfood',
      color: '0xFFE0554F',
    ),
    TransactionCategory(
      id: 'cat-2',
      categoryName: 'Lương',
      type: CategoryType.income,
      icon: 'work',
      color: '0xFF2E9E5B',
    ),
  ];

  @override
  List<TransactionCategory> get categories => fakeCategories;

  @override
  TransactionCategory? byId(String? id) =>
      fakeCategories.where((c) => c.id == id).firstOrNull;

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

class FakeBudgetProvider extends ChangeNotifier implements BudgetProvider {
  @override
  Future<void> load({DateTime? month}) async {}

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

class FakePetStreakProvider extends ChangeNotifier
    implements PetStreakProvider {
  @override
  Future<void> load() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<InheritedProvider> _testProviders({
  required FakePendingProvider pending,
  FakeWalletProvider? wallet,
  FakeCategoryProvider? category,
}) =>
    [
      ChangeNotifierProvider<AuthProvider>(create: (_) => FakeAuthProvider()),
      ChangeNotifierProvider<PendingProvider>.value(value: pending),
      ChangeNotifierProvider<WalletProvider>(
          create: (_) => wallet ?? FakeWalletProvider()),
      ChangeNotifierProvider<CategoryProvider>(
          create: (_) => category ?? FakeCategoryProvider()),
      ChangeNotifierProvider<TransactionProvider>(
          create: (_) => FakeTransactionProvider()),
      ChangeNotifierProvider<TransferProvider>(
          create: (_) => FakeTransferProvider()),
      ChangeNotifierProvider<BudgetProvider>(
          create: (_) => FakeBudgetProvider()),
      ChangeNotifierProvider<SavingGoalProvider>(
          create: (_) => FakeSavingGoalProvider()),
      ChangeNotifierProvider<PetStreakProvider>(
          create: (_) => FakePetStreakProvider()),
    ];

void main() {
  group('MoreMenuScreen - Entries and badge tests', () {
    testWidgets('Displays Hộp thư chờ duyệt with badge and Dán tin nhắn',
        (tester) async {
      final fakePending = FakePendingProvider()
        ..fakePending = [
          const PendingTransaction(
            id: 'p1',
            userId: 'user-1',
            source: PendingSource.text,
            maskedContent: 'GD 50000',
            sourceHash: 'hash1',
            status: PendingStatus.pending,
          ),
        ];

      await tester.pumpWidget(
        MultiProvider(
          providers: _testProviders(pending: fakePending),
          child: const MaterialApp(home: MoreMenuScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Dán tin nhắn'), 100);
      await tester.pumpAndSettle();

      expect(find.text('Hộp thư chờ duyệt'), findsOneWidget);
      expect(find.text('Dán tin nhắn'), findsOneWidget);
      expect(find.byType(Badge), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });
  });

  group('PasteMessageScreen tests', () {
    GoRouter navigationRouter() => GoRouter(
          initialLocation: '/more-test',
          routes: [
            GoRoute(
                path: '/more-test', builder: (_, __) => const MoreMenuScreen()),
            GoRoute(
                path: AppRoutes.pendingInbox,
                builder: (_, __) => const PendingInboxScreen()),
            GoRoute(
              path: AppRoutes.pasteMessage,
              builder: (_, state) => PasteMessageScreen(
                openedFromInbox:
                    state.uri.queryParameters['fromInbox'] == 'true',
              ),
            ),
          ],
        );

    testWidgets('parsed item opened from inbox keeps back to More screen',
        (tester) async {
      final fakePending = FakePendingProvider()
        ..parsedPending = PendingTransaction(
          id: 'parsed-1',
          userId: 'user-1',
          source: PendingSource.text,
          maskedContent: 'GD 38.000 VND',
          amount: 38000,
          type: CategoryType.income,
          transactionDate: DateTime(2026, 11, 4),
          note: 'Tiền bo',
          sourceHash: 'parsed-hash',
          status: PendingStatus.pending,
        );
      final router = navigationRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(MultiProvider(
        providers: _testProviders(pending: fakePending),
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Hộp thư chờ duyệt'), 100);
      await tester.tap(find.text('Hộp thư chờ duyệt'));
      await tester.pumpAndSettle();
      expect(find.byType(PendingInboxScreen), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('paste_message_fab')));
      await tester.pumpAndSettle();
      expect(find.byType(PasteMessageScreen), findsOneWidget);
      await tester.enterText(
          find.byKey(const ValueKey('paste_message_input')), 'GD 38.000 VND');
      await tester.ensureVisible(find.text('Phân tích'));
      await tester.tap(find.text('Phân tích'));
      await tester.pumpAndSettle();

      expect(find.byType(PendingInboxScreen), findsOneWidget);
      expect(find.text('Tiền bo'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(MoreMenuScreen), findsOneWidget);
      expect(find.text('Thêm'), findsOneWidget);
    });

    testWidgets('parsed item entered from More retains a back route',
        (tester) async {
      final fakePending = FakePendingProvider()
        ..parsedPending = PendingTransaction(
          id: 'parsed-2',
          userId: 'user-1',
          source: PendingSource.text,
          maskedContent: 'GD 50.000 VND',
          amount: 50000,
          type: CategoryType.expense,
          transactionDate: DateTime(2026, 11, 4),
          note: 'Ăn trưa',
          sourceHash: 'parsed-hash-2',
          status: PendingStatus.pending,
        );
      final router = navigationRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(MultiProvider(
        providers: _testProviders(pending: fakePending),
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Dán tin nhắn'), 100);
      await tester.tap(find.text('Dán tin nhắn').last);
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('paste_message_input')), 'GD 50.000 VND');
      await tester.ensureVisible(find.text('Phân tích'));
      await tester.tap(find.text('Phân tích'));
      await tester.pumpAndSettle();

      expect(find.byType(PendingInboxScreen), findsOneWidget);
      expect(find.text('Ăn trưa'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(MoreMenuScreen), findsOneWidget);
    });

    testWidgets(
        'Has multiline TextField, 1000 max length, disclaimer and Phân tích button',
        (tester) async {
      final fakePending = FakePendingProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: _testProviders(pending: fakePending),
          child: const MaterialApp(home: PasteMessageScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dán tin nhắn'), findsOneWidget);
      expect(
        find.text(
            'Số tài khoản, số điện thoại và số dư được che trước khi gửi.'),
        findsOneWidget,
      );
      expect(find.text('Phân tích'), findsOneWidget);

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.maxLength, 1000);
      expect(textField.minLines, greaterThanOrEqualTo(3));
    });

    testWidgets('Shows invalid outcome message when text is empty',
        (tester) async {
      final fakePending = FakePendingProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: _testProviders(pending: fakePending),
          child: const MaterialApp(home: PasteMessageScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Phân tích'));
      await tester.pumpAndSettle();

      expect(find.text('Yêu cầu nhập nội dung không quá 1000 ký tự.'),
          findsOneWidget);
    });

    testWidgets('Shows duplicate outcome message when duplicate',
        (tester) async {
      final fakePending = FakePendingProvider()
        ..nextOutcome = PasteOutcome.duplicate;

      await tester.pumpWidget(
        MultiProvider(
          providers: _testProviders(pending: fakePending),
          child: const MaterialApp(home: PasteMessageScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'GD 100.000VND');
      await tester.tap(find.text('Phân tích'));
      await tester.pumpAndSettle();

      expect(find.text('Tin nhắn đã có trong hộp thư.'), findsOneWidget);
    });

    testWidgets('Shows queued message based on provider.lastRun',
        (tester) async {
      final fakePending = FakePendingProvider()
        ..nextOutcome = PasteOutcome.queued
        ..fakeLastRun = AiRunResult.rateLimited;

      await tester.pumpWidget(
        MultiProvider(
          providers: _testProviders(pending: fakePending),
          child: const MaterialApp(home: PasteMessageScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'GD 200.000VND');
      await tester.tap(find.text('Phân tích'));
      await tester.pump();

      expect(find.textContaining('AI đang giới hạn lượt gọi'), findsOneWidget);
    });
  });

  group('PendingInboxScreen tests', () {
    testWidgets(
        'Empty inbox shows EmptyState and calls load + retryNeedsAi on init',
        (tester) async {
      final fakePending = FakePendingProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: _testProviders(pending: fakePending),
          child: const MaterialApp(home: PendingInboxScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(fakePending.loadCalled, isTrue);
      expect(fakePending.retryNeedsAiCalled, isTrue);
      expect(find.byType(EmptyState), findsOneWidget);
    });

    testWidgets(
        'Displays Đề xuất cần bạn xác nhận and Đang chờ phân tích sections with correct info',
        (tester) async {
      final fakePending = FakePendingProvider()
        ..fakePending = [
          PendingTransaction(
            id: 'p1',
            userId: 'user-1',
            source: PendingSource.text,
            maskedContent: 'GD 75.000 tai Quan Pho',
            amount: 75000,
            type: CategoryType.expense,
            transactionDate: DateTime(2026, 3, 10),
            note: 'Phở sáng',
            suggestedCategoryId: 'cat-1',
            confidence: 0.55, // < 0.6 -> warning chip
            sourceHash: 'hash1',
            status: PendingStatus.pending,
          ),
        ]
        ..fakeNeedsAi = [
          const PendingTransaction(
            id: 'p2',
            userId: 'user-1',
            source: PendingSource.text,
            maskedContent: 'SMS ngan hang dai 123456...',
            sourceHash: 'hash2',
            status: PendingStatus.needsAi,
          ),
        ];

      await tester.pumpWidget(
        MultiProvider(
          providers: _testProviders(pending: fakePending),
          child: const MaterialApp(home: PendingInboxScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đề xuất cần bạn xác nhận'), findsOneWidget);
      expect(find.text('Đang chờ phân tích'), findsOneWidget);

      // Pending card info
      expect(find.text('Phở sáng'), findsOneWidget);
      expect(find.text('Ăn uống'), findsOneWidget);
      expect(find.text('Chi tiêu'), findsOneWidget);
      expect(find.text('55%'), findsOneWidget);
      expect(find.text('Kiểm tra & xác nhận'), findsOneWidget);
      expect(find.text('Bỏ qua'), findsOneWidget);

      final chip = tester.widget<Chip>(find.byType(Chip));
      expect(chip.side?.color, AppColors.warning);

      // NeedsAi card info
      expect(find.text('SMS ngan hang dai 123456...'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.text('Bỏ'), findsOneWidget);
    });

    testWidgets(
        'Tapping Kiểm tra & xác nhận opens edit sheet and confirms without displaying wallet balance',
        (tester) async {
      final fakePending = FakePendingProvider()
        ..fakePending = [
          PendingTransaction(
            id: 'p1',
            userId: 'user-1',
            source: PendingSource.text,
            maskedContent: 'GD 75.000 tai Quan Pho',
            amount: 75000,
            type: CategoryType.expense,
            transactionDate: DateTime(2026, 3, 10),
            note: 'Phở sáng',
            suggestedCategoryId: 'cat-1',
            confidence: 0.9,
            sourceHash: 'hash1',
            status: PendingStatus.pending,
          ),
        ];

      await tester.pumpWidget(
        MultiProvider(
          providers: _testProviders(pending: fakePending),
          child: const MaterialApp(home: PendingInboxScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on "Kiểm tra & xác nhận" to open sheet
      await tester.tap(find.text('Kiểm tra & xác nhận'));
      await tester.pumpAndSettle();

      expect(
          find.text('Kiểm tra & xác nhận'), findsNWidgets(2)); // Title + Sheet
      expect(find.text('Xác nhận'), findsOneWidget);
      expect(find.text('Bỏ qua'), findsNWidgets(2)); // Card + edit sheet

      // Verify wallet balance is NOT displayed
      expect(find.textContaining('500.000'), findsNothing);
      expect(find.text('Ví tiền mặt'), findsOneWidget);

      // Tap "Xác nhận"
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();

      expect(fakePending.confirmedPendingId, 'p1');
    });
  });
}
