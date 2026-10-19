import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/utils/clock.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ledger_refresh.dart';
import '../../core/utils/validators.dart';
import '../../models/saving_goal.dart';
import '../../providers/saving_goal_provider.dart';
import '../../providers/transfer_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/app_text_field.dart';

class TransferFormScreen extends StatefulWidget {
  final String? goalId;
  const TransferFormScreen({super.key, this.goalId});
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
  bool _goalTouched = false;
  bool _defaultsInit = false;
  bool _saving = false;
  DateTime _date = DateTime.parse(businessToday());

  @override
  void initState() {
    super.initState();
    _goalId = widget.goalId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _initDefaults());
  }

  void _initDefaults() {
    if (!mounted || _defaultsInit) return;
    final wallets = context.read<WalletProvider>().wallets;
    if (wallets.length < 2) return;
    _defaultsInit = true;
    final goals = context.read<SavingGoalProvider>().goals;
    final requestedGoal = goals.where((g) => g.id == widget.goalId).firstOrNull;
    final goalWalletId = requestedGoal?.walletId;
    final linkedDestination = goalWalletId == null
        ? null
        : wallets.where((w) => w.id == goalWalletId).firstOrNull;
    final source = linkedDestination == null
        ? wallets[0]
        : wallets.firstWhere((w) => w.id != linkedDestination.id);
    final destination = linkedDestination ?? wallets[1];
    setState(() {
      _goalId = requestedGoal?.id;
      _goalTouched = requestedGoal != null;
      _sourceId = source.id;
      _destinationId = destination.id;
      _autoPickGoal(sourceId: _sourceId, destId: _destinationId);
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _autoPickGoal({String? sourceId, String? destId}) {
    final sId = sourceId ?? _sourceId;
    final dId = destId ?? _destinationId;
    final goals = context.read<SavingGoalProvider>().goals;

    final compatible = goals
        .where(
            (g) => g.walletId == null || g.walletId == sId || g.walletId == dId)
        .toList();

    if (_goalId != null && !compatible.any((g) => g.id == _goalId)) {
      _goalId = null;
      _goalTouched = false;
    }
    if (_goalTouched) return;

    final deposits =
        goals.where((g) => g.walletId != null && g.walletId == dId).toList();
    _goalId = deposits.length == 1 ? deposits.first.id : null;
  }

  Future<void> _pickDate() async {
    final today = DateTime.parse(businessToday());
    final initial = _date.isAfter(today) ? today : _date;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: today,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_sourceId == null || _destinationId == null) return;
    if (_sourceId == _destinationId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Ví nguồn và ví đích không được trùng nhau')),
      );
      return;
    }

    setState(() => _saving = true);
    final transferProvider = context.read<TransferProvider>();
    final refresh = LedgerRefresh.of(context);
    try {
      await transferProvider.addTransfer(
        sourceWalletId: _sourceId!,
        destinationWalletId: _destinationId!,
        goalId: _goalId,
        amount: int.parse(_amountController.text.replaceAll(',', '')),
        date: _date,
        note: _noteController.text.trim(),
      );
      await refresh.run();
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallets = context.watch<WalletProvider>().wallets;
    final allGoals = context.watch<SavingGoalProvider>().goals;

    if (wallets.length < 2) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chuyển khoản')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.swap_horiz_rounded,
                    size: 64, color: AppColors.textSecondary),
                const SizedBox(height: 16),
                const Text(
                  'Cần ít nhất 2 ví để chuyển khoản',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  wallets.isEmpty
                      ? 'Bạn chưa có ví nào. Hãy tạo ví để chuyển tiền giữa các ví.'
                      : 'Hiện bạn mới có 1 ví. Hãy tạo thêm một chiếc ví khác để thực hiện chuyển tiền giữa các ví.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => context.push(AppRoutes.walletAdd),
                  icon: const Icon(Icons.add),
                  label: const Text('Tạo thêm ví mới'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_defaultsInit) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _initDefaults());
    }

    final compatibleGoals = allGoals
        .where((g) =>
            g.walletId == null ||
            g.walletId == _sourceId ||
            g.walletId == _destinationId)
        .toList();

    SavingGoal? selectedGoal;
    if (_goalId != null) {
      selectedGoal = compatibleGoals.where((g) => g.id == _goalId).firstOrNull;
    }

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
                initialValue:
                    wallets.any((w) => w.id == _sourceId) ? _sourceId : null,
                decoration: const InputDecoration(labelText: 'Từ ví'),
                items: wallets
                    .map((w) => DropdownMenuItem(
                        value: w.id, child: Text(w.walletName)))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _sourceId = v;
                    _autoPickGoal(sourceId: v);
                  });
                },
                validator: (v) => v == null ? 'Chọn ví nguồn' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: wallets.any((w) => w.id == _destinationId)
                    ? _destinationId
                    : null,
                decoration: const InputDecoration(labelText: 'Đến ví'),
                items: wallets
                    .map((w) => DropdownMenuItem(
                        value: w.id, child: Text(w.walletName)))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _destinationId = v;
                    _autoPickGoal(destId: v);
                  });
                },
                validator: (v) => v == null ? 'Chọn ví đích' : null,
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Số tiền',
                controller: _amountController,
                keyboardType: TextInputType.number,
                validator: Validators.positiveAmount,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String?>(
                initialValue: compatibleGoals.any((g) => g.id == _goalId)
                    ? _goalId
                    : null,
                decoration: const InputDecoration(
                    labelText: 'Liên kết mục tiêu tiết kiệm (tùy chọn)'),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Không liên kết')),
                  ...compatibleGoals.map((g) {
                    String tag = '';
                    if (g.walletId != null) {
                      if (g.walletId == _destinationId) {
                        tag = ' · Nạp vào mục tiêu';
                      } else if (g.walletId == _sourceId) {
                        tag = ' · Rút khỏi mục tiêu';
                      }
                    }
                    return DropdownMenuItem(
                      value: g.id,
                      child: Text(
                        '${g.goalName}$tag',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                ],
                onChanged: (v) => setState(() {
                  _goalId = v;
                  _goalTouched = true;
                }),
              ),
              if (selectedGoal != null && selectedGoal.walletId != null) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      if (selectedGoal.walletId == _destinationId) ...[
                        const Icon(Icons.arrow_downward_rounded,
                            size: 16, color: AppColors.income),
                        const SizedBox(width: 4),
                        const Text(
                          'Nạp vào mục tiêu',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.income,
                          ),
                        ),
                      ] else if (selectedGoal.walletId == _sourceId) ...[
                        const Icon(Icons.arrow_upward_rounded,
                            size: 16, color: AppColors.danger),
                        const SizedBox(width: 4),
                        const Text(
                          'Rút khỏi mục tiêu',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: 14, color: AppColors.textSecondary),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Chuyển tiền không gắn mục tiêu không tính vào tiến độ và chuỗi tiết kiệm',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
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
              AppTextField(
                label: 'Ghi chú (tùy chọn)',
                controller: _noteController,
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: const Text('Chuyển khoản'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
