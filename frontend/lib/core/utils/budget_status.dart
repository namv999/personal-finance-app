enum BudgetLevel { safe, warning, exceeded }

class BudgetStatus {
  final BudgetLevel level;
  final double ratio;
  final double barFill;
  final int remaining;

  const BudgetStatus({
    required this.level,
    required this.ratio,
    required this.barFill,
    required this.remaining,
  });
}

BudgetStatus budgetStatusOf(int spent, int limit) {
  if (limit <= 0) {
    return BudgetStatus(
      level: spent > 0 ? BudgetLevel.exceeded : BudgetLevel.safe,
      ratio: spent > 0 ? double.infinity : 0,
      barFill: spent > 0 ? 1 : 0,
      remaining: -spent,
    );
  }
  final ratio = spent / limit;
  return BudgetStatus(
    level: spent > limit
        ? BudgetLevel.exceeded
        : ratio >= 0.75
            ? BudgetLevel.warning
            : BudgetLevel.safe,
    ratio: ratio,
    barFill: ratio.clamp(0, 1).toDouble(),
    remaining: limit - spent,
  );
}
