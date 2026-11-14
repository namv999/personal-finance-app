import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/clock.dart';
import '../../core/utils/formatters.dart';
import '../../models/category.dart';
import '../../models/transaction_filter.dart';
import '../../models/wallet.dart';

Future<TransactionFilter?> showTransactionFilterSheet(
  BuildContext context, {
  required TransactionFilter initial,
  required List<Wallet> wallets,
  required List<TransactionCategory> categories,
}) {
  return showModalBottomSheet<TransactionFilter>(
    context: context,
    isScrollControlled: true, // để sheet đẩy lên theo bàn phím
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _FilterSheet(
      initial: initial,
      wallets: wallets,
      categories: categories,
    ),
  );
}

class _FilterSheet extends StatefulWidget {
  final TransactionFilter initial;
  final List<Wallet> wallets;
  final List<TransactionCategory> categories;

  const _FilterSheet({
    required this.initial,
    required this.wallets,
    required this.categories,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late TransactionFilter _draft;
  late TextEditingController _queryController;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
    _queryController = TextEditingController(text: _draft.query);
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _onTypeChanged(CategoryType? newType) {
    if (newType == null) {
      setState(() {
        _draft = _draft.copyWith(clearType: true);
      });
      return;
    }

    final currentCat = widget.categories
        .where((c) => c.id == _draft.categoryId)
        .firstOrNull;
    final needClear = currentCat != null && currentCat.type != newType;

    setState(() {
      _draft = _draft.copyWith(
        type: newType,
        clearCategory: needClear,
      );
    });
  }

  Future<void> _pickDateRange() async {
    final today = DateTime.parse(businessToday());
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: today,
      initialDateRange: (_draft.from != null && _draft.to != null)
          ? DateTimeRange(start: _draft.from!, end: _draft.to!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _draft = _draft.copyWith(from: picked.start, to: picked.end);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableCategories = _draft.type == null
        ? widget.categories.where((c) => !c.isDeleted).toList()
        : widget.categories
            .where((c) => !c.isDeleted && c.type == _draft.type)
            .toList();

    String dateSubtitle = 'Tất cả thời gian';
    if (_draft.from != null && _draft.to != null) {
      dateSubtitle =
          '${Formatters.date(_draft.from!)} - ${Formatters.date(_draft.to!)}';
    } else if (_draft.from != null) {
      dateSubtitle = 'Từ ${Formatters.date(_draft.from!)}';
    } else if (_draft.to != null) {
      dateSubtitle = 'Đến ${Formatters.date(_draft.to!)}';
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Hàng tiêu đề
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tìm kiếm và lọc',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _draft = const TransactionFilter();
                      _queryController.clear();
                    });
                  },
                  child: const Text('Đặt lại'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 2. TextField "Tìm trong ghi chú"
            TextField(
              controller: _queryController,
              decoration: InputDecoration(
                labelText: 'Tìm trong ghi chú',
                hintText: 'Nhập từ khóa tìm kiếm',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _queryController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _queryController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // 3. Loại: ba ChoiceChip "Tất cả" / "Thu" / "Chi"
            const Text(
              'Loại giao dịch',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Tất cả'),
                  selected: _draft.type == null,
                  onSelected: (selected) {
                    if (selected) _onTypeChanged(null);
                  },
                ),
                ChoiceChip(
                  label: const Text('Thu'),
                  selected: _draft.type == CategoryType.income,
                  selectedColor: AppColors.income.withValues(alpha: 0.2),
                  onSelected: (selected) {
                    if (selected) _onTypeChanged(CategoryType.income);
                  },
                ),
                ChoiceChip(
                  label: const Text('Chi'),
                  selected: _draft.type == CategoryType.expense,
                  selectedColor: AppColors.expense.withValues(alpha: 0.2),
                  onSelected: (selected) {
                    if (selected) _onTypeChanged(CategoryType.expense);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 4. Ví: DropdownButtonFormField<String?>
            DropdownButtonFormField<String?>(
              key: ValueKey('wallet_${_draft.walletId}'),
              initialValue: widget.wallets.any((w) => w.id == _draft.walletId)
                  ? _draft.walletId
                  : null,
              decoration: const InputDecoration(
                labelText: 'Ví',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Tất cả ví'),
                ),
                ...widget.wallets.map(
                  (w) => DropdownMenuItem<String?>(
                    value: w.id,
                    child: Text(w.walletName),
                  ),
                ),
              ],
              onChanged: (v) {
                setState(() {
                  _draft = _draft.copyWith(
                    walletId: v,
                    clearWallet: v == null,
                  );
                });
              },
            ),
            const SizedBox(height: 16),

            // 5. Danh mục: DropdownButtonFormField<String?>
            DropdownButtonFormField<String?>(
              key: ValueKey('cat_${_draft.categoryId}_${_draft.type}'),
              initialValue: availableCategories.any((c) => c.id == _draft.categoryId)
                  ? _draft.categoryId
                  : null,
              decoration: const InputDecoration(
                labelText: 'Danh mục',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Tất cả danh mục'),
                ),
                ...availableCategories.map(
                  (c) => DropdownMenuItem<String?>(
                    value: c.id,
                    child: Text(c.categoryName),
                  ),
                ),
              ],
              onChanged: (v) {
                setState(() {
                  _draft = _draft.copyWith(
                    categoryId: v,
                    clearCategory: v == null,
                  );
                });
              },
            ),
            const SizedBox(height: 16),

            // 6. Khoảng ngày: ListTile
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.date_range_outlined),
              title: const Text('Khoảng thời gian'),
              subtitle: Text(dateSubtitle),
              trailing: (_draft.from != null || _draft.to != null)
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _draft = _draft.copyWith(clearDates: true);
                        });
                      },
                    )
                  : const Icon(Icons.chevron_right),
              onTap: _pickDateRange,
            ),
            const SizedBox(height: 20),

            // 7. FilledButton "Áp dụng"
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final finalFilter = _draft.copyWith(
                    query: _queryController.text,
                  );
                  Navigator.pop(context, finalFilter);
                },
                child: const Text('Áp dụng'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
