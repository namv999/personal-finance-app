import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_app/core/utils/id_generator.dart';
import 'package:personal_finance_app/core/utils/occurrence.dart';

void main() {
  test('month end is clamped without drifting', () {
    const r = RecurrenceRule(
        startDate: '2026-01-31', unit: RepeatUnit.month, every: 1);
    expect(r.dateAt(1), '2026-02-28');
    expect(r.dateAt(2), '2026-03-31');
    expect(r.dateAt(13), '2027-02-28');
    expect(r.nextAfter('2026-01-31'), '2026-02-28');
    expect(r.nextAfter('2026-02-28'), '2026-03-31');
  });

  test('leap day yearly recurrence', () {
    const r = RecurrenceRule(
        startDate: '2024-02-29', unit: RepeatUnit.year, every: 1);
    expect(r.dateAt(1), '2025-02-28');
    expect(r.dateAt(4), '2028-02-29');
    expect(r.nextAfter('2025-02-28'), '2026-02-28');
  });

  test('biweekly and every three days', () {
    const w = RecurrenceRule(
        startDate: '2026-11-03', unit: RepeatUnit.week, every: 2);
    expect(w.nextAfter('2026-11-03'), '2026-11-17');
    const d =
        RecurrenceRule(startDate: '2026-11-01', unit: RepeatUnit.day, every: 3);
    expect(d.nextAfter('2026-11-10'), '2026-11-13');
    expect(d.nextAfter('2026-11-01'), '2026-11-04');
  });

  test('end date and one-time occurrence', () {
    const r = RecurrenceRule(
        startDate: '2026-11-03',
        unit: RepeatUnit.week,
        every: 1,
        endDate: '2026-11-10');
    expect(r.nextAfter('2026-11-03'), '2026-11-10');
    expect(r.nextAfter('2026-11-10'), isNull);
    const once = RecurrenceRule(startDate: '2026-11-03');
    expect(once.nextAfter('2026-11-03'), isNull);
  });

  test('occurrence UUID v5 is deterministic', () {
    final a = IdGenerator.forOccurrence('abc', '2026-11-03');
    expect(IdGenerator.forOccurrence('abc', '2026-11-03'), a);
    expect(IdGenerator.forOccurrence('abc', '2026-11-04'), isNot(a));
    expect(a, a.toLowerCase());
    expect(a.length, 36);
  });
}
