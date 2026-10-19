import 'package:flutter/foundation.dart';
import '../core/utils/budget_status.dart';
import '../core/utils/clock.dart';
import '../core/utils/formatters.dart';
import '../models/monthly_budget.dart';
import '../repositories/budget_repository.dart';
import '../repositories/transaction_repository.dart';

class BudgetLine {
  final MonthlyBudget budget;
  final int spent;
  BudgetLine(this.budget, this.spent);
  BudgetStatus get status => budgetStatusOf(spent, budget.spendingLimit);
  bool get isOverLimit => status.level == BudgetLevel.exceeded;
}

class BudgetProvider extends ChangeNotifier {
  final BudgetRepository _repo;
  final TransactionRepository _txRepo;
  final String userId;
  BudgetProvider(this._repo, this._txRepo, this.userId);

  List<BudgetLine> lines = [];
  bool isLoading = false;
  DateTime selectedMonth = DateTime.parse(businessToday());

  int get totalLimit => lines.fold<int>(0, (sum, line) => sum + line.budget.spendingLimit);
  int get totalSpent => lines.fold<int>(0, (sum, line) => sum + line.spent);
  BudgetStatus get overallStatus => budgetStatusOf(totalSpent, totalLimit);

  Future<void> load({DateTime? month}) async {
    selectedMonth = month ?? selectedMonth;
    isLoading = true;
    notifyListeners();

    try {
      final yyyyMM = Formatters.yyyyMM(selectedMonth);
      final budgets = await _repo.getForMonth(userId, yyyyMM);
      final spentByCategory = await _txRepo.getExpenseByCategory(userId, yyyyMM);
      lines = budgets.map((b) => BudgetLine(b, spentByCategory[b.categoryId] ?? 0)).toList();
    } finally {
      isLoading = false;
      notifyListeners();
    }
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
