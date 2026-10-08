import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/utils/validators.dart';
import '../../models/wallet.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/confirm_delete_dialog.dart';
import '../../widgets/icon_color_picker.dart';

const _walletTypes = ['SPENDING', 'SAVINGS', 'CASH', 'BANK', 'E_WALLET'];

class WalletFormScreen extends StatefulWidget {
  final String? walletId;
  const WalletFormScreen({super.key, this.walletId});

  @override
  State<WalletFormScreen> createState() => _WalletFormScreenState();
}

class _WalletFormScreenState extends State<WalletFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController(text: '0');
  String _walletType = _walletTypes.first;
  String? _icon = 'account_balance_wallet';
  String? _color = '#2E7D6B';
  Wallet? _editing;

  bool get isEditing => widget.walletId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final wallet = context.read<WalletProvider>().wallets.firstWhere((w) => w.id == widget.walletId);
        setState(() {
          _editing = wallet;
          _nameController.text = wallet.walletName;
          _balanceController.text = wallet.currentBalance.toString();
          _walletType = wallet.walletType;
          _icon = wallet.icon;
          _color = wallet.color;
        });
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<WalletProvider>();
    if (isEditing && _editing != null) {
      final updated = _editing!.copyWith(
        walletName: _nameController.text.trim(),
        walletType: _walletType,
        icon: _icon,
        color: _color,
      );
      await provider.editWallet(updated);
    } else {
      await provider.addWallet(
        name: _nameController.text.trim(),
        type: _walletType,
        initialBalance: int.tryParse(_balanceController.text) ?? 0,
        icon: _icon,
        color: _color,
      );
    }
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    if (_editing == null) return;
    final confirmed = await confirmDelete(context, itemLabel: _editing!.walletName);
    if (confirmed) {
      await context.read<WalletProvider>().deleteWallet(_editing!.id);
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Sửa ví' : 'Tạo ví mới'),
        actions: [
          if (isEditing) IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
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
                label: 'Tên ví',
                controller: _nameController,
                validator: (v) => Validators.required(v, field: 'Tên ví'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _walletType,
                decoration: const InputDecoration(labelText: 'Loại ví'),
                items: _walletTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _walletType = v!),
              ),
              const SizedBox(height: 14),
              if (!isEditing)
                AppTextField(
                  label: 'Số dư ban đầu',
                  controller: _balanceController,
                  keyboardType: TextInputType.number,
                  validator: Validators.positiveAmount,
                ),
              const SizedBox(height: 20),
              IconColorPicker(
                selectedIcon: _icon,
                selectedColor: _color,
                onIconSelected: (v) => setState(() => _icon = v),
                onColorSelected: (v) => setState(() => _color = v),
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _submit, child: Text(isEditing ? 'Lưu thay đổi' : 'Tạo ví')),
            ],
          ),
        ),
      ),
    );
  }
}
