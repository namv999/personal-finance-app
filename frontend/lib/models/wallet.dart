class Wallet {
  final String id;
  final String userId;
  final String walletName;
  final String walletType; // free-form: SPENDING, SAVINGS, or user-defined
  final int currentBalance; // cached value, periodically recomputed
  final String? color;
  final String? icon;
  final DateTime? updatedAt;
  final bool isDeleted;

  Wallet({
    required this.id,
    required this.userId,
    required this.walletName,
    required this.walletType,
    this.currentBalance = 0,
    this.color,
    this.icon,
    this.updatedAt,
    this.isDeleted = false,
  });

  factory Wallet.fromMap(Map<String, dynamic> map) => Wallet(
        id: map['id'],
        userId: map['user_id'],
        walletName: map['wallet_name'],
        walletType: map['wallet_type'],
        currentBalance: map['current_balance'] ?? 0,
        color: map['color'],
        icon: map['icon'],
        updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
        isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'wallet_name': walletName,
        'wallet_type': walletType,
        'current_balance': currentBalance,
        'color': color,
        'icon': icon,
        'updated_at': updatedAt?.toIso8601String(),
        'is_deleted': isDeleted ? 1 : 0,
      };

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
        id: json['id'],
        userId: json['userId'],
        walletName: json['walletName'],
        walletType: json['walletType'],
        currentBalance: json['currentBalance'] ?? 0,
        color: json['color'],
        icon: json['icon'],
        updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
        isDeleted: json['isDeleted'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'walletName': walletName,
        'walletType': walletType,
        'currentBalance': currentBalance,
        'color': color,
        'icon': icon,
        'updatedAt': updatedAt?.toIso8601String(),
        'isDeleted': isDeleted,
      };

  Wallet copyWith({
    String? walletName,
    String? walletType,
    int? currentBalance,
    String? color,
    String? icon,
    bool? isDeleted,
  }) =>
      Wallet(
        id: id,
        userId: userId,
        walletName: walletName ?? this.walletName,
        walletType: walletType ?? this.walletType,
        currentBalance: currentBalance ?? this.currentBalance,
        color: color ?? this.color,
        icon: icon ?? this.icon,
        updatedAt: DateTime.now(),
        isDeleted: isDeleted ?? this.isDeleted,
      );
}
