class AppUser {
  final String id;
  final String fullName;
  final String? email;
  final String passwordHash;
  final int? monthlyIncome; // reserved for a future feature, unused in MVP
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isDeleted;

  AppUser({
    required this.id,
    required this.fullName,
    this.email,
    required this.passwordHash,
    this.monthlyIncome,
    required this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        id: map['id'] as String,
        fullName: map['full_name'] as String,
        email: map['email'] as String?,
        passwordHash: map['password_hash'] as String,
        monthlyIncome: map['monthly_income'] as int?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
        isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'full_name': fullName,
        'email': email,
        'password_hash': passwordHash,
        'monthly_income': monthlyIncome,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        'is_deleted': isDeleted ? 1 : 0,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'],
        fullName: json['fullName'],
        email: json['email'],
        passwordHash: json['passwordHash'] ?? '',
        monthlyIncome: json['monthlyIncome'],
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
        isDeleted: json['isDeleted'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'monthlyIncome': monthlyIncome,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'isDeleted': isDeleted,
      };

  AppUser copyWith({String? fullName, String? email, int? monthlyIncome}) => AppUser(
        id: id,
        fullName: fullName ?? this.fullName,
        email: email ?? this.email,
        passwordHash: passwordHash,
        monthlyIncome: monthlyIncome ?? this.monthlyIncome,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        isDeleted: isDeleted,
      );
}
