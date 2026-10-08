import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

Future<bool> confirmDelete(BuildContext context, {required String itemLabel}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Xác nhận xóa'),
      content: Text('Bạn có chắc muốn xóa "$itemLabel"? Hành động này không thể hoàn tác.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Xóa', style: TextStyle(color: AppColors.danger)),
        ),
      ],
    ),
  );
  return result ?? false;
}
