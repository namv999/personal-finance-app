import 'package:flutter/material.dart';
import 'app_dialog.dart';

Future<bool> confirmDelete(BuildContext context, {required String itemLabel}) async {
  final result = await showAppConfirm(
    context,
    title: 'Xác nhận xóa',
    message: 'Bạn có chắc muốn xóa "$itemLabel"? Hành động này không thể hoàn tác.',
    cancelLabel: 'Hủy',
    confirmLabel: 'Xóa',
    danger: true,
  );
  return result ?? false;
}
