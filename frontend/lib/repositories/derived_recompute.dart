import 'package:sqflite/sqflite.dart';
import '../core/database/db_helper.dart';
import 'wallet_repository.dart';
import 'saving_goal_repository.dart';
import 'saving_streak_repository.dart';

/// Tính lại current_balance, saved_amount, streak của một user.
/// Truyền executor của transaction đang mở để cùng commit hoặc cùng rollback.
Future<void> recomputeDerived(DatabaseExecutor e, String userId) async {
  final wallets = WalletRepository(e);
  final walletRows = await e.query(Tables.wallets,
      columns: ['id'],
      where: 'user_id = ? AND is_deleted = 0',
      whereArgs: [userId]);
  for (final r in walletRows) {
    await wallets.recomputeBalance(r['id'] as String);
  }

  final goals = SavingGoalRepository(e);
  final goalRows = await e.query(Tables.savingGoals,
      columns: ['id'],
      where: 'user_id = ? AND is_deleted = 0',
      whereArgs: [userId]);
  for (final r in goalRows) {
    await goals.recomputeSavedAmount(r['id'] as String);
  }

  await SavingStreakRepository(e).recompute(userId);
}
