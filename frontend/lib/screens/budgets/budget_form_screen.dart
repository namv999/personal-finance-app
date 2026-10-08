import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/utils/validators.dart';
import '../../providers/budget_provider.dart';
import '../../providers/category_provider.dart';
import '../../widgets/app_text_field.dart';

class BudgetFormScreen extends StatefulWidget {
  const BudgetFormScreen({super.key});
  @override
  State<BudgetFormScreen> createState() => _BudgetFormScreenState();
}

class _BudgetFormScreenState extends State<BudgetFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _limitController = TextEditingController();
  String? _categoryId;

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _categoryId == null) return;
    await context.read<BudgetProvider>().setBudget(
          categoryId: _categoryId!,
          limit: int.parse(_limitController.text.replaceAll(',', '')),
        );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final expenseCategories = context.watch<CategoryProvider>().expenseCategories;
    return Scaffold(
      appBar: AppBar(title: const Text('Đặt ngân sách')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                value: _categoryId,
                decoration: const InputDecoration(labelText: 'Danh mục chi tiêu'),
                items: expenseCategories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.categoryName))).toList(),
                onChanged: (v) => setState(() => _categoryId = v),
                validator: (v) => v == null ? 'Chọn danh mục' : null,
              ),
              const SizedBox(height: 14),
              AppTextField(label: 'Hạn mức chi tiêu / tháng', controller: _limitController, keyboardType: TextInputType.number, validator: Validators.positiveAmount),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _submit, child: const Text('Lưu ngân sách')),
            ],
          ),
        ),
      ),
    );
  }
}
