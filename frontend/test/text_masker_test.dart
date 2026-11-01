import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_app/core/utils/text_masker.dart';

void main() {
  test('giữ số tiền và giờ, che tài khoản/số dư/SĐT', () {
    final m = TextMasker.mask(
      'TK 0123456789 -50,000 VND luc 26/10 14:05 SD: 1,234,000 VND LH 0901234567',
    );
    expect(m, contains('50,000'));
    expect(m, contains('14:05'));
    expect(m, isNot(contains('0123456789')));
    expect(m, isNot(contains('1,234,000')));
    expect(m, isNot(contains('0901234567')));
  });

  test('che số dư dạng "Số dư"', () {
    final m = TextMasker.mask('Số dư 5.000.000 VND');
    expect(m, contains('[đã ẩn số dư]'));
    expect(m, isNot(contains('5.000.000')));
  });

  test('che số thẻ có khoảng trắng', () {
    final m = TextMasker.mask('the 1234 5678 9012 3456');
    expect(m, contains('***'));
    expect(m, isNot(contains('1234')));
  });

  test('che SĐT có khoảng trắng', () {
    final m = TextMasker.mask('LH 090 123 4567');
    expect(m, contains('***'));
    expect(m, isNot(contains('4567')));
  });

  test('giữ nguyên số tài khoản đã che sẵn', () {
    const s = 'TK ****1234 -50.000đ';
    expect(TextMasker.mask(s), s);
  });

  test('hash ổn định với khoảng trắng và hoa/thường', () {
    expect(TextMasker.hash('u1', ' A  b '), TextMasker.hash('u1', 'a b'));
  });

  test('hash khác nhau giữa 2 user', () {
    expect(TextMasker.hash('u1', 'a'), isNot(TextMasker.hash('u2', 'a')));
  });
}
