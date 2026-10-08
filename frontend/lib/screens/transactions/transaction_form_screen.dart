import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../models/category.dart';
import '../../models/transaction.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/confirm_delete_dialog.dart';

class TransactionFormScreen extends StatefulWidget {
  final String? transactionId;
  const TransactionFormScreen({super.key, this.transactionId});

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  CategoryType _type = CategoryType.expense;
  String? _walletId;
  String? _categoryId;
  DateTime _date = DateTime.now();
  FinanceTransaction? _editing;

  bool get isEditing => widget.transactionId != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wallets = context.read<WalletProvider>().wallets;
      if (wallets.isNotEmpty) setState(() => _walletId ??= wallets.first.id);

      if (isEditing) {
        final tx = context
            .read<TransactionProvider>()
            .transactions
            .where((t) => t.id == widget.transactionId)
            .firstOrNull;
        if (tx != null) {
          setState(() {
            _editing = tx;
            _amountController.text = tx.amount.toString();
            _noteController.text = tx.note ?? '';
            _type = tx.type;
            _walletId = tx.walletId;
            _categoryId = tx.categoryId;
            _date = tx.transactionDate;
          });
        }
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
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _walletId == null) return;
    final provider = context.read<TransactionProvider>();
    final amount = int.parse(_amountController.text.replaceAll(',', ''));

    if (isEditing && _editing != null) {
      await provider.editTransaction(_editing!.copyWith(
        walletId: _walletId,
        categoryId: _categoryId,
        type: _type,
        amount: amount,
        note: _noteController.text.trim(),
        transactionDate: _date,
      ));
    } else {
      await provider.addTransaction(
        walletId: _walletId!,
        categoryId: _categoryId,
        type: _type,
        amount: amount,
        note: _noteController.text.trim(),
        date: _date,
      );
    }
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    if (_editing == null) return;
    final confirmed = await confirmDelete(context, itemLabel: 'giao dịch này');
    if (confirmed) {
      await context.read<TransactionProvider>().deleteTransaction(_editing!.id, _editing!.walletId);
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallets = context.watch<WalletProvider>().wallets;
    final categories = context.watch<CategoryProvider>();
    final categoryOptions = _type == CategoryType.income ? categories.incomeCategories : categories.expenseCategories;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Sửa giao dịch' : 'Giao dịch mới'),
        actions: [if (isEditing) IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<CategoryType>(
                segments: const [
                  ButtonSegment(value: CategoryType.expense, label: Text('Chi tiêu')),
                  ButtonSegment(value: CategoryType.income, label: Text('Thu nhập')),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() {
                  _type = s.first;
                  _categoryId = null;
                }),
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Số tiền',
                controller: _amountController,
                keyboardType: TextInputType.number,
                validator: Validators.positiveAmount,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: wallets.any((w) => w.id == _walletId) ? _walletId : null,
                decoration: const InputDecoration(labelText: 'Ví'),
                items: wallets.map((w) => DropdownMenuItem(value: w.id, child: Text(w.walletName))).toList(),
                onChanged: (v) => setState(() => _walletId = v),
                validator: (v) => v == null ? 'Vui lòng chọn ví' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: categoryOptions.any((c) => c.id == _categoryId) ? _categoryId : null,
                decoration: const InputDecoration(labelText: 'Danh mục'),
                items: categoryOptions.map((c) => DropdownMenuItem(value: c.id, child: Text(c.categoryName))).toList(),
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Ngày giao dịch',
                controller: TextEditingController(text: Formatters.date(_date)),
                readOnly: true,
                onTap: _pickDate,
                prefixIcon: const Icon(Icons.calendar_today_outlined),
              ),
              const SizedBox(height: 14),
              AppTextField(label: 'Ghi chú (tùy chọn)', controller: _noteController, maxLines: 2),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _submit, child: Text(isEditing ? 'Lưu thay đổi' : 'Thêm giao dịch')),
            ],
          ),
        ),
      ),
    );
  }
}
