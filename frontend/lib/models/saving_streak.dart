class SavingStreak {
  final String id;
  final String userId;
  final int currentStreakDays;
  final int longestStreak;
  final DateTime? lastSavedDate;
  final DateTime? updatedAt;

  SavingStreak({
    required this.id,
    required this.userId,
    this.currentStreakDays = 0,
    this.longestStreak = 0,
    this.lastSavedDate,
    this.updatedAt,
  });

  factory SavingStreak.fromMap(Map<String, dynamic> map) => SavingStreak(
        id: map['id'],
        userId: map['user_id'],
        currentStreakDays: map['current_streak_days'] ?? 0,
        longestStreak: map['longest_streak'] ?? 0,
        lastSavedDate:
            map['last_saved_date'] != null ? DateTime.parse(map['last_saved_date']) : null,
        updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'current_streak_days': currentStreakDays,
        'longest_streak': longestStreak,
        'last_saved_date': lastSavedDate?.toIso8601String().split('T').first,
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory SavingStreak.fromJson(Map<String, dynamic> json) => SavingStreak(
        id: json['id'],
        userId: json['userId'],
        currentStreakDays: json['currentStreakDays'] ?? 0,
        longestStreak: json['longestStreak'] ?? 0,
        lastSavedDate:
            json['lastSavedDate'] != null ? DateTime.parse(json['lastSavedDate']) : null,
        updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'currentStreakDays': currentStreakDays,
        'longestStreak': longestStreak,
        'lastSavedDate': lastSavedDate?.toIso8601String().split('T').first,
        'updatedAt': updatedAt?.toIso8601String(),
      };
}
