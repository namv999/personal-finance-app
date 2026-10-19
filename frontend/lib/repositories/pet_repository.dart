import 'package:sqflite/sqflite.dart';
import '../core/database/db_helper.dart';
import '../core/utils/clock.dart';
import '../core/utils/id_generator.dart';
import '../models/pet.dart';

/// Gamification: one pet per user (1:1 per ERD). The pet levels up as the
/// user logs transactions / hits saving milestones.
class PetRepository {
  final DatabaseExecutor _db;
  PetRepository(this._db);

  Future<void> createDefaultForUser(String userId) async {
    final pet =
        Pet(id: IdGenerator.next(), userId: userId, updatedAt: nowUtc());
    await _db.insert(Tables.pets, pet.toMap());
  }

  Future<Pet?> getForUser(String userId) async {
    final rows =
        await _db.query(Tables.pets, where: 'user_id = ?', whereArgs: [userId]);
    return rows.isEmpty ? null : Pet.fromMap(rows.first);
  }

  /// XP suy ra từ tổng, không cộng dồn, để xóa transfer thì XP tự giảm.
  Future<void> setTotalExperience(String userId, int totalXp) async {
    final pet = await getForUser(userId);
    if (pet == null) return;
    var xp = totalXp, level = 1, need = 100;
    while (xp >= need) {
      xp -= need;
      level++;
      need = level * 100;
    }
    final shape = level >= 10
        ? PetShape.large
        : level >= 5
            ? PetShape.medium
            : PetShape.small;
    final updated = pet.copyWith(experiencePoints: xp, level: level, shape: shape);
    if (updated.experiencePoints == pet.experiencePoints &&
        updated.level == pet.level &&
        updated.shape == pet.shape) {
      return;
    }
    await _db.update(Tables.pets, updated.toMap(),
        where: 'user_id = ?', whereArgs: [userId]);
  }

  Future<void> rename(String userId, String newName) async {
    await _db.update(Tables.pets,
        {'pet_name': newName, 'updated_at': nowUtcIso()},
        where: 'user_id = ?', whereArgs: [userId]);
  }
}
