import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/ledger_refresh.dart';
import '../../models/category.dart';
import '../../providers/category_provider.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/confirm_delete_dialog.dart';
import '../../widgets/icon_color_picker.dart';

class CategoryFormScreen extends StatefulWidget {
  final String? categoryId;
  const CategoryFormScreen({super.key, this.categoryId});

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  CategoryType _type = CategoryType.expense;
  String? _icon = 'category';
  String? _color = '#2E7D6B';
  TransactionCategory? _editing;
  bool _saving = false;

  bool get isEditing => widget.categoryId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final category =
            context.read<CategoryProvider>().byId(widget.categoryId);
        if (category == null) return;
        setState(() {
          _editing = category;
          _nameController.text = category.categoryName;
          _type = category.type;
          _icon = category.icon;
          _color = category.color;
        });
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error.toString().replaceFirst('Exception: ', ''))));
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final provider = context.read<CategoryProvider>();
    setState(() => _saving = true);
    try {
      if (isEditing && _editing != null) {
        await provider.editCategory(_editing!.copyWith(
            categoryName: _nameController.text.trim(),
            type: _type,
            icon: _icon,
            color: _color));
      } else {
        await provider.addCategory(_nameController.text.trim(), _type,
            icon: _icon, color: _color);
      }
      if (mounted) context.pop();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (_editing == null) return;
    final confirmed =
        await confirmDelete(context, itemLabel: _editing!.categoryName);
    if (!confirmed || !mounted) return;
    final refresh = LedgerRefresh.of(context);
    setState(() => _saving = true);
    try {
      await context.read<CategoryProvider>().deleteCategory(_editing!.id);
      await refresh.run();
      if (mounted) context.pop();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Sửa danh mục' : 'Danh mục mới'),
        actions: [
          if (isEditing)
            IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: _saving ? null : _delete),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'Tên danh mục',
                controller: _nameController,
                validator: (v) => Validators.required(v, field: 'Tên danh mục'),
              ),
              const SizedBox(height: 14),
              SegmentedButton<CategoryType>(
                segments: const [
                  ButtonSegment(
                      value: CategoryType.expense, label: Text('Chi tiêu')),
                  ButtonSegment(
                      value: CategoryType.income, label: Text('Thu nhập')),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 20),
              IconColorPicker(
                selectedIcon: _icon,
                selectedColor: _color,
                onIconSelected: (v) => setState(() => _icon = v),
                onColorSelected: (v) => setState(() => _color = v),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  child: Text(isEditing ? 'Lưu thay đổi' : 'Tạo danh mục')),
            ],
          ),
        ),
      ),
    );
  }
}
