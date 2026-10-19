import 'package:flutter/foundation.dart';

import '../models/ai_suggestion.dart';
import '../repositories/ai_suggestion_repository.dart';

class AiSuggestionProvider extends ChangeNotifier {
  final AiSuggestionRepository _repo;
  final String userId;
  AiSuggestionProvider(this._repo, this.userId);

  List<AiSuggestion> suggestions = [];
  bool isLoading = false;

  Future<void> load({AiPeriodType type = AiPeriodType.month, DateTime? date}) async {
    isLoading = true;
    notifyListeners();
    try {
      suggestions = await _repo.getForPeriod(userId, AiPeriod.of(type, date));
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> requestNew({
    AiPeriodType type = AiPeriodType.month,
    DateTime? date,
  }) async {
    await _repo.requestSuggestion(userId, AiPeriod.of(type, date));
    await load(type: type, date: date);
  }
}
