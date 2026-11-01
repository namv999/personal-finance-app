import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../core/database/db_helper.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/utils/clock.dart';
import '../core/utils/id_generator.dart';
import '../models/ai_suggestion.dart';

enum SuggestStatus { ok, insufficientData, offline, unauthorized, syncFailed, rateLimited, unavailable, error, busy }

class SuggestOutcome {
  final SuggestStatus status;
  final String? message;
  const SuggestOutcome(this.status, [this.message]);
}

/// Local cache of backend generated suggestions, at most one per period.
class AiSuggestionRepository {
  final DatabaseExecutor _db;
  AiSuggestionRepository(this._db);

  Future<List<AiSuggestion>> getForPeriod(String userId, AiPeriod period) async {
    final rows = await _db.query(Tables.aiSuggestions,
        where: 'user_id = ? AND period_type = ? AND period_start = ?',
        whereArgs: [userId, period.type.value, dateOnly(period.start)],
        orderBy: 'created_at DESC');
    return rows.map(AiSuggestion.fromMap).toList();
  }

  Future<SuggestOutcome> requestSuggestion(String userId, AiPeriodType type) async {
    if (!ApiClient.instance.hasToken) return const SuggestOutcome(SuggestStatus.offline);
    dynamic res;
    try {
      res = await ApiClient.instance.post(ApiEndpoints.aiSuggestions,
          body: {'period_type': type.value}, receiveTimeout: const Duration(seconds: 60));
    } on NetworkException {
      return const SuggestOutcome(SuggestStatus.offline);
    } on ApiException catch (e) {
      if (e.statusCode == 401) return SuggestOutcome(SuggestStatus.unauthorized, e.message);
      if (e.statusCode == 429 || e.code == 'AI_RATE_LIMITED') return SuggestOutcome(SuggestStatus.rateLimited, e.message);
      if (e.statusCode == 503 || e.code == 'AI_UNAVAILABLE') return SuggestOutcome(SuggestStatus.unavailable, e.message);
      return SuggestOutcome(SuggestStatus.error, e.message);
    }
    if (res is! Map) return const SuggestOutcome(SuggestStatus.error);
    if (res['status'] == 'INSUFFICIENT_DATA') {
      return SuggestOutcome(SuggestStatus.insufficientData, res['message']?.toString());
    }
    final content = res['content'];
    final start = DateTime.tryParse('${res['period_start']}');
    final end = DateTime.tryParse('${res['period_end']}');
    if (res['status'] != 'OK' || content is! String || content.trim().isEmpty || start == null || end == null) {
      return const SuggestOutcome(SuggestStatus.error);
    }
    final suggestion = AiSuggestion(
      id: IdGenerator.next(), userId: userId, periodType: type, periodStart: start,
      periodEnd: end, suggestionContent: content.trim(),
      suggestedData: res['data'] == null ? null : jsonEncode(res['data']), createdAt: nowUtc(),
    );
    await _db.insert(Tables.aiSuggestions, suggestion.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    return const SuggestOutcome(SuggestStatus.ok);
  }
}
