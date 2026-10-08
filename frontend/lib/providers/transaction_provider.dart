import 'package:flutter/foundation.dart';
import '../core/utils/formatters.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../repositories/pet_repository.dart';
import '../repositories/transaction_repository.dart';

class TransactionProvider extends ChangeNotifier {
  final TransactionRepository _repo;
  final PetRepository _pets;
  final String userId;
  TransactionProvider(this._repo, this._pets, this.userId);

  List<FinanceTransaction> transactions = [];
  Map<CategoryType, int> monthTotals = {CategoryType.income: 0, CategoryType.expense: 0};
  bool isLoading = false;

  Future<void> load({String? walletId}) async {
    isLoading = true;
    notifyListeners();
    transactions = await _repo.getAll(userId, walletId: walletId, limit: 200);

    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1);
    final to = DateTime(now.year, now.month + 1, 0);
    monthTotals = await _repo.getTotalsByType(userId, from, to);

    isLoading = false;
    notifyListeners();
  }

  Future<void> addTransaction({
    required String walletId,
    String? categoryId,
    required CategoryType type,
    required int amount,
    String? note,
    required DateTime date,
  }) async {
    await _repo.create(
      userId: userId,
      walletId: walletId,
      categoryId: categoryId,
      type: type,
      amount: amount,
      note: note,
      transactionDate: date,
    );
    // Small XP reward for logging activity — nudges good tracking habits.
    await _pets.addExperience(userId, 5);
    await load();
  }

  Future<void> editTransaction(FinanceTransaction tx) async {
    await _repo.update(tx);
    await load();
  }

  Future<void> deleteTransaction(String id, String walletId) async {
    await _repo.delete(id, walletId);
    await load();
  }

  Future<Map<String, int>> expenseByCategoryForMonth(DateTime month) =>
      _repo.getExpenseByCategory(userId, Formatters.yyyyMM(month));
}
