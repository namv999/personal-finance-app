import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/budget_status.dart';
import '../core/utils/formatters.dart';

class BudgetStatusBar extends StatelessWidget {
  final BudgetStatus status;
  final bool showLabel;

  const BudgetStatusBar({
    super.key,
    required this.status,
    this.showLabel = true,
  });

  Color _colorForLevel(BudgetLevel level) {
    switch (level) {
      case BudgetLevel.safe:
        return AppColors.success;
      case BudgetLevel.warning:
        return AppColors.warning;
      case BudgetLevel.exceeded:
        return AppColors.danger;
    }
  }

  Widget _buildStatusMessage() {
    switch (status.level) {
      case BudgetLevel.safe:
        return Text(
          'Còn ${Formatters.currency(status.remaining)}',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
          overflow: TextOverflow.ellipsis,
        );
      case BudgetLevel.warning:
        return Text(
          'Sắp hết, còn ${Formatters.currency(status.remaining)}',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
          overflow: TextOverflow.ellipsis,
        );
      case BudgetLevel.exceeded:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 14,
              color: AppColors.danger,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'Vượt ${Formatters.currency(-status.remaining)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.danger,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetColor = _colorForLevel(status.level);
    final int percent =
        status.ratio.isFinite ? (status.ratio * 100).round() : 100;

    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: targetColor),
      duration: const Duration(milliseconds: 250),
      builder: (context, color, _) {
        final currentColor = color ?? targetColor;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: status.barFill,
                minHeight: 10,
                backgroundColor: currentColor.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(currentColor),
              ),
            ),
            if (showLabel) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: _buildStatusMessage()),
                  const SizedBox(width: 8),
                  Text(
                    '$percent%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: status.level == BudgetLevel.exceeded
                          ? AppColors.danger
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
