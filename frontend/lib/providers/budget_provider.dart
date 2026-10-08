import 'package:flutter/foundation.dart';
import '../core/utils/formatters.dart';
import '../models/monthly_budget.dart';
import '../repositories/budget_repository.dart';
import '../repositories/transaction_repository.dart';

class BudgetLine {
  final MonthlyBudget budget;
  final int spent;
  BudgetLine(this.budget, this.spent);
  double get progress => budget.spendingLimit <= 0 ? 0 : (spent / budget.spendingLimit).clamp(0, 1.5);
  bool get isOverLimit => spent > budget.spendingLimit;
}

class BudgetProvider extends ChangeNotifier {
  final BudgetRepository _repo;
  final TransactionRepository _txRepo;
  final String userId;
  BudgetProvider(this._repo, this._txRepo, this.userId);

  List<BudgetLine> lines = [];
  bool isLoading = false;
  DateTime selectedMonth = DateTime.now();

  Future<void> load({DateTime? month}) async {
    selectedMonth = month ?? selectedMonth;
    isLoading = true;
    notifyListeners();

    final yyyyMM = Formatters.yyyyMM(selectedMonth);
    final budgets = await _repo.getForMonth(userId, yyyyMM);
    final spentByCategory = await _txRepo.getExpenseByCategory(userId, yyyyMM);

    lines = budgets.map((b) => BudgetLine(b, spentByCategory[b.categoryId] ?? 0)).toList();
    isLoading = false;
    notifyListeners();
  }

  Future<void> setBudget({String? id, required String categoryId, required int limit}) async {
    await _repo.upsert(
        id: id, userId: userId, categoryId: categoryId, month: Formatters.yyyyMM(selectedMonth), spendingLimit: limit);
    await load();
  }

  Future<void> deleteBudget(String id) async {
    await _repo.delete(id);
    await load();
  }
}
