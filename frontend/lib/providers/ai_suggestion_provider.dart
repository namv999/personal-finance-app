import 'package:flutter/foundation.dart';
import '../core/utils/formatters.dart';
import '../models/ai_suggestion.dart';
import '../repositories/ai_suggestion_repository.dart';

class AiSuggestionProvider extends ChangeNotifier {
  final AiSuggestionRepository _repo;
  final String userId;
  AiSuggestionProvider(this._repo, this.userId);

  List<AiSuggestion> suggestions = [];
  bool isLoading = false;

  Future<void> load({DateTime? month}) async {
    isLoading = true;
    notifyListeners();
    suggestions = await _repo.getForMonth(userId, Formatters.yyyyMM(month ?? DateTime.now()));
    isLoading = false;
    notifyListeners();
  }

  Future<void> requestNew({DateTime? month}) async {
    await _repo.requestSuggestion(userId, Formatters.yyyyMM(month ?? DateTime.now()));
    await load(month: month);
  }
}
