/// Coarse filter for likely bank transaction messages.
class BankSmsFilter {
  BankSmsFilter._();

  static final _amount = RegExp(
    r'\d[\d.,]*\s*(?:vnd|vnđ|đ)(?![a-z0-9])',
    unicode: true,
  );
  static final _keyword = RegExp(
    r'giao dich|giao dịch|\bgd\b|\btk\b|so du|số dư|\bsd\b|bien dong|'
    r'biến động|thanh toan|thanh toán|chuyen khoan|chuyển khoản|'
    r'nhan tien|nhận tiền|rut tien|rút tiền|nap tien|nạp tiền',
    unicode: true,
  );
  static final _otp = RegExp(
    r'\botp\b|ma xac thuc|mã xác thực|ma xac nhan|mã xác nhận|mat khau|mật khẩu',
    unicode: true,
  );

  static bool looksLikeTransaction(String? body) {
    if (body == null || body.isEmpty) return false;
    final text = body.toLowerCase();
    return _amount.hasMatch(text) &&
        _keyword.hasMatch(text) &&
        !_otp.hasMatch(text);
  }
}
