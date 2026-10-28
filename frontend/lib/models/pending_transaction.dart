import '../core/utils/clock.dart';
import 'category.dart';

enum PendingSource { sms, image, text }

enum PendingStatus { needsAi, pending, confirmed, rejected }

extension PendingSourceX on PendingSource {
  String get value => name.toUpperCase();

  static PendingSource fromValue(String? value) =>
      PendingSource.values.firstWhere((source) => source.value == value,
          orElse: () => PendingSource.text);
}

extension PendingStatusX on PendingStatus {
  String get value => switch (this) {
        PendingStatus.needsAi => 'NEEDS_AI',
        PendingStatus.pending => 'PENDING',
        PendingStatus.confirmed => 'CONFIRMED',
        PendingStatus.rejected => 'REJECTED',
      };

  static PendingStatus fromValue(String? value) =>
      PendingStatus.values.firstWhere((status) => status.value == value,
          orElse: () => PendingStatus.needsAi);
}

class PendingTransaction {
  final String id;
  final String userId;
  final PendingSource source;
  final String maskedContent;
  final int? amount;
  final CategoryType? type;
  final DateTime? transactionDate;
  final String? note;
  final String? suggestedCategoryId;
  final double? confidence;
  final String sourceHash;
  final PendingStatus status;
  final DateTime? updatedAt;

  const PendingTransaction({
    required this.id,
    required this.userId,
    required this.source,
    required this.maskedContent,
    this.amount,
    this.type,
    this.transactionDate,
    this.note,
    this.suggestedCategoryId,
    this.confidence,
    required this.sourceHash,
    required this.status,
    this.updatedAt,
  });

  factory PendingTransaction.fromMap(Map<String, dynamic> map) =>
      PendingTransaction(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        source: PendingSourceX.fromValue(map['source'] as String?),
        maskedContent: map['masked_content'] as String? ?? '',
        amount: map['amount'] as int?,
        type: map['type'] == null
            ? null
            : CategoryTypeX.fromValue(map['type'] as String),
        transactionDate: map['transaction_date'] == null
            ? null
            : DateTime.parse(map['transaction_date'] as String),
        note: map['note'] as String?,
        suggestedCategoryId: map['suggested_category_id'] as String?,
        confidence: (map['confidence'] as num?)?.toDouble(),
        sourceHash: map['source_hash'] as String,
        status: PendingStatusX.fromValue(map['status'] as String?),
        updatedAt: map['updated_at'] == null
            ? null
            : DateTime.parse(map['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'source': source.value,
        'masked_content': maskedContent,
        'amount': amount,
        'type': type?.value,
        'transaction_date':
            transactionDate == null ? null : dateOnly(transactionDate!),
        'note': note,
        'suggested_category_id': suggestedCategoryId,
        'confidence': confidence,
        'source_hash': sourceHash,
        'status': status.value,
        'updated_at': toUtcIsoN(updatedAt),
      };
}
