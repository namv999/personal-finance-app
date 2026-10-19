import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_app/repositories/wallet_repository.dart';
import 'package:personal_finance_app/widgets/wallet_delete_dialog.dart';

void main() {
  Widget buildTestDialog({
    required String walletName,
    required WalletDeletePreview preview,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog<bool>(
              context: context,
              builder: (_) => WalletDeleteDialog(
                walletName: walletName,
                preview: preview,
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
  }

  testWidgets('WalletDeleteDialog displays preview details and 6s countdown',
      (tester) async {
    const preview = WalletDeletePreview(
      transactionCount: 3,
      incomeTotal: 2000000,
      expenseTotal: 500000,
      transferCount: 1,
      counterparts: [
        WalletDeleteImpact(
          walletId: 'w2',
          walletName: 'Ví phụ',
          balanceDelta: 500000,
        ),
      ],
      deletedGoals: ['Mục tiêu A'],
      affectedGoals: ['Mục tiêu B'],
    );

    await tester
        .pumpWidget(buildTestDialog(walletName: 'Ví chính', preview: preview));
    await tester.tap(find.text('Open'));
    await tester.pump();

    // Verify dialog title and wallet name
    expect(find.text('Xác nhận xóa ví'), findsOneWidget);
    expect(find.textContaining('Ví chính'), findsOneWidget);

    // Verify cascade details are rendered
    expect(find.textContaining('3 giao dịch thu/chi'), findsOneWidget);
    expect(find.textContaining('1 lượt chuyển tiền sẽ bị xóa'), findsOneWidget);
    expect(find.textContaining('Ví phụ'), findsOneWidget);
    expect(
        find.textContaining('Mục tiêu sẽ bị xóa: Mục tiêu A'), findsOneWidget);
    expect(find.textContaining('Tiến độ mục tiêu thay đổi: Mục tiêu B'),
        findsOneWidget);

    // Verify button is initially disabled with countdown 6
    expect(find.text('Đồng ý xóa (6)'), findsOneWidget);
    final deleteBtnInitial = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Đồng ý xóa (6)'),
    );
    expect(deleteBtnInitial.onPressed, isNull);

    // Advance 3 seconds
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Đồng ý xóa (3)'), findsOneWidget);

    // Advance remaining 3 seconds (total 6s)
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Đồng ý xóa'), findsOneWidget);

    // Verify button is now enabled
    final deleteBtnActive = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Đồng ý xóa'),
    );
    expect(deleteBtnActive.onPressed, isNotNull);

    // Tap confirm delete
    await tester.tap(find.text('Đồng ý xóa'));
    await tester.pumpAndSettle();

    // Dialog should be dismissed
    expect(find.text('Xác nhận xóa ví'), findsNothing);
  });

  testWidgets('WalletDeleteDialog Cancel button dismisses dialog',
      (tester) async {
    const emptyPreview = WalletDeletePreview(
      transactionCount: 0,
      incomeTotal: 0,
      expenseTotal: 0,
      transferCount: 0,
      counterparts: [],
      deletedGoals: [],
      affectedGoals: [],
    );

    await tester.pumpWidget(
        buildTestDialog(walletName: 'Ví rỗng', preview: emptyPreview));
    await tester.tap(find.text('Open'));
    await tester.pump();

    expect(find.text('Xác nhận xóa ví'), findsOneWidget);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();

    expect(find.text('Xác nhận xóa ví'), findsNothing);
  });

  testWidgets('empty wallet can be confirmed without countdown',
      (tester) async {
    const preview = WalletDeletePreview(
      transactionCount: 0,
      incomeTotal: 0,
      expenseTotal: 0,
      transferCount: 0,
      counterparts: [],
      deletedGoals: [],
      affectedGoals: [],
    );

    await tester
        .pumpWidget(buildTestDialog(walletName: 'Ví rỗng', preview: preview));
    await tester.tap(find.text('Open'));
    await tester.pump();

    expect(find.text('Đồng ý xóa'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Đồng ý xóa'))
          .onPressed,
      isNotNull,
    );
  });
}
