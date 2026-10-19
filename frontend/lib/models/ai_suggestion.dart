import '../core/utils/clock.dart';

enum AiPeriodType { week, month }

extension AiPeriodTypeX on AiPeriodType {
  String get value => this == AiPeriodType.week ? 'WEEK' : 'MONTH';

  static AiPeriodType fromValue(String value) =>
      value == 'WEEK' ? AiPeriodType.week : AiPeriodType.month;
}

/// A suggestion period. Weeks start on Monday in the business timezone.
class AiPeriod {
  final AiPeriodType type;
  final DateTime start;
  final DateTime end;
  const AiPeriod(this.type, this.start, this.end);

  factory AiPeriod.of(AiPeriodType type, [DateTime? date]) {
    final day = date ?? DateTime.parse(businessToday());
    final normalized = DateTime(day.year, day.month, day.day);
    if (type == AiPeriodType.week) {
      final start = normalized.subtract(Duration(days: normalized.weekday - 1));
      return AiPeriod(type, start, start.add(const Duration(days: 6)));
    }
    return AiPeriod(type, DateTime(normalized.year, normalized.month, 1),
        DateTime(normalized.year, normalized.month + 1, 0));
  }
}

class AiSuggestion {
  final String id;
  final String userId;
  final AiPeriodType periodType;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String suggestionContent;
  final String? suggestedData;
  final DateTime createdAt;

  AiSuggestion({
    required this.id,
    required this.userId,
    required this.periodType,
    required this.periodStart,
    required this.periodEnd,
    required this.suggestionContent,
    this.suggestedData,
    required this.createdAt,
  });

  factory AiSuggestion.fromMap(Map<String, dynamic> map) => AiSuggestion(
        id: map['id'],
        userId: map['user_id'],
        periodType: AiPeriodTypeX.fromValue(map['period_type']),
        periodStart: DateTime.parse(map['period_start']),
        periodEnd: DateTime.parse(map['period_end']),
        suggestionContent: map['suggestion_content'],
        suggestedData: map['suggested_data'],
        createdAt: DateTime.parse(map['created_at']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'period_type': periodType.value,
        'period_start': dateOnly(periodStart),
        'period_end': dateOnly(periodEnd),
        'suggestion_content': suggestionContent,
        'suggested_data': suggestedData,
        'created_at': toUtcIso(createdAt),
      };

  factory AiSuggestion.fromJson(Map<String, dynamic> json) => AiSuggestion(
        id: json['id'],
        userId: json['userId'],
        periodType: AiPeriodTypeX.fromValue(json['periodType']),
        periodStart: DateTime.parse(json['periodStart']),
        periodEnd: DateTime.parse(json['periodEnd']),
        suggestionContent: json['suggestionContent'],
        suggestedData: json['suggestedData'],
        createdAt: DateTime.parse(json['createdAt']),
      );
}
