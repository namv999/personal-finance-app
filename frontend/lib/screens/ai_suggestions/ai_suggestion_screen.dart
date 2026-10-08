import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/ai_suggestion_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';

class AiSuggestionScreen extends StatelessWidget {
  const AiSuggestionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AiSuggestionProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Gợi ý tài chính AI')),
      body: provider.isLoading
          ? const LoadingView()
          : provider.suggestions.isEmpty
              ? EmptyState(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Chưa có gợi ý nào',
                  subtitle: 'Nhận lời khuyên tài chính cá nhân hóa dựa trên chi tiêu tháng này',
                  actionLabel: 'Nhận gợi ý ngay',
                  onAction: () => context.read<AiSuggestionProvider>().requestNew(),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final s in provider.suggestions)
                      Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Icon(Icons.auto_awesome, color: AppColors.secondary, size: 18),
                                const SizedBox(width: 6),
                                Text('Tháng ${s.month}', style: const TextStyle(fontWeight: FontWeight.w700)),
                              ]),
                              const SizedBox(height: 10),
                              Text(s.suggestionContent),
                              const SizedBox(height: 8),
                              Text(Formatters.date(s.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.read<AiSuggestionProvider>().requestNew(),
        icon: const Icon(Icons.refresh),
        label: const Text('Gợi ý mới'),
      ),
    );
  }
}
