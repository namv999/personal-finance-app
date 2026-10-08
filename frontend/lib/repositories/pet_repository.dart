import 'package:sqflite/sqflite.dart';
import '../core/database/db_helper.dart';
import '../core/utils/id_generator.dart';
import '../models/pet.dart';

/// Gamification: one pet per user (1:1 per ERD). The pet levels up as the
/// user logs transactions / hits saving milestones.
class PetRepository {
  final Database _db;
  PetRepository(this._db);

  Future<void> createDefaultForUser(String userId) async {
    final pet = Pet(id: IdGenerator.next(), userId: userId, updatedAt: DateTime.now());
    await _db.insert(Tables.pets, pet.toMap());
  }

  Future<Pet?> getForUser(String userId) async {
    final rows = await _db.query(Tables.pets, where: 'user_id = ?', whereArgs: [userId]);
    return rows.isEmpty ? null : Pet.fromMap(rows.first);
  }

  Future<void> addExperience(String userId, int xp) async {
    final pet = await getForUser(userId);
    if (pet == null) return;

    var newXp = pet.experiencePoints + xp;
    var newLevel = pet.level;
    var xpForNext = newLevel * 100;
    while (newXp >= xpForNext) {
      newXp -= xpForNext;
      newLevel++;
      xpForNext = newLevel * 100;
    }
    var shape = pet.shape;
    if (newLevel >= 10) {
      shape = PetShape.large;
    } else if (newLevel >= 5) {
      shape = PetShape.medium;
    } else {
      shape = PetShape.small;
    }

    final updated = pet.copyWith(experiencePoints: newXp, level: newLevel, shape: shape);
    await _db.update(Tables.pets, updated.toMap(), where: 'user_id = ?', whereArgs: [userId]);
  }

  Future<void> rename(String userId, String newName) async {
    await _db.update(Tables.pets, {'pet_name': newName, 'updated_at': DateTime.now().toIso8601String()},
        where: 'user_id = ?', whereArgs: [userId]);
  }
}
