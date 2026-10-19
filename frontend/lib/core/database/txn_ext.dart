import 'package:sqflite/sqflite.dart';

extension InTxn on DatabaseExecutor {
  /// Chạy trong một transaction. Nếu đã ở trong transaction thì dùng lại.
  /// Bên trong callback chỉ dùng `e`, KHÔNG dùng `_db` (sẽ deadlock).
  Future<T> inTxn<T>(Future<T> Function(DatabaseExecutor e) action) {
    final self = this;
    if (self is Database) return self.transaction<T>((txn) => action(txn));
    return action(self);
  }
}
