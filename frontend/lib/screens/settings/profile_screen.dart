import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_text_field.dart';

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
    _incomeController = TextEditingController(text: user?.monthlyIncome?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _incomeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<AuthProvider>().updateProfile(
          fullName: _nameController.text.trim(),
          monthlyIncome: int.tryParse(_incomeController.text),
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu thay đổi')));
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
              Center(child: CircleAvatar(radius: 40, child: Text(user != null && user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?', style: const TextStyle(fontSize: 28)))),
              const SizedBox(height: 24),
              AppTextField(label: 'Họ và tên', controller: _nameController, validator: (v) => Validators.required(v, field: 'Họ và tên')),
              const SizedBox(height: 14),
              AppTextField(label: 'Email', controller: TextEditingController(text: user?.email ?? ''), readOnly: true),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Thu nhập hàng tháng (tùy chọn)',
                controller: _incomeController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _save, child: const Text('Lưu thay đổi')),
            ],
          ),
        ),
      ),
    );
  }
}
