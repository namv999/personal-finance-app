enum GoalStatus { inProgress, completed, cancelled }

extension GoalStatusX on GoalStatus {
  String get value {
    switch (this) {
      case GoalStatus.inProgress:
        return 'IN_PROGRESS';
      case GoalStatus.completed:
        return 'COMPLETED';
      case GoalStatus.cancelled:
        return 'CANCELLED';
    }
  }

  static GoalStatus fromValue(String? v) {
    switch (v) {
      case 'COMPLETED':
        return GoalStatus.completed;
      case 'CANCELLED':
        return GoalStatus.cancelled;
      default:
        return GoalStatus.inProgress;
    }
  }
}

class SavingGoal {
  final String id;
  final String userId;
  final String? walletId; // savings wallet linked to this goal, if any
  final String goalName;
  final int targetAmount;
  final int savedAmount; // cached value, periodically recomputed
  final DateTime? expectedCompletionDate;
  final GoalStatus status;
  final DateTime? updatedAt;
  final bool isDeleted;

  SavingGoal({
    required this.id,
    required this.userId,
    this.walletId,
    required this.goalName,
    required this.targetAmount,
    this.savedAmount = 0,
    this.expectedCompletionDate,
    this.status = GoalStatus.inProgress,
    this.updatedAt,
    this.isDeleted = false,
  });

  double get progress =>
      targetAmount <= 0 ? 0 : (savedAmount / targetAmount).clamp(0, 1).toDouble();

  factory SavingGoal.fromMap(Map<String, dynamic> map) => SavingGoal(
        id: map['id'],
        userId: map['user_id'],
        walletId: map['wallet_id'],
        goalName: map['goal_name'],
        targetAmount: map['target_amount'],
        savedAmount: map['saved_amount'] ?? 0,
        expectedCompletionDate: map['expected_completion_date'] != null
            ? DateTime.parse(map['expected_completion_date'])
            : null,
        status: GoalStatusX.fromValue(map['status']),
        updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
        isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'wallet_id': walletId,
        'goal_name': goalName,
        'target_amount': targetAmount,
        'saved_amount': savedAmount,
        'expected_completion_date':
            expectedCompletionDate?.toIso8601String().split('T').first,
        'status': status.value,
        'updated_at': updatedAt?.toIso8601String(),
        'is_deleted': isDeleted ? 1 : 0,
      };

  factory SavingGoal.fromJson(Map<String, dynamic> json) => SavingGoal(
        id: json['id'],
        userId: json['userId'],
        walletId: json['walletId'],
        goalName: json['goalName'],
        targetAmount: json['targetAmount'],
        savedAmount: json['savedAmount'] ?? 0,
        expectedCompletionDate: json['expectedCompletionDate'] != null
            ? DateTime.parse(json['expectedCompletionDate'])
            : null,
        status: GoalStatusX.fromValue(json['status']),
        updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
        isDeleted: json['isDeleted'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'walletId': walletId,
        'goalName': goalName,
        'targetAmount': targetAmount,
        'savedAmount': savedAmount,
        'expectedCompletionDate':
            expectedCompletionDate?.toIso8601String().split('T').first,
        'status': status.value,
        'updatedAt': updatedAt?.toIso8601String(),
        'isDeleted': isDeleted,
      };

  SavingGoal copyWith({
    String? walletId,
    String? goalName,
    int? targetAmount,
    int? savedAmount,
    DateTime? expectedCompletionDate,
    GoalStatus? status,
    bool? isDeleted,
  }) =>
      SavingGoal(
        id: id,
        userId: userId,
        walletId: walletId ?? this.walletId,
        goalName: goalName ?? this.goalName,
        targetAmount: targetAmount ?? this.targetAmount,
        savedAmount: savedAmount ?? this.savedAmount,
        expectedCompletionDate: expectedCompletionDate ?? this.expectedCompletionDate,
        status: status ?? this.status,
        updatedAt: DateTime.now(),
        isDeleted: isDeleted ?? this.isDeleted,
      );
}
