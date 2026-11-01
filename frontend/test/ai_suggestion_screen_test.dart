import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:personal_finance_app/models/ai_suggestion.dart';
import 'package:personal_finance_app/providers/ai_suggestion_provider.dart';
import 'package:personal_finance_app/repositories/ai_suggestion_repository.dart';
import 'package:personal_finance_app/screens/ai_suggestions/ai_suggestion_screen.dart';
import 'package:personal_finance_app/widgets/empty_state.dart';

class FakeAiSuggestionProvider extends ChangeNotifier
    implements AiSuggestionProvider {
  @override
  String get userId => 'user-1';

  @override
  AiPeriodType periodType = AiPeriodType.month;

  @override
  AiSuggestion? current;

  @override
  bool isLoading = false;

  @override
  bool isRequesting = false;

  SuggestOutcome nextOutcome = const SuggestOutcome(SuggestStatus.ok);

  bool loadCalled = false;
  bool requestNewCalled = false;

  @override
  List<AiSuggestion> get suggestions => current == null ? const [] : [current!];

  @override
  AiPeriod get targetPeriod => periodType == AiPeriodType.month
      ? AiPeriod(
          AiPeriodType.month,
          DateTime(2026, 11, 1),
          DateTime(2026, 11, 30),
        )
      : AiPeriod(
          AiPeriodType.week,
          DateTime(2026, 11, 2),
          DateTime(2026, 11, 8),
        );

  @override
  Future<void> load() async {
    loadCalled = true;
    notifyListeners();
  }

  @override
  Future<void> setType(AiPeriodType type) async {
    periodType = type;
    notifyListeners();
  }

  @override
  Future<SuggestOutcome> requestNew() async {
    requestNewCalled = true;
    return nextOutcome;
  }
}

void main() {
  late FakeAiSuggestionProvider fakeProvider;

  setUp(() {
    fakeProvider = FakeAiSuggestionProvider();
  });

  Widget buildTestWidget() {
    return ChangeNotifierProvider<AiSuggestionProvider>.value(
      value: fakeProvider,
      child: const MaterialApp(
        home: AiSuggestionScreen(),
      ),
    );
  }

  group('AiSuggestionScreen tests', () {
    testWidgets('Header displays SegmentedButton and period label',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Tuần tới'), findsOneWidget);
      expect(find.text('Tháng tới'), findsOneWidget);
      expect(find.text('Tháng 11/2026'), findsOneWidget);

      // Switch to week
      await tester.tap(find.text('Tuần tới'));
      await tester.pumpAndSettle();

      expect(fakeProvider.periodType, AiPeriodType.week);
      expect(find.text('02/11 – 08/11'), findsOneWidget);
    });

    testWidgets('EmptyState shown when current is null', (tester) async {
      fakeProvider.current = null;
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Chưa có gợi ý cho kỳ này'), findsOneWidget);
      expect(find.text('Tạo gợi ý'), findsOneWidget);
      expect(
        find.text(
          'Gợi ý dựa trên dữ liệu đã đồng bộ. AI chỉ diễn giải, mọi số liệu do hệ thống tính.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'Card displays suggestion bullet points, creation date, and collapsible data when current exists',
        (tester) async {
      final sampleData = jsonEncode({
        'avg_expense': 3500000,
        'avg_income': 10000000,
        'top_expense_categories': [
          {'category_name': 'Ăn uống', 'avg_amount': 1500000, 'share_percent': 43},
          {'category_name': 'Di chuyển', 'avg_amount': 500000, 'share_percent': 14},
        ],
        'budgets': [
          {
            'category_name': 'Ăn uống',
            'spending_limit': 1200000,
            'avg_spent': 1500000,
            'over_limit': true,
          }
        ]
      });

      fakeProvider.current = AiSuggestion(
        id: 'sug-1',
        userId: 'user-1',
        periodType: AiPeriodType.month,
        periodStart: DateTime(2026, 11, 1),
        periodEnd: DateTime(2026, 11, 30),
        suggestionContent:
            '- Cắt giảm chi phí ăn uống ngoài hàng.\n- Tiết kiệm thêm 10% thu nhập.',
        suggestedData: sampleData,
        createdAt: DateTime(2026, 10, 29, 9, 15),
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Label switches to 'Tạo lại'
      expect(find.text('Tạo lại'), findsOneWidget);

      // Bullet points
      expect(find.text('Cắt giảm chi phí ăn uống ngoài hàng.'), findsOneWidget);
      expect(find.text('Tiết kiệm thêm 10% thu nhập.'), findsOneWidget);

      // Created at
      expect(find.textContaining('Tạo lúc 29/10 09:15'), findsOneWidget);

      // Collapsible "Số liệu" section
      expect(find.text('Số liệu'), findsOneWidget);

      // Tap to expand
      await tester.tap(find.text('Số liệu'));
      await tester.pumpAndSettle();

      expect(find.text('Top danh mục chi tiêu'), findsOneWidget);
      expect(find.text('Ăn uống'), findsWidgets);
      expect(find.text('Di chuyển'), findsOneWidget);
      expect(find.text('Ngân sách'), findsOneWidget);
      expect(find.text('Vượt hạn mức'), findsOneWidget);
    });

    testWidgets('isRequesting disables button and shows spinner',
        (tester) async {
      fakeProvider.isRequesting = true;
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Đang đồng bộ và phân tích...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Button is disabled
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('insufficientData displays info card and not a SnackBar',
        (tester) async {
      fakeProvider.nextOutcome = const SuggestOutcome(
        SuggestStatus.insufficientData,
        'Cần ít nhất 5 giao dịch trải trên 14 ngày.',
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tạo gợi ý'));
      await tester.pumpAndSettle();

      // No SnackBar
      expect(find.byType(SnackBar), findsNothing);

      // Info card visible
      expect(find.text('Cần ít nhất 5 giao dịch trải trên 14 ngày.'), findsOneWidget);
      expect(find.text('Hãy ghi thêm giao dịch rồi thử lại.'), findsOneWidget);
    });

    testWidgets('Error outcomes display expected SnackBar messages',
        (tester) async {
      final cases = [
        (SuggestStatus.offline, 'Cần kết nối mạng và đăng nhập online để tạo gợi ý'),
        (SuggestStatus.unauthorized, 'Phiên hết hạn, hãy đăng nhập lại'),
        (
          SuggestStatus.syncFailed,
          'Không đồng bộ được dữ liệu nên chưa thể tạo gợi ý. Thử lại sau'
        ),
        (SuggestStatus.rateLimited, 'Dịch vụ AI đang quá tải, thử lại sau ít phút'),
        (SuggestStatus.unavailable, 'Dịch vụ AI tạm thời không khả dụng'),
        (SuggestStatus.error, 'Có lỗi, vui lòng thử lại'),
      ];

      for (final c in cases) {
        fakeProvider.nextOutcome = SuggestOutcome(c.$1);
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Tạo gợi ý'));
        await tester.pump(); // Start SnackBar animation
        await tester.pump(const Duration(milliseconds: 750));

        expect(find.text(c.$2), findsOneWidget);

        // Wait for SnackBar to expire and settle before next case
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('syncFailed with BUSY message displays busy SnackBar',
        (tester) async {
      fakeProvider.nextOutcome =
          const SuggestOutcome(SuggestStatus.syncFailed, 'BUSY');
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tạo gợi ý'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Đang đồng bộ, thử lại sau ít giây'), findsOneWidget);
    });
  });
}
