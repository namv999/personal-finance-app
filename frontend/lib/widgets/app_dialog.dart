import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// Reusable two-button row for dialogs following the UI/UX guideline:
/// - 2 buttons: in a Row, two equal Expanded, 12px apart.
/// - Left: OutlinedButton (cancel/safe action).
/// - Right: FilledButton (primary/confirm action).
/// - Equal height (48).
class AppDialogTwoButtons extends StatelessWidget {
  final String cancelLabel;
  final VoidCallback? onCancel;
  final String confirmLabel;
  final VoidCallback? onConfirm;
  final bool danger;
  final Widget? confirmChild;

  const AppDialogTwoButtons({
    super.key,
    required this.cancelLabel,
    this.onCancel,
    required this.confirmLabel,
    this.onConfirm,
    this.danger = false,
    this.confirmChild,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: onCancel,
              child: Text(cancelLabel),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 48,
            child: FilledButton(
              style: danger
                  ? FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.divider,
                      disabledForegroundColor: AppColors.textSecondary,
                    )
                  : null,
              onPressed: onConfirm,
              child: confirmChild ?? Text(confirmLabel),
            ),
          ),
        ),
      ],
    );
  }
}

/// Standard confirmation dialog.
Future<bool?> showAppConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String cancelLabel,   // tối đa 12 ký tự
  required String confirmLabel,  // tối đa 12 ký tự
  bool danger = false,           // true: nút phải màu AppColors.danger
}) {
  assert(cancelLabel.length <= 12, 'cancelLabel must be <= 12 characters');
  assert(confirmLabel.length <= 12, 'confirmLabel must be <= 12 characters');

  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        AppDialogTwoButtons(
          cancelLabel: cancelLabel,
          onCancel: () => Navigator.of(ctx).pop(false),
          confirmLabel: confirmLabel,
          onConfirm: () => Navigator.of(ctx).pop(true),
          danger: danger,
        ),
      ],
    ),
  );
}
