import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../providers/saving_goal_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/app_text_field.dart';

class SavingGoalFormScreen extends StatefulWidget {
  const SavingGoalFormScreen({super.key});
  @override
  State<SavingGoalFormScreen> createState() => _SavingGoalFormScreenState();
}

class _SavingGoalFormScreenState extends State<SavingGoalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  String? _walletId;
  DateTime? _expectedDate;

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
        context: context, initialDate: DateTime.now().add(const Duration(days: 30)), firstDate: DateTime.now(), lastDate: DateTime(2100));
    if (picked != null) setState(() => _expectedDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<SavingGoalProvider>().addGoal(
          walletId: _walletId,
          name: _nameController.text.trim(),
          targetAmount: int.parse(_targetController.text.replaceAll(',', '')),
          expectedDate: _expectedDate,
        );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final wallets = context.watch<WalletProvider>().wallets;
    return Scaffold(
      appBar: AppBar(title: const Text('Mục tiêu tiết kiệm mới')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(label: 'Tên mục tiêu', controller: _nameController, validator: (v) => Validators.required(v, field: 'Tên mục tiêu')),
              const SizedBox(height: 14),
              AppTextField(label: 'Số tiền mục tiêu', controller: _targetController, keyboardType: TextInputType.number, validator: Validators.positiveAmount),
              const SizedBox(height: 14),
              if (wallets.isNotEmpty)
                DropdownButtonFormField<String?>(
                  value: _walletId,
                  decoration: const InputDecoration(labelText: 'Ví tiết kiệm liên kết (tùy chọn)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Không liên kết')),
                    ...wallets.map((w) => DropdownMenuItem(value: w.id, child: Text(w.walletName))),
                  ],
                  onChanged: (v) => setState(() => _walletId = v),
                ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Ngày dự kiến hoàn thành (tùy chọn)',
                controller: TextEditingController(text: _expectedDate != null ? Formatters.date(_expectedDate!) : ''),
                readOnly: true,
                onTap: _pickDate,
                prefixIcon: const Icon(Icons.event_outlined),
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _submit, child: const Text('Tạo mục tiêu')),
            ],
          ),
        ),
      ),
    );
  }
}
