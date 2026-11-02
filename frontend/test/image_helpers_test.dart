import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_app/core/utils/text_masker.dart';
import 'package:personal_finance_app/repositories/pending_transaction_repository.dart';

void main() {
  test('hashBytes is stable and scoped to the user', () {
    final bytes = Uint8List.fromList(List.generate(32, (index) => index));

    expect(
        TextMasker.hashBytes('u1', bytes), TextMasker.hashBytes('u1', bytes));
    expect(TextMasker.hashBytes('u1', bytes),
        isNot(TextMasker.hashBytes('u2', bytes)));
  });

  test('sniffMime recognizes jpeg, png, webp, and rejects other data', () {
    final jpeg = Uint8List(16)
      ..[0] = 0xFF
      ..[1] = 0xD8
      ..[2] = 0xFF;
    final png = Uint8List(16)
      ..[0] = 0x89
      ..[1] = 0x50
      ..[2] = 0x4E
      ..[3] = 0x47;
    final webp = Uint8List.fromList(
      [0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50],
    );

    expect(PendingTransactionRepository.sniffMime(jpeg), 'image/jpeg');
    expect(PendingTransactionRepository.sniffMime(png), 'image/png');
    expect(PendingTransactionRepository.sniffMime(webp), 'image/webp');
    expect(PendingTransactionRepository.sniffMime(Uint8List(16)), isNull);
    expect(PendingTransactionRepository.sniffMime(Uint8List(4)), isNull);
  });
}
