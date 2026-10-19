import '../core/utils/clock.dart';

import 'category.dart';

class FinanceTransaction {
  final String id;
  final String userId;
  final String walletId;
  final String? categoryId;
  final CategoryType type;
  final int amount;
  final String? note;
  final DateTime transactionDate;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isDeleted;

  FinanceTransaction({
    required this.id,
    required this.userId,
    required this.walletId,
    this.categoryId,
    required this.type,
    required this.amount,
    this.note,
    required this.transactionDate,
    required this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
  });

  factory FinanceTransaction.fromMap(Map<String, dynamic> map) => FinanceTransaction(
        id: map['id'],
        userId: map['user_id'],
        walletId: map['wallet_id'],
        categoryId: map['category_id'],
        type: CategoryTypeX.fromValue(map['type']),
        amount: map['amount'],
        note: map['note'],
        transactionDate: DateTime.parse(map['transaction_date']),
        createdAt: DateTime.parse(map['created_at']),
        updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
        isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'wallet_id': walletId,
        'category_id': categoryId,
        'type': type.value,
        'amount': amount,
        'note': note,
        'transaction_date': dateOnly(transactionDate),
        'created_at': toUtcIso(createdAt),
        'updated_at': toUtcIsoN(updatedAt),
        'is_deleted': isDeleted ? 1 : 0,
      };

  factory FinanceTransaction.fromJson(Map<String, dynamic> json) => FinanceTransaction(
        id: json['id'],
        userId: json['userId'],
        walletId: json['walletId'],
        categoryId: json['categoryId'],
        type: CategoryTypeX.fromValue(json['type']),
        amount: json['amount'],
        note: json['note'],
        transactionDate: DateTime.parse(json['transactionDate']),
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
        isDeleted: json['isDeleted'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'walletId': walletId,
        'categoryId': categoryId,
        'type': type.value,
        'amount': amount,
        'note': note,
        'transactionDate': dateOnly(transactionDate),
        'createdAt': toUtcIso(createdAt),
        'updatedAt': toUtcIsoN(updatedAt),
        'isDeleted': isDeleted,
      };

  FinanceTransaction copyWith({
    String? walletId,
    String? categoryId,
    CategoryType? type,
    int? amount,
    String? note,
    DateTime? transactionDate,
    bool? isDeleted,
  }) =>
      FinanceTransaction(
        id: id,
        userId: userId,
        walletId: walletId ?? this.walletId,
        categoryId: categoryId ?? this.categoryId,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        note: note ?? this.note,
        transactionDate: transactionDate ?? this.transactionDate,
        createdAt: createdAt,
        updatedAt: nowUtc(),
        isDeleted: isDeleted ?? this.isDeleted,
      );
}
