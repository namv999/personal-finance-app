import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/user_avatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _incomeController;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _nameController = TextEditingController(text: user?.fullName ?? '');
    _incomeController =
        TextEditingController(text: user?.monthlyIncome?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _incomeController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar(ImageSource source) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (picked == null || !mounted) return;

      final docsDir = await getApplicationDocumentsDirectory();
      final avatarsDir = Directory('${docsDir.path}/avatars');
      if (!await avatarsDir.exists()) {
        await avatarsDir.create(recursive: true);
      }

      final targetPath = '${avatarsDir.path}/${user.id}.jpg';
      final targetFile = File(targetPath);
      await File(picked.path).copy(targetPath);

      await FileImage(targetFile).evict();

      if (mounted) {
        await context.read<AuthProvider>().updateAvatar(targetPath);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể cập nhật ảnh đại diện')),
        );
      }
    }
  }

  Future<void> _deleteAvatar() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null || user.avatarPath == null) return;

    final file = File(user.avatarPath!);
    if (await file.exists()) {
      await file.delete();
      await FileImage(file).evict();
    }

    if (mounted) {
      await context.read<AuthProvider>().updateAvatar(null);
    }
  }

  void _showAvatarOptions() {
    final user = context.read<AuthProvider>().currentUser;
    final hasAvatar = user?.avatarPath != null &&
        File(user!.avatarPath!).existsSync();

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Chụp ảnh'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAvatar(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn từ thư viện'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAvatar(ImageSource.gallery);
              },
            ),
            if (hasAvatar)
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: AppColors.danger),
                title: const Text('Xóa ảnh',
                    style: TextStyle(color: AppColors.danger)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _deleteAvatar();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<AuthProvider>().updateProfile(
          fullName: _nameController.text.trim(),
          monthlyIncome: int.tryParse(_incomeController.text),
        );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã lưu thay đổi')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ cá nhân')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Center(
                child: GestureDetector(
                  onTap: _showAvatarOptions,
                  child: Stack(
                    children: [
                      UserAvatar(user: user, radius: 44),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              AppTextField(
                  label: 'Họ và tên',
                  controller: _nameController,
                  validator: (v) => Validators.required(v, field: 'Họ và tên')),
              const SizedBox(height: 14),
              AppTextField(
                  label: 'Email',
                  controller: TextEditingController(text: user?.email ?? ''),
                  readOnly: true),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Thu nhập hàng tháng (tùy chọn)',
                controller: _incomeController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                  onPressed: _save, child: const Text('Lưu thay đổi')),
            ],
          ),
        ),
      ),
    );
  }
}
