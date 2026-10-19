import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_app/core/utils/clock.dart';
import 'package:personal_finance_app/core/utils/formatters.dart';
import 'package:personal_finance_app/repositories/wallet_repository.dart';

void main() {
  test('Formatters formats currency correctly', () {
    expect(Formatters.currency(100000), contains('100.000'));
    expect(Formatters.currency(-50000), contains('-50.000'));
  });

  test('businessToday returns non-empty UTC+7 date string', () {
    final today = businessToday();
    expect(today, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
  });

  test('WalletDeletePreview holds correct stats', () {
    const preview = WalletDeletePreview(
      transactionCount: 5,
      incomeTotal: 1000000,
      expenseTotal: 500000,
      transferCount: 2,
      counterparts: [
        WalletDeleteImpact(
          walletId: 'w2',
          walletName: 'Ví tiết kiệm',
          balanceDelta: -500000,
        ),
      ],
      deletedGoals: ['Mua xe'],
      affectedGoals: ['Mua nhà'],
    );

    expect(preview.transactionCount, 5);
    expect(preview.incomeTotal, 1000000);
    expect(preview.expenseTotal, 500000);
    expect(preview.transferCount, 2);
    expect(preview.counterparts.length, 1);
    expect(preview.counterparts.first.balanceDelta, -500000);
    expect(preview.deletedGoals, contains('Mua xe'));
    expect(preview.affectedGoals, contains('Mua nhà'));
  });
}
