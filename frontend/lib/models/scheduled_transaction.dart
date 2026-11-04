import '../core/utils/clock.dart';
import '../core/utils/occurrence.dart';
import 'category.dart';

class ScheduledTransaction {
  final String id;
  final String userId;
  final String walletId;
  final String? categoryId;
  final CategoryType type;
  final int amount;
  final String? note;
  final String startDate;
  final String timeOfDay;
  final RepeatUnit? repeatUnit;
  final int? repeatEvery;
  final String? endDate;
  final String? nextDueDate;
  final DateTime updatedAt;
  final bool isDeleted;

  const ScheduledTransaction({
    required this.id,
    required this.userId,
    required this.walletId,
    this.categoryId,
    required this.type,
    required this.amount,
    this.note,
    required this.startDate,
    required this.timeOfDay,
    this.repeatUnit,
    this.repeatEvery,
    this.endDate,
    this.nextDueDate,
    required this.updatedAt,
    this.isDeleted = false,
  });

  RecurrenceRule get rule => RecurrenceRule(
      startDate: startDate,
      unit: repeatUnit,
      every: repeatEvery,
      endDate: endDate);
  bool get isRecurring => repeatUnit != null;
  bool get isFinished => nextDueDate == null;

  factory ScheduledTransaction.fromMap(Map<String, dynamic> m) =>
      ScheduledTransaction(
        id: m['id'],
        userId: m['user_id'],
        walletId: m['wallet_id'],
        categoryId: m['category_id'],
        type: CategoryTypeX.fromValue(m['type']),
        amount: m['amount'],
        note: m['note'],
        startDate: m['start_date'],
        timeOfDay: m['time_of_day'],
        repeatUnit: RepeatUnitX.fromValue(m['repeat_unit']),
        repeatEvery: m['repeat_every'],
        endDate: m['end_date'],
        nextDueDate: m['next_due_date'],
        updatedAt: DateTime.parse(m['updated_at']),
        isDeleted: (m['is_deleted'] as int? ?? 0) == 1,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'wallet_id': walletId,
        'category_id': categoryId,
        'type': type.value,
        'amount': amount,
        'note': note,
        'start_date': startDate,
        'time_of_day': timeOfDay,
        'repeat_unit': repeatUnit?.value,
        'repeat_every': repeatEvery,
        'end_date': endDate,
        'next_due_date': nextDueDate,
        'updated_at': toUtcIso(updatedAt),
        'is_deleted': isDeleted ? 1 : 0,
      };
}
