import 'package:flutter/foundation.dart';
import '../models/saving_goal.dart';
import '../repositories/saving_goal_repository.dart';

class SavingGoalProvider extends ChangeNotifier {
  final SavingGoalRepository _repo;
  final String userId;
  SavingGoalProvider(this._repo, this.userId);

  List<SavingGoal> goals = [];
  bool isLoading = false;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    goals = await _repo.getAll(userId);
    isLoading = false;
    notifyListeners();
  }

  Future<void> addGoal({
    String? walletId,
    required String name,
    required int targetAmount,
    DateTime? expectedDate,
  }) async {
    await _repo.create(
        userId: userId, walletId: walletId, goalName: name, targetAmount: targetAmount, expectedCompletionDate: expectedDate);
    await load();
  }

  Future<void> editGoal(SavingGoal goal) async {
    await _repo.update(goal);
    await load();
  }

  Future<void> deleteGoal(String id) async {
    await _repo.delete(id);
    await load();
  }

  Future<SavingGoal?> refresh(String id) => _repo.getById(id);
}
