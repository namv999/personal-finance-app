import 'package:flutter/foundation.dart';

import '../models/ai_suggestion.dart';
import '../repositories/ai_suggestion_repository.dart';
import '../repositories/sync_service.dart';

class AiSuggestionProvider extends ChangeNotifier {
  final AiSuggestionRepository _repo;
  final SyncService _sync;
  final String userId;
  AiSuggestionProvider(this._repo, this._sync, this.userId);

  AiPeriodType periodType = AiPeriodType.month;
  AiSuggestion? current;
  bool isLoading = false;
  bool isRequesting = false;
  bool _disposed = false;

  List<AiSuggestion> get suggestions => current == null ? const [] : [current!];
  AiPeriod get targetPeriod => AiPeriod.next(periodType);

  @override
  void notifyListeners() { if (!_disposed) super.notifyListeners(); }

  @override
  void dispose() { _disposed = true; super.dispose(); }

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    try {
      final rows = await _repo.getForPeriod(userId, targetPeriod);
      current = rows.isEmpty ? null : rows.first;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setType(AiPeriodType type) async {
    if (type == periodType) return;
    periodType = type;
    current = null;
    await load();
  }

  Future<SuggestOutcome> requestNew() async {
    if (isRequesting) return const SuggestOutcome(SuggestStatus.busy);
    isRequesting = true;
    notifyListeners();
    final type = periodType;
    try {
      final sync = await _sync.syncAll(userId);
      if (!sync.ok) {
        if (sync.error == 'NO_TOKEN') return const SuggestOutcome(SuggestStatus.offline);
        if (sync.unauthorized) return const SuggestOutcome(SuggestStatus.unauthorized);
        return SuggestOutcome(SuggestStatus.syncFailed, sync.error);
      }
      final outcome = await _repo.requestSuggestion(userId, type);
      if (outcome.status == SuggestStatus.ok && type == periodType) await load();
      return outcome;
    } finally {
      isRequesting = false;
      notifyListeners();
    }
  }
}
