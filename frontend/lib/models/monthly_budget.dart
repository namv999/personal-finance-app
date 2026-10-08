class MonthlyBudget {
  final String id;
  final String userId;
  final String categoryId;
  final String month; // format YYYY-MM
  final int spendingLimit;
  final DateTime? updatedAt;
  final bool isDeleted;

  MonthlyBudget({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.month,
    required this.spendingLimit,
    this.updatedAt,
    this.isDeleted = false,
  });

  factory MonthlyBudget.fromMap(Map<String, dynamic> map) => MonthlyBudget(
        id: map['id'],
        userId: map['user_id'],
        categoryId: map['category_id'],
        month: map['month'],
        spendingLimit: map['spending_limit'],
        updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
        isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'category_id': categoryId,
        'month': month,
        'spending_limit': spendingLimit,
        'updated_at': updatedAt?.toIso8601String(),
        'is_deleted': isDeleted ? 1 : 0,
      };

  factory MonthlyBudget.fromJson(Map<String, dynamic> json) => MonthlyBudget(
        id: json['id'],
        userId: json['userId'],
        categoryId: json['categoryId'],
        month: json['month'],
        spendingLimit: json['spendingLimit'],
        updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
        isDeleted: json['isDeleted'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'categoryId': categoryId,
        'month': month,
        'spendingLimit': spendingLimit,
        'updatedAt': updatedAt?.toIso8601String(),
        'isDeleted': isDeleted,
      };
}
