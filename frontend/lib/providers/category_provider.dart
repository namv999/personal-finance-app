import 'package:flutter/foundation.dart';
import '../models/category.dart';
import '../repositories/category_repository.dart';

class CategoryProvider extends ChangeNotifier {
  final CategoryRepository _repo;
  final String userId;
  CategoryProvider(this._repo, this.userId);

  List<TransactionCategory> categories = [];
  List<TransactionCategory> _displayCategories = [];
  bool isLoading = false;
  String? error;
  bool _loaded = false;

  List<TransactionCategory> get incomeCategories =>
      categories.where((c) => c.type == CategoryType.income).toList();
  List<TransactionCategory> get expenseCategories =>
      categories.where((c) => c.type == CategoryType.expense).toList();

  Future<void> load() async {
    if (!_loaded) {
      isLoading = true;
      notifyListeners();
    }
    try {
      _displayCategories = await _repo.getAllForDisplay(userId);
      categories = _displayCategories.where((c) => !c.isDeleted).toList();
      _loaded = true;
      error = null;
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addCategory(String name, CategoryType type,
      {String? color, String? icon}) async {
    await _repo.create(
        userId: userId,
        categoryName: name,
        type: type,
        color: color,
        icon: icon);
    await load();
  }

  Future<void> editCategory(TransactionCategory category) async {
    await _repo.update(category);
    await load();
  }

  Future<void> deleteCategory(String id) async {
    await _repo.delete(id);
    await load();
  }

  TransactionCategory? byId(String? id) {
    if (id == null) return null;
    for (final c in _displayCategories) {
      if (c.id == id) return c;
    }
    return null;
  }
}
