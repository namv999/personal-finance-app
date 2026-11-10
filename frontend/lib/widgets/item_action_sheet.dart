import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class ItemAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const ItemAction(this.icon, this.label, this.onTap, {this.danger = false});
}

Future<void> showItemActionSheet(
  BuildContext context, {
  required String title,
  required List<ItemAction> actions,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(height: 1),
            for (final action in actions)
              ListTile(
                leading: Icon(
                  action.icon,
                  color: action.danger ? AppColors.danger : null,
                ),
                title: Text(
                  action.label,
                  style: TextStyle(
                    color: action.danger ? AppColors.danger : null,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  action.onTap();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
