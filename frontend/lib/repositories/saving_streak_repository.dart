import 'package:sqflite/sqflite.dart';
import '../core/database/db_helper.dart';
import '../core/utils/id_generator.dart';
import '../models/saving_streak.dart';
import 'pet_repository.dart';

/// Gamification: tracks consecutive days the user has saved money (via a
/// transfer into a savings wallet). One row per user (1:1 per ERD).
class SavingStreakRepository {
  final Database _db;
  late final PetRepository _pets = PetRepository(_db);
  SavingStreakRepository(this._db);

  Future<void> createDefaultForUser(String userId) async {
    final streak = SavingStreak(id: IdGenerator.next(), userId: userId, updatedAt: DateTime.now());
    await _db.insert(Tables.savingStreaks, streak.toMap());
  }

  Future<SavingStreak?> getForUser(String userId) async {
    final rows = await _db.query(Tables.savingStreaks, where: 'user_id = ?', whereArgs: [userId]);
    return rows.isEmpty ? null : SavingStreak.fromMap(rows.first);
  }

  Future<void> markSavedToday(String userId) async {
    final streak = await getForUser(userId);
    if (streak == null) return;

    final today = DateTime.now();
    final todayStr = today.toIso8601String().split('T').first;
    if (streak.lastSavedDate != null &&
        streak.lastSavedDate!.toIso8601String().split('T').first == todayStr) {
      return; // already recorded for today
    }

    final isConsecutive = streak.lastSavedDate != null &&
        today.difference(streak.lastSavedDate!).inDays == 1;
    final newStreak = isConsecutive ? streak.currentStreakDays + 1 : 1;
    final newLongest = newStreak > streak.longestStreak ? newStreak : streak.longestStreak;

    await _db.update(
      Tables.savingStreaks,
      {
        'current_streak_days': newStreak,
        'longest_streak': newLongest,
        'last_saved_date': todayStr,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    await _pets.addExperience(userId, 15);
  }
}
