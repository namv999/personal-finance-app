import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_app/core/constants/app_colors.dart';
import 'package:personal_finance_app/core/utils/budget_status.dart';
import 'package:personal_finance_app/widgets/budget_status_bar.dart';

void main() {
  group('BudgetStatusBar tests', () {
    testWidgets('1. Chi 600.000 / 1.000.000: safe, 60%, "Còn 400.000"',
        (tester) async {
      final status = budgetStatusOf(600000, 1000000);
      expect(status.level, BudgetLevel.safe);
      expect(status.barFill, 0.6);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BudgetStatusBar(status: status),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Còn 400.000'), findsOneWidget);
      expect(find.text('60%'), findsOneWidget);

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, 0.6);
      expect(indicator.valueColor?.value, AppColors.success);
    });

    testWidgets('2. Chi 750.000 / 1.000.000: warning, 75%, "Sắp hết, còn 250.000"',
        (tester) async {
      final status = budgetStatusOf(750000, 1000000);
      expect(status.level, BudgetLevel.warning);
      expect(status.barFill, 0.75);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BudgetStatusBar(status: status),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Sắp hết, còn 250.000'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, 0.75);
      expect(indicator.valueColor?.value, AppColors.warning);
    });

    testWidgets('3. Chi 1.000.000 / 1.000.000: warning, 100%, "Sắp hết, còn 0"',
        (tester) async {
      final status = budgetStatusOf(1000000, 1000000);
      expect(status.level, BudgetLevel.warning);
      expect(status.barFill, 1.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BudgetStatusBar(status: status),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Sắp hết, còn 0'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, 1.0);
      expect(indicator.valueColor?.value, AppColors.warning);
    });

    testWidgets('4. Chi 1.000.001 / 1.000.000: exceeded, "Vượt 1", warning icon, AppColors.danger',
        (tester) async {
      final status = budgetStatusOf(1000001, 1000000);
      expect(status.level, BudgetLevel.exceeded);
      expect(status.barFill, 1.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BudgetStatusBar(status: status),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Vượt 1'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, 1.0);
      expect(indicator.valueColor?.value, AppColors.danger);
    });

    testWidgets('Chi 1.500.000 / 1.000.000: shows 150% and clamped 1.0 barFill',
        (tester) async {
      final status = budgetStatusOf(1500000, 1000000);
      expect(status.level, BudgetLevel.exceeded);
      expect(status.barFill, 1.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BudgetStatusBar(status: status),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Vượt 500.000'), findsOneWidget);
      expect(find.text('150%'), findsOneWidget);
    });

    testWidgets('showLabel: false hides the label row', (tester) async {
      final status = budgetStatusOf(500000, 1000000);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BudgetStatusBar(status: status, showLabel: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.textContaining('Còn'), findsNothing);
      expect(find.text('50%'), findsNothing);
    });
  });
}
