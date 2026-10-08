/// Internal money movement between two of the user's own wallets.
/// Deliberately NOT a transaction — moving money into a savings wallet is
/// not "spending" and must never reduce the "total expense" figure.
class Transfer {
  final String id;
  final String userId;
  final String sourceWalletId;
  final String destinationWalletId;
  final String? goalId; // optional link to a saving goal
  final int amount;
  final DateTime transferDate;
  final String? note;
  final DateTime? updatedAt;
  final bool isDeleted;

  Transfer({
    required this.id,
    required this.userId,
    required this.sourceWalletId,
    required this.destinationWalletId,
    this.goalId,
    required this.amount,
    required this.transferDate,
    this.note,
    this.updatedAt,
    this.isDeleted = false,
  });

  factory Transfer.fromMap(Map<String, dynamic> map) => Transfer(
        id: map['id'],
        userId: map['user_id'],
        sourceWalletId: map['source_wallet_id'],
        destinationWalletId: map['destination_wallet_id'],
        goalId: map['goal_id'],
        amount: map['amount'],
        transferDate: DateTime.parse(map['transfer_date']),
        note: map['note'],
        updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
        isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'source_wallet_id': sourceWalletId,
        'destination_wallet_id': destinationWalletId,
        'goal_id': goalId,
        'amount': amount,
        'transfer_date': transferDate.toIso8601String().split('T').first,
        'note': note,
        'updated_at': updatedAt?.toIso8601String(),
        'is_deleted': isDeleted ? 1 : 0,
      };

  factory Transfer.fromJson(Map<String, dynamic> json) => Transfer(
        id: json['id'],
        userId: json['userId'],
        sourceWalletId: json['sourceWalletId'],
        destinationWalletId: json['destinationWalletId'],
        goalId: json['goalId'],
        amount: json['amount'],
        transferDate: DateTime.parse(json['transferDate']),
        note: json['note'],
        updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
        isDeleted: json['isDeleted'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'sourceWalletId': sourceWalletId,
        'destinationWalletId': destinationWalletId,
        'goalId': goalId,
        'amount': amount,
        'transferDate': transferDate.toIso8601String().split('T').first,
        'note': note,
        'updatedAt': updatedAt?.toIso8601String(),
        'isDeleted': isDeleted,
      };
}
