import 'package:sqflite/sqflite.dart';

import '../core/database/db_helper.dart';
import '../core/utils/clock.dart';
import '../core/utils/id_generator.dart';
import '../models/ai_suggestion.dart';

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

  /// TODO(backend): request the API, which computes all financial figures.
  Future<AiSuggestion> requestSuggestion(String userId, AiPeriod period) async {
    final suggestion = AiSuggestion(
      id: IdGenerator.next(),
      userId: userId,
      periodType: period.type,
      periodStart: period.start,
      periodEnd: period.end,
      suggestionContent: 'Kết nối backend để nhận gợi ý tài chính được tạo bởi AI.',
      createdAt: nowUtc(),
    );
    await _db.insert(Tables.aiSuggestions, suggestion.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return suggestion;
  }
}
