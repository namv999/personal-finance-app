import 'package:sqflite/sqflite.dart';
import '../core/database/db_helper.dart';
import '../core/utils/id_generator.dart';
import '../models/ai_suggestion.dart';

/// AI-generated monthly financial suggestions. Generation happens
/// server-side (Spring Boot + an LLM call) — this repo caches results
/// locally and exposes a stub for fetching new ones.
class AiSuggestionRepository {
  final Database _db;
  AiSuggestionRepository(this._db);

  Future<List<AiSuggestion>> getForMonth(String userId, String yyyyMM) async {
    final rows = await _db.query(Tables.aiSuggestions,
        where: 'user_id = ? AND month = ?', whereArgs: [userId, yyyyMM], orderBy: 'created_at DESC');
    return rows.map(AiSuggestion.fromMap).toList();
  }

  /// TODO(backend): call `POST {ApiEndpoints.aiSuggestions}` with the
  /// month's transaction summary and store the returned suggestion here.
  Future<AiSuggestion> requestSuggestion(String userId, String yyyyMM) async {
    // final response = await ApiClient.instance.post(ApiEndpoints.aiSuggestions,
    //     body: {'userId': userId, 'month': yyyyMM});
    // final suggestion = AiSuggestion.fromJson(response);

    // Local placeholder until the backend endpoint exists.
    final suggestion = AiSuggestion(
      id: IdGenerator.next(),
      userId: userId,
      month: yyyyMM,
      suggestionContent:
          'Kết nối backend để nhận gợi ý tài chính được tạo bởi AI dựa trên chi tiêu tháng này.',
      createdAt: DateTime.now(),
    );
    await _db.insert(Tables.aiSuggestions, suggestion.toMap());
    return suggestion;
  }
}
