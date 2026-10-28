import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Hides common account, card, phone, and balance patterns before local
/// persistence or sending a message to the AI service.
class TextMasker {
  TextMasker._();

  static final _balance = RegExp(
    r'(?:\bSD\b|\bS[ốo]\s*d[ưu]\b|\bso\s*du\b|\bbalance\b|\bbal\b)\s*[:.]?\s*[+-]?\d[\d.,]*\s*(?:VND|VNĐ|đ)?',
    caseSensitive: false,
    unicode: true,
  );
  static final _longDigits = RegExp(r'(?<!\d)\d{9,}(?!\d)');
  static final _spacedCard = RegExp(r'(?<!\d)(?:\d{4}[ -]){3}\d{1,4}(?!\d)');
  static final _spacedPhone =
      RegExp(r'(?<!\d)(?:\+?84|0)\d{2}[ .]\d{3}[ .]\d{3,4}(?!\d)');
  static final _maskedNumber = RegExp(r'[*xX]{2,}\d{2,}');

  static String mask(String raw) => raw
      .replaceAll(_balance, '[đã ẩn số dư]')
      .replaceAll(_spacedCard, '[đã ẩn]')
      .replaceAll(_spacedPhone, '[đã ẩn]')
      .replaceAll(_longDigits, '[đã ẩn]')
      .replaceAll(_maskedNumber, '****')
      .trim();

  /// Hashes normalized source text with the user id. Raw text is not stored.
  static String hash(String userId, String raw) {
    final normalized = raw.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    return sha256.convert(utf8.encode('$userId|$normalized')).toString();
  }
}
