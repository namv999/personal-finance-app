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

  Future<void> markSaved(String userId, DateTime savedDate) async {
    final streak = await getForUser(userId);
    if (streak == null) return;

    final date = DateTime(savedDate.year, savedDate.month, savedDate.day);
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    if (date.isAfter(todayDate)) return;
    final dateStr = date.toIso8601String().split('T').first;
    final lastDate = streak.lastSavedDate == null
        ? null
        : DateTime(streak.lastSavedDate!.year, streak.lastSavedDate!.month,
            streak.lastSavedDate!.day);
    if (lastDate != null && !date.isAfter(lastDate)) return;

    final isConsecutive = lastDate != null && date.difference(lastDate).inDays == 1;
    final newStreak = isConsecutive ? streak.currentStreakDays + 1 : 1;
    final newLongest = newStreak > streak.longestStreak ? newStreak : streak.longestStreak;

    await _db.update(
      Tables.savingStreaks,
      {
        'current_streak_days': newStreak,
        'longest_streak': newLongest,
        'last_saved_date': dateStr,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    await _pets.addExperience(userId, 15);
  }
}
