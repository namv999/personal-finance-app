import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/utils/ledger_refresh.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/utils/validators.dart';
import '../../models/wallet.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/wallet_delete_dialog.dart';
import '../../widgets/icon_color_picker.dart';

const _walletTypes = ['SPENDING', 'SAVINGS', 'CASH', 'BANK', 'E_WALLET'];

class WalletFormScreen extends StatefulWidget {
  final String? walletId;
  final bool isRequired;
  const WalletFormScreen({super.key, this.walletId, this.isRequired = false});

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
  bool _saving = false;

  bool get isEditing => widget.walletId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final wallet = context
            .read<WalletProvider>()
            .wallets
            .where((w) => w.id == widget.walletId)
            .firstOrNull;
        if (wallet != null) {
          setState(() {
            _editing = wallet;
            _nameController.text = wallet.walletName;
            _balanceController.text = wallet.currentBalance.toString();
            _walletType = wallet.walletType;
            _icon = wallet.icon;
            _color = wallet.color;
          });
        }
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
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final provider = context.read<WalletProvider>();
    try {
      if (isEditing && _editing != null) {
        final refresh = LedgerRefresh.of(context);
        final updated = _editing!.copyWith(
          walletName: _nameController.text.trim(),
          walletType: _walletType,
          icon: _icon,
          color: _color,
        );
        await provider.editWallet(updated);
        await refresh.run();
      } else {
        await provider.addWallet(
          name: _nameController.text.trim(),
          type: _walletType,
          initialBalance:
              int.parse(_balanceController.text.replaceAll(',', '')),
          icon: _icon,
          color: _color,
        );
      }
      if (mounted) {
        if (widget.isRequired) {
          context.go(AppRoutes.home);
        } else {
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (_editing == null) return;
    await confirmAndDeleteWallet(
      context,
      walletId: _editing!.id,
      walletName: _editing!.walletName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isRequired
        ? 'Tạo ví đầu tiên'
        : (isEditing ? 'Sửa ví' : 'Tạo ví mới');

    final content = Scaffold(
      appBar: AppBar(
        title: Text(title),
        automaticallyImplyLeading: !widget.isRequired,
        actions: [
          if (isEditing && !widget.isRequired)
            IconButton(
                icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.isRequired) ...[
                Card(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.primary),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Bạn chưa có ví nào. Hãy tạo chiếc ví đầu tiên để bắt đầu theo dõi thu chi và quản lý tài chính nhé!',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              AppTextField(
                label: 'Tên ví',
                controller: _nameController,
                validator: (v) => Validators.required(v, field: 'Tên ví'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _walletType,
                decoration: const InputDecoration(labelText: 'Loại ví'),
                items: _walletTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
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
              ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  child: Text(widget.isRequired
                      ? 'Tạo ví & Bắt đầu'
                      : (isEditing ? 'Lưu thay đổi' : 'Tạo ví'))),
            ],
          ),
        ),
      ),
    );

    if (widget.isRequired) {
      return PopScope(canPop: false, child: content);
    }
    return content;
  }
}
