import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_app/core/constants/app_colors.dart';
import 'package:personal_finance_app/widgets/item_action_sheet.dart';

void main() {
  testWidgets('showItemActionSheet renders title and actions', (tester) async {
    bool editCalled = false;
    bool deleteCalled = false;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showItemActionSheet(
            context,
            title: 'Ăn trưa 50.000đ',
            actions: [
              ItemAction(
                Icons.edit_outlined,
                'Sửa',
                () => editCalled = true,
              ),
              ItemAction(
                Icons.delete_outline,
                'Xóa',
                () => deleteCalled = true,
                danger: true,
              ),
            ],
          ),
          child: const Text('Open'),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Ăn trưa 50.000đ'), findsOneWidget);
    expect(find.text('Sửa'), findsOneWidget);
    expect(find.text('Xóa'), findsOneWidget);

    // Check danger color on Xóa
    final deleteText = tester.widget<Text>(find.text('Xóa'));
    expect(deleteText.style?.color, AppColors.danger);

    // Tap Sửa
    await tester.tap(find.text('Sửa'));
    await tester.pumpAndSettle();

    expect(editCalled, isTrue);
    expect(deleteCalled, isFalse);
    // Sheet is closed
    expect(find.text('Ăn trưa 50.000đ'), findsNothing);
  });
}
