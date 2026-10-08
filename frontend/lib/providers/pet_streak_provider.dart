import 'package:flutter/foundation.dart';
import '../models/pet.dart';
import '../models/saving_streak.dart';
import '../repositories/pet_repository.dart';
import '../repositories/saving_streak_repository.dart';

/// Combines the two small gamification tables (1:1 with user) into a single
/// provider since they're almost always shown together (dashboard, pet screen).
class PetStreakProvider extends ChangeNotifier {
  final PetRepository _petRepo;
  final SavingStreakRepository _streakRepo;
  final String userId;
  PetStreakProvider(this._petRepo, this._streakRepo, this.userId);

  Pet? pet;
  SavingStreak? streak;
  bool isLoading = false;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    pet = await _petRepo.getForUser(userId);
    streak = await _streakRepo.getForUser(userId);
    isLoading = false;
    notifyListeners();
  }

  Future<void> renamePet(String newName) async {
    await _petRepo.rename(userId, newName);
    await load();
  }
}
