import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_app/core/utils/text_masker.dart';

void main() {
  test('keeps transaction amount and masks sensitive fields', () {
    final masked = TextMasker.mask(
      'TK 0123456789 -50,000 VND luc 26/10 14:05 SD: 1,234,000 VND LH 0901234567',
    );

    expect(masked, contains('50,000'));
    expect(masked, isNot(contains('0123456789')));
    expect(masked, isNot(contains('1,234,000')));
    expect(masked, isNot(contains('0901234567')));
  });

  test('hash is stable after whitespace normalization and scoped by user', () {
    expect(TextMasker.hash('u1', ' A  b '), TextMasker.hash('u1', 'a b'));
    expect(TextMasker.hash('u1', 'a'), isNot(TextMasker.hash('u2', 'a')));
  });
}
