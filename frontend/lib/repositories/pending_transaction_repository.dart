import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../core/database/db_helper.dart';
import '../core/database/txn_ext.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/utils/clock.dart';
import '../core/utils/id_generator.dart';
import '../core/utils/text_masker.dart';
import '../models/category.dart';
import '../models/pending_transaction.dart';
import '../models/transaction.dart';
import 'transaction_repository.dart';

enum AiRunResult { nothing, done, offline, rateLimited, unavailable, error }

enum ImageRunStatus {
  added,
  duplicate,
  notTransaction,
  failed,
  offline,
  rateLimited,
  unavailable,
  unauthorized,
  tooLarge,
  unsupported,
  busy,
  error,
}

class ImageRunResult {
  final ImageRunStatus status;
  const ImageRunResult(this.status);
}

class PendingTransactionRepository {
  final DatabaseExecutor _db;
  PendingTransactionRepository(this._db);

  static const maxBatch = 10;
  static const maxContentLength = 1000;

  Future<List<PendingTransaction>> getByStatus(
      String userId, List<PendingStatus> statuses) async {
    if (statuses.isEmpty) return [];
    final marks = List.filled(statuses.length, '?').join(',');
    final rows = await _db.query(
      Tables.pendingTransactions,
      where: 'user_id = ? AND status IN ($marks)',
      whereArgs: [userId, ...statuses.map((status) => status.value)],
      orderBy: 'updated_at DESC',
    );
    return rows.map(PendingTransaction.fromMap).toList();
  }

  /// Saves only masked content. Returns null for duplicate source text.
  Future<PendingTransaction?> addRaw(String userId, String raw,
      {PendingSource source = PendingSource.text, DateTime? receivedAt}) async {
    final normalized = raw.trim();
    if (normalized.isEmpty || normalized.length > maxContentLength) {
      throw ArgumentError('Tin nhắn phải có từ 1 đến $maxContentLength ký tự');
    }
    final hash = TextMasker.hash(userId, normalized);
    final duplicate = await _db.query(
      Tables.pendingTransactions,
      columns: ['id'],
      where: 'user_id = ? AND source_hash = ?',
      whereArgs: [userId, hash],
      limit: 1,
    );
    if (duplicate.isNotEmpty) return null;

    // Keep hashing the original message so pasted and scanned copies deduplicate.
    final withDate = receivedAt == null
        ? normalized
        : 'Nhận ngày ${_ymd(receivedAt.toLocal())}: $normalized';
    final maskedContent = TextMasker.mask(withDate);
    final boundedMaskedContent = String.fromCharCodes(
      maskedContent.runes.take(maxContentLength),
    );
    final pending = PendingTransaction(
      id: IdGenerator.next(),
      userId: userId,
      source: source,
      maskedContent: boundedMaskedContent,
      sourceHash: hash,
      status: PendingStatus.needsAi,
      updatedAt: nowUtc(),
    );
    try {
      await _db.insert(Tables.pendingTransactions, pending.toMap());
    } on DatabaseException {
      // A second submit may win the unique (user_id, source_hash) constraint.
      final duplicate = await _db.query(
        Tables.pendingTransactions,
        columns: ['id'],
        where: 'user_id = ? AND source_hash = ?',
        whereArgs: [userId, hash],
        limit: 1,
      );
      if (duplicate.isNotEmpty) return null;
      rethrow;
    }
    return pending;
  }

  static String _ymd(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Sends up to ten NEEDS_AI items. Request timeout is longer because the
  /// backend may retry Gemini and switch to its fallback model.
  Future<AiRunResult> processNeedsAi(String userId) async {
    final rows = await _db.query(
      Tables.pendingTransactions,
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, PendingStatus.needsAi.value],
      orderBy: 'updated_at ASC',
      limit: maxBatch,
    );
    if (rows.isEmpty) return AiRunResult.nothing;
    if (!ApiClient.instance.hasToken) return AiRunResult.offline;

    final catRows = await _db.query(
      Tables.categories,
      columns: ['id', 'category_name', 'type'],
      where: 'is_deleted = 0 AND (user_id IS NULL OR user_id = ?)',
      whereArgs: [userId],
      orderBy: 'category_name',
      limit: 100,
    );
    final categoryTypes = {
      for (final category in catRows)
        category['id'] as String: category['type'] as String,
    };

    dynamic response;
    try {
      response = await ApiClient.instance.post(
        ApiEndpoints.aiParseText,
        body: {
          'items': [
            for (final row in rows)
              {
                'ref': row['id'],
                'source': row['source'],
                'content': row['masked_content'],
              },
          ],
          'categories': [
            for (final category in catRows)
              {
                'id': category['id'],
                'category_name': category['category_name'],
                'type': category['type'],
              },
          ],
        },
        receiveTimeout: const Duration(seconds: 60),
      );
    } on NetworkException {
      return AiRunResult.offline;
    } on ApiException catch (error) {
      if (error.statusCode == 429 || error.code == 'AI_RATE_LIMITED') {
        return AiRunResult.rateLimited;
      }
      if (error.statusCode == 503 || error.code == 'AI_UNAVAILABLE') {
        return AiRunResult.unavailable;
      }
      return AiRunResult.error;
    }

    final results = response is Map ? response['results'] : null;
    if (results is! List) return AiRunResult.error;
    final knownIds = {for (final row in rows) row['id'] as String};
    final today = businessToday();

    for (final rawResult in results) {
      if (rawResult is! Map) continue;
      final ref = rawResult['ref'];
      if (ref is! String || !knownIds.contains(ref)) continue;

      switch (rawResult['status']) {
        case 'NOT_A_TRANSACTION':
          await _setStatus(ref, PendingStatus.rejected,
              from: PendingStatus.needsAi);
          break;
        case 'PARSED':
          final suggestion = rawResult['suggestion'];
          if (suggestion is! Map) break;
          final rawAmount = suggestion['amount'];
          if (rawAmount is! num ||
              !rawAmount.isFinite ||
              rawAmount <= 0 ||
              rawAmount % 1 != 0) {
            break;
          }
          final amount = rawAmount.toInt();
          final type = suggestion['type'];
          if (type != 'INCOME' && type != 'EXPENSE') break;

          var date = suggestion['transaction_date'];
          if (date is! String ||
              date.length != 10 ||
              DateTime.tryParse(date) == null ||
              date.compareTo(today) > 0) {
            date = today;
          }
          final rawCategoryId = suggestion['category_id'];
          final categoryId =
              rawCategoryId is String && categoryTypes[rawCategoryId] == type
                  ? rawCategoryId
                  : null;
          final confidence = suggestion['confidence'];

          await _db.update(
            Tables.pendingTransactions,
            {
              'amount': amount,
              'type': type,
              'transaction_date': date,
              'note': suggestion['note']?.toString().trim(),
              'suggested_category_id': categoryId,
              'confidence': confidence is num ? confidence.toDouble() : null,
              'status': PendingStatus.pending.value,
              'updated_at': nowUtcIso(),
            },
            where: 'id = ? AND status = ?',
            whereArgs: [ref, PendingStatus.needsAi.value],
          );
          break;
        default:
          // FAILED and unknown statuses stay in NEEDS_AI for a later retry.
          break;
      }
    }
    return AiRunResult.done;
  }

  static const maxImageBytes = 3 * 1024 * 1024;

  /// Detects supported image formats from their signatures.
  static String? sniffMime(Uint8List bytes) {
    if (bytes.length < 12) return null;
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    return null;
  }

  Future<bool> _imageHashExists(String userId, String hash) async =>
      (await _db.query(
        Tables.pendingTransactions,
        columns: ['id'],
        where: 'user_id = ? AND source_hash = ?',
        whereArgs: [userId, hash],
        limit: 1,
      ))
          .isNotEmpty;

  /// Parses one image online. The image itself is never persisted locally.
  Future<ImageRunResult> processImage(String userId, Uint8List bytes) async {
    if (bytes.length > maxImageBytes) {
      return const ImageRunResult(ImageRunStatus.tooLarge);
    }
    final mime = sniffMime(bytes);
    if (mime == null) {
      return const ImageRunResult(ImageRunStatus.unsupported);
    }
    if (!ApiClient.instance.hasToken) {
      return const ImageRunResult(ImageRunStatus.offline);
    }

    final hash = TextMasker.hashBytes(userId, bytes);
    if (await _imageHashExists(userId, hash)) {
      return const ImageRunResult(ImageRunStatus.duplicate);
    }

    final categoryRows = await _db.query(
      Tables.categories,
      columns: ['id', 'category_name', 'type'],
      where: 'is_deleted = 0 AND (user_id IS NULL OR user_id = ?)',
      whereArgs: [userId],
      orderBy: 'category_name',
      limit: 100,
    );
    final categoryTypes = {
      for (final category in categoryRows)
        category['id'] as String: category['type'] as String,
    };

    dynamic response;
    try {
      response = await ApiClient.instance.post(
        ApiEndpoints.aiParseImage,
        body: {
          'image_base64': base64Encode(bytes),
          'mime_type': mime,
          'categories': [
            for (final category in categoryRows)
              {
                'id': category['id'],
                'category_name': category['category_name'],
                'type': category['type'],
              },
          ],
        },
        receiveTimeout: const Duration(seconds: 60),
      );
    } on NetworkException {
      return const ImageRunResult(ImageRunStatus.offline);
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        return const ImageRunResult(ImageRunStatus.unauthorized);
      }
      if (error.statusCode == 429 || error.code == 'AI_RATE_LIMITED') {
        return const ImageRunResult(ImageRunStatus.rateLimited);
      }
      if (error.statusCode == 503 || error.code == 'AI_UNAVAILABLE') {
        return const ImageRunResult(ImageRunStatus.unavailable);
      }
      return const ImageRunResult(ImageRunStatus.error);
    }

    if (response is! Map) return const ImageRunResult(ImageRunStatus.error);
    final responseStatus = response['status'];
    if (responseStatus == 'NOT_A_TRANSACTION') {
      return const ImageRunResult(ImageRunStatus.notTransaction);
    }
    final suggestion = response['suggestion'];
    if (responseStatus != 'PARSED' || suggestion is! Map) {
      return const ImageRunResult(ImageRunStatus.failed);
    }

    final rawAmount = suggestion['amount'];
    if (rawAmount is! num ||
        !rawAmount.isFinite ||
        rawAmount <= 0 ||
        rawAmount % 1 != 0) {
      return const ImageRunResult(ImageRunStatus.failed);
    }
    final type = suggestion['type'];
    if (type != 'INCOME' && type != 'EXPENSE') {
      return const ImageRunResult(ImageRunStatus.failed);
    }
    final today = businessToday();
    var date = suggestion['transaction_date'];
    if (date is! String ||
        date.length != 10 ||
        DateTime.tryParse(date) == null ||
        date.compareTo(today) > 0) {
      date = today;
    }
    final rawCategoryId = suggestion['category_id'];
    final categoryId =
        rawCategoryId is String && categoryTypes[rawCategoryId] == type
            ? rawCategoryId
            : null;
    final confidence = suggestion['confidence'];
    final rawNote = suggestion['note']?.toString().trim();

    final item = PendingTransaction(
      id: IdGenerator.next(),
      userId: userId,
      source: PendingSource.image,
      maskedContent: '[Ảnh]',
      amount: rawAmount.toInt(),
      type: CategoryTypeX.fromValue(type as String),
      transactionDate: DateTime.parse(date),
      note: rawNote == null || rawNote.isEmpty ? null : rawNote,
      suggestedCategoryId: categoryId,
      confidence: confidence is num ? confidence.toDouble() : null,
      sourceHash: hash,
      status: PendingStatus.pending,
      updatedAt: nowUtc(),
    );
    try {
      await _db.insert(Tables.pendingTransactions, item.toMap());
    } on DatabaseException {
      if (await _imageHashExists(userId, hash)) {
        return const ImageRunResult(ImageRunStatus.duplicate);
      }
      rethrow;
    }
    return const ImageRunResult(ImageRunStatus.added);
  }

  /// Creates the ledger transaction and closes the pending item atomically.
  Future<FinanceTransaction> confirm({
    required String userId,
    required String pendingId,
    required String walletId,
    required int amount,
    required CategoryType type,
    required DateTime date,
    String? note,
    String? categoryId,
  }) =>
      _db.inTxn((executor) async {
        final rows = await executor.query(
          Tables.pendingTransactions,
          where: 'id = ? AND user_id = ? AND status = ?',
          whereArgs: [pendingId, userId, PendingStatus.pending.value],
          limit: 1,
        );
        if (rows.isEmpty) {
          throw StateError('Đề xuất không còn ở trạng thái chờ duyệt');
        }
        final pending = PendingTransaction.fromMap(rows.first);

        var validCategoryId = categoryId;
        if (validCategoryId != null) {
          final categoryRows = await executor.query(
            Tables.categories,
            columns: ['type'],
            where:
                'id = ? AND is_deleted = 0 AND (user_id IS NULL OR user_id = ?)',
            whereArgs: [validCategoryId, userId],
            limit: 1,
          );
          if (categoryRows.isEmpty ||
              categoryRows.first['type'] != type.value) {
            validCategoryId = null;
          }
        }

        final transaction = await TransactionRepository(executor).create(
          userId: userId,
          walletId: walletId,
          categoryId: validCategoryId,
          type: type,
          amount: amount,
          note: note,
          transactionDate: date,
          source: TransactionSourceX.fromValue(pending.source.value),
        );
        await executor.update(
          Tables.pendingTransactions,
          {
            'status': PendingStatus.confirmed.value,
            'updated_at': nowUtcIso(),
          },
          where: 'id = ? AND status = ?',
          whereArgs: [pendingId, PendingStatus.pending.value],
        );
        return transaction;
      });

  Future<void> reject(String userId, String pendingId) => _db.update(
        Tables.pendingTransactions,
        {
          'status': PendingStatus.rejected.value,
          'updated_at': nowUtcIso(),
        },
        where: "id = ? AND user_id = ? AND status IN ('NEEDS_AI','PENDING')",
        whereArgs: [pendingId, userId],
      );

  Future<void> _setStatus(String id, PendingStatus status,
          {required PendingStatus from}) =>
      _db.update(
        Tables.pendingTransactions,
        {'status': status.value, 'updated_at': nowUtcIso()},
        where: 'id = ? AND status = ?',
        whereArgs: [id, from.value],
      );
}
