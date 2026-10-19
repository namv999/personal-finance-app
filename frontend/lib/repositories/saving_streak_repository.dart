import 'package:sqflite/sqflite.dart';
import '../core/database/db_helper.dart';
import '../core/utils/clock.dart';
import '../core/utils/id_generator.dart';
import '../models/saving_streak.dart';
import 'pet_repository.dart';

/// Gamification: tracks consecutive days the user has saved money (via a
/// transfer into a savings wallet). One row per user (1:1 per ERD).
class SavingStreakRepository {
  final DatabaseExecutor _db;
  late final PetRepository _pets = PetRepository(_db);
  SavingStreakRepository(this._db);

  Future<void> createDefaultForUser(String userId) async {
    final streak = SavingStreak(
        id: IdGenerator.next(), userId: userId, updatedAt: nowUtc());
    await _db.insert(Tables.savingStreaks, streak.toMap());
  }

  Future<SavingStreak?> getForUser(String userId) async {
    final rows = await _db
        .query(Tables.savingStreaks, where: 'user_id = ?', whereArgs: [userId]);
    return rows.isEmpty ? null : SavingStreak.fromMap(rows.first);
  }

  Future<void> recompute(String userId) async {
    final todayStr = businessToday();
    final parsedToday = DateTime.parse(todayStr);
    final today = DateTime.utc(parsedToday.year, parsedToday.month, parsedToday.day);
    final rows = await _db.rawQuery('''
      SELECT DISTINCT t.transfer_date AS d
      FROM ${Tables.transfers} t
      JOIN ${Tables.savingGoals} g
        ON g.id = t.goal_id AND g.user_id = t.user_id AND g.is_deleted = 0
      WHERE t.user_id = ? AND t.is_deleted = 0 AND t.transfer_date <= ?
        AND (g.wallet_id IS NULL OR t.destination_wallet_id = g.wallet_id)
      ORDER BY d
    ''', [userId, todayStr]);

    DateTime? prev;
    var run = 0, longest = 0;
    for (final row in rows) {
      final parsed = DateTime.parse(row['d'] as String);
      final day = DateTime.utc(parsed.year, parsed.month, parsed.day);
      run = prev != null && day.difference(prev).inDays == 1 ? run + 1 : 1;
      if (run > longest) longest = run;
      prev = day;
    }
    final alive = prev != null && today.difference(prev).inDays <= 1;
    final current = alive ? run : 0;
    final lastStr = prev == null ? null : dateOnly(prev);
    final old = await getForUser(userId);
    final oldLast = old?.lastSavedDate == null ? null : dateOnly(old!.lastSavedDate!);
    final unchanged = old != null &&
        old.currentStreakDays == current &&
        old.longestStreak == longest &&
        oldLast == lastStr;
    if (!unchanged) {
      await _db.update(
        Tables.savingStreaks,
        {
          'current_streak_days': current,
          'longest_streak': longest,
          'last_saved_date': lastStr,
          'updated_at': nowUtcIso(),
        },
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    }
    final transactionCount = Sqflite.firstIntValue(await _db.rawQuery(
            'SELECT COUNT(*) FROM ${Tables.transactions} WHERE user_id = ? AND is_deleted = 0',
            [userId])) ??
        0;
    await _pets.setTotalExperience(
        userId, rows.length * 15 + transactionCount * 5);
  }
}
