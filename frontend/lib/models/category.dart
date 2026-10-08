enum CategoryType { income, expense }

extension CategoryTypeX on CategoryType {
  String get value => this == CategoryType.income ? 'INCOME' : 'EXPENSE';
  static CategoryType fromValue(String v) =>
      v == 'INCOME' ? CategoryType.income : CategoryType.expense;
}

class TransactionCategory {
  final String id;
  final String? userId; // NULL => system default category, shared by all users
  final String categoryName;
  final CategoryType type;
  final String? color;
  final String? icon;
  final DateTime? updatedAt;
  final bool isDeleted;

  TransactionCategory({
    required this.id,
    this.userId,
    required this.categoryName,
    required this.type,
    this.color,
    this.icon,
    this.updatedAt,
    this.isDeleted = false,
  });

  bool get isSystemDefault => userId == null;

  factory TransactionCategory.fromMap(Map<String, dynamic> map) => TransactionCategory(
        id: map['id'],
        userId: map['user_id'],
        categoryName: map['category_name'],
        type: CategoryTypeX.fromValue(map['type']),
        color: map['color'],
        icon: map['icon'],
        updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
        isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'category_name': categoryName,
        'type': type.value,
        'color': color,
        'icon': icon,
        'updated_at': updatedAt?.toIso8601String(),
        'is_deleted': isDeleted ? 1 : 0,
      };

  factory TransactionCategory.fromJson(Map<String, dynamic> json) => TransactionCategory(
        id: json['id'],
        userId: json['userId'],
        categoryName: json['categoryName'],
        type: CategoryTypeX.fromValue(json['type']),
        color: json['color'],
        icon: json['icon'],
        updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
        isDeleted: json['isDeleted'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'categoryName': categoryName,
        'type': type.value,
        'color': color,
        'icon': icon,
        'updatedAt': updatedAt?.toIso8601String(),
        'isDeleted': isDeleted,
      };

  TransactionCategory copyWith({
    String? categoryName,
    CategoryType? type,
    String? color,
    String? icon,
    bool? isDeleted,
  }) =>
      TransactionCategory(
        id: id,
        userId: userId,
        categoryName: categoryName ?? this.categoryName,
        type: type ?? this.type,
        color: color ?? this.color,
        icon: icon ?? this.icon,
        updatedAt: DateTime.now(),
        isDeleted: isDeleted ?? this.isDeleted,
      );
}
