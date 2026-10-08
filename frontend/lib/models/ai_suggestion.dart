class AiSuggestion {
  final String id;
  final String userId;
  final String month; // format YYYY-MM
  final String suggestionContent;
  final DateTime createdAt;

  AiSuggestion({
    required this.id,
    required this.userId,
    required this.month,
    required this.suggestionContent,
    required this.createdAt,
  });

  factory AiSuggestion.fromMap(Map<String, dynamic> map) => AiSuggestion(
        id: map['id'],
        userId: map['user_id'],
        month: map['month'],
        suggestionContent: map['suggestion_content'],
        createdAt: DateTime.parse(map['created_at']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'month': month,
        'suggestion_content': suggestionContent,
        'created_at': createdAt.toIso8601String(),
      };

  factory AiSuggestion.fromJson(Map<String, dynamic> json) => AiSuggestion(
        id: json['id'],
        userId: json['userId'],
        month: json['month'],
        suggestionContent: json['suggestionContent'],
        createdAt: DateTime.parse(json['createdAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'month': month,
        'suggestionContent': suggestionContent,
        'createdAt': createdAt.toIso8601String(),
      };
}
