import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../providers/saving_goal_provider.dart';
import '../../providers/transfer_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/app_text_field.dart';

class TransferFormScreen extends StatefulWidget {
  const TransferFormScreen({super.key});
  @override
  State<TransferFormScreen> createState() => _TransferFormScreenState();
}

class _TransferFormScreenState extends State<TransferFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _sourceId;
  String? _destinationId;
  String? _goalId;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wallets = context.read<WalletProvider>().wallets;
      if (wallets.length >= 2) {
        setState(() {
          _sourceId = wallets.first.id;
          _destinationId = wallets[1].id;
        });
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_sourceId == null || _destinationId == null) return;
    try {
      await context.read<TransferProvider>().addTransfer(
            sourceWalletId: _sourceId!,
            destinationWalletId: _destinationId!,
            goalId: _goalId,
            amount: int.parse(_amountController.text.replaceAll(',', '')),
            date: _date,
            note: _noteController.text.trim(),
          );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallets = context.watch<WalletProvider>().wallets;
    final goals = context.watch<SavingGoalProvider>().goals;

    return Scaffold(
      appBar: AppBar(title: const Text('Chuyển khoản')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                value: wallets.any((w) => w.id == _sourceId) ? _sourceId : null,
                decoration: const InputDecoration(labelText: 'Từ ví'),
                items: wallets.map((w) => DropdownMenuItem(value: w.id, child: Text(w.walletName))).toList(),
                onChanged: (v) => setState(() => _sourceId = v),
                validator: (v) => v == null ? 'Chọn ví nguồn' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: wallets.any((w) => w.id == _destinationId) ? _destinationId : null,
                decoration: const InputDecoration(labelText: 'Đến ví'),
                items: wallets.map((w) => DropdownMenuItem(value: w.id, child: Text(w.walletName))).toList(),
                onChanged: (v) => setState(() => _destinationId = v),
                validator: (v) => v == null ? 'Chọn ví đích' : null,
              ),
              const SizedBox(height: 14),
              AppTextField(label: 'Số tiền', controller: _amountController, keyboardType: TextInputType.number, validator: Validators.positiveAmount),
              const SizedBox(height: 14),
              if (goals.isNotEmpty)
                DropdownButtonFormField<String?>(
                  value: _goalId,
                  decoration: const InputDecoration(labelText: 'Liên kết mục tiêu tiết kiệm (tùy chọn)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Không liên kết')),
                    ...goals.map((g) => DropdownMenuItem(value: g.id, child: Text(g.goalName))),
                  ],
                  onChanged: (v) => setState(() => _goalId = v),
                ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Ngày chuyển',
                controller: TextEditingController(text: Formatters.date(_date)),
                readOnly: true,
                onTap: _pickDate,
                prefixIcon: const Icon(Icons.calendar_today_outlined),
              ),
              const SizedBox(height: 14),
              AppTextField(label: 'Ghi chú (tùy chọn)', controller: _noteController, maxLines: 2),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _submit, child: const Text('Chuyển khoản')),
            ],
          ),
        ),
      ),
    );
  }
}
