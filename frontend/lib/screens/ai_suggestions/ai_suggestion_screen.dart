import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/ai_suggestion.dart';
import '../../providers/ai_suggestion_provider.dart';
import '../../repositories/ai_suggestion_repository.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';

class AiSuggestionScreen extends StatefulWidget {
  const AiSuggestionScreen({super.key});

  @override
  State<AiSuggestionScreen> createState() => _AiSuggestionScreenState();
}

class _AiSuggestionScreenState extends State<AiSuggestionScreen> {
  String? _insufficientDataMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final p = context.read<AiSuggestionProvider>();
        if (p.current == null && !p.isLoading) {
          p.load();
        }
      }
    });
  }

  Future<void> _request(BuildContext context) async {
    final provider = context.read<AiSuggestionProvider>();
    setState(() {
      _insufficientDataMessage = null;
    });

    final outcome = await provider.requestNew();
    if (!context.mounted) return;

    if (outcome.status == SuggestStatus.ok) {
      return;
    }

    if (outcome.status == SuggestStatus.insufficientData) {
      setState(() {
        _insufficientDataMessage =
            outcome.message ?? 'Chưa đủ dữ liệu để tạo gợi ý.';
      });
      return;
    }

    final text = switch (outcome.status) {
      SuggestStatus.offline =>
        'Cần kết nối mạng và đăng nhập online để tạo gợi ý',
      SuggestStatus.unauthorized => 'Phiên hết hạn, hãy đăng nhập lại',
      SuggestStatus.syncFailed => outcome.message == 'BUSY'
          ? 'Đang đồng bộ, thử lại sau ít giây'
          : 'Không đồng bộ được dữ liệu nên chưa thể tạo gợi ý. Thử lại sau',
      SuggestStatus.rateLimited =>
        'Dịch vụ AI đang quá tải, thử lại sau ít phút',
      SuggestStatus.unavailable => 'Dịch vụ AI tạm thời không khả dụng',
      SuggestStatus.error || SuggestStatus.busy => 'Có lỗi, vui lòng thử lại',
      _ => 'Có lỗi, vui lòng thử lại',
    };

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _formatPeriodLabel(AiPeriod period) {
    if (period.type == AiPeriodType.month) {
      return 'Tháng ${Formatters.monthYear(period.start)}';
    } else {
      final startStr = DateFormat('dd/MM').format(period.start);
      final endStr = DateFormat('dd/MM').format(period.end);
      return '$startStr – $endStr';
    }
  }

  String _formatAmount(dynamic val) {
    if (val is num) return Formatters.currency(val);
    if (val is String) {
      final parsed = num.tryParse(val);
      if (parsed != null) return Formatters.currency(parsed);
    }
    return '0 đ';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AiSuggestionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gợi ý tài chính AI'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Đầu màn: SegmentedButton và nhãn kỳ
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<AiPeriodType>(
                      segments: const [
                        ButtonSegment<AiPeriodType>(
                          value: AiPeriodType.week,
                          label: Text('Tuần tới'),
                        ),
                        ButtonSegment<AiPeriodType>(
                          value: AiPeriodType.month,
                          label: Text('Tháng tới'),
                        ),
                      ],
                      selected: {provider.periodType},
                      onSelectionChanged: provider.isRequesting
                          ? null
                          : (selected) {
                              setState(() {
                                _insufficientDataMessage = null;
                              });
                              provider.setType(selected.first);
                            },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatPeriodLabel(provider.targetPeriod),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),

            // Phần nội dung gợi ý / empty / insufficient data
            Expanded(
              child: provider.isLoading
                  ? const LoadingView()
                  : _buildBodyContent(context, provider),
            ),

            // 4 & 5. Nút chính và ghi chú nhỏ
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: provider.isRequesting
                        ? null
                        : () => _request(context),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor:
                          AppColors.primary.withOpacity(0.12),
                      disabledForegroundColor: AppColors.primary,
                    ),
                    child: provider.isRequesting
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Đang đồng bộ và phân tích...',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ],
                          )
                        : Text(
                            provider.current != null ? 'Tạo lại' : 'Tạo gợi ý',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Gợi ý dựa trên dữ liệu đã đồng bộ. AI chỉ diễn giải, mọi số liệu do hệ thống tính.',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyContent(
      BuildContext context, AiSuggestionProvider provider) {
    final current = provider.current;
    if (current == null) {
      if (_insufficientDataMessage != null) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildInsufficientDataCard(_insufficientDataMessage!),
            const SizedBox(height: 16),
            const EmptyState(
              icon: Icons.auto_awesome_outlined,
              title: 'Chưa có gợi ý cho kỳ này',
              subtitle:
                  'Nhấn "Tạo gợi ý" bên dưới để nhận phân tích chi tiêu và lời khuyên tài chính.',
            ),
          ],
        );
      }
      return const EmptyState(
        icon: Icons.auto_awesome_outlined,
        title: 'Chưa có gợi ý cho kỳ này',
        subtitle:
            'Nhấn "Tạo gợi ý" bên dưới để nhận phân tích chi tiêu và lời khuyên tài chính.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_insufficientDataMessage != null)
          _buildInsufficientDataCard(_insufficientDataMessage!),
        _buildSuggestionCard(context, current),
        _buildDataSection(context, current),
      ],
    );
  }

  Widget _buildInsufficientDataCard(String message) {
    return Card(
      color: const Color(0xFFF0F7F6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.primary, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: AppColors.primary, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Hãy ghi thêm giao dịch rồi thử lại.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionCard(BuildContext context, AiSuggestion current) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome,
                    color: AppColors.secondary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Lời khuyên tài chính',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._buildContentLines(current.suggestionContent),
            const SizedBox(height: 12),
            Text(
              'Tạo lúc ${DateFormat('dd/MM HH:mm').format(current.createdAt.toLocal())}',
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContentLines(String content) {
    final lines = content.split('\n');
    final widgets = <Widget>[];
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('- ') ||
          line.startsWith('* ') ||
          line.startsWith('• ')) {
        final text = line.substring(2).trim();
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '• ',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              line,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  Widget _buildDataSection(BuildContext context, AiSuggestion current) {
    if (current.suggestedData == null || current.suggestedData!.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(current.suggestedData!);
      if (decoded is Map<String, dynamic>) {
        data = decoded;
      }
    } catch (_) {
      return const SizedBox.shrink();
    }
    if (data == null || data.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(top: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading:
              const Icon(Icons.analytics_outlined, color: AppColors.primary),
          title: const Text(
            'Số liệu',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          children: [
            _buildSuggestedDataDetails(data),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestedDataDetails(Map<String, dynamic> data) {
    final avgIncome = data['avg_income'];
    final avgExpense = data['avg_expense'];
    final topCategories = data['top_expense_categories'];
    final budgets = data['budgets'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (avgIncome is num || avgExpense is num) ...[
          Row(
            children: [
              if (avgIncome is num)
                Expanded(
                  child: _buildMetricTile(
                    label: 'Thu nhập TB',
                    value: Formatters.currency(avgIncome),
                    color: AppColors.income,
                  ),
                ),
              if (avgIncome is num && avgExpense is num)
                const SizedBox(width: 8),
              if (avgExpense is num)
                Expanded(
                  child: _buildMetricTile(
                    label: 'Chi tiêu TB',
                    value: Formatters.currency(avgExpense),
                    color: AppColors.expense,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (topCategories is List && topCategories.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 6),
            child: Text(
              'Top danh mục chi tiêu',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          for (final item in topCategories)
            if (item is Map) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${item['category_name'] ?? item['name'] ?? 'Khác'}',
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_formatAmount(item['avg_amount'])} (${item['share_percent'] ?? 0}%)',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
        ],
        if (budgets is List && budgets.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Divider(height: 16, color: AppColors.divider),
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 6),
            child: Text(
              'Ngân sách',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          for (final b in budgets)
            if (b is Map) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${b['category_name'] ?? 'Khác'}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (b['over_limit'] == true)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Vượt hạn mức',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.danger,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Đã chi: ${_formatAmount(b['avg_spent'])} / Hạn mức: ${_formatAmount(b['spending_limit'])}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ],
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}
