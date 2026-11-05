import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/ai_chat_provider.dart';
import '../../repositories/ai_chat_repository.dart';
import '../../repositories/auto_sync_service.dart';

class AiChatScreen extends StatelessWidget {
  const AiChatScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (c) =>
            AiChatProvider(AiChatRepository(), c.read<AutoSyncService>()),
        child: const _ChatView(),
      );
}

class _ChatView extends StatefulWidget {
  const _ChatView();

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  static const _examples = [
    'Tháng này tôi chi nhiều nhất vào đâu?',
    'So với tháng trước, chi tiêu của tôi tăng hay giảm?',
    'Tôi nên cắt giảm khoản nào?',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  Future<void> _send(String text) async {
    final p = context.read<AiChatProvider>();
    if (p.isSending || text.trim().isEmpty) return;
    _input.clear();
    final future = p.send(text);
    _scrollToEnd();
    await future;
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AiChatProvider>();
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hỏi đáp tài chính AI'),
        actions: [
          if (p.messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Xóa hội thoại',
              onPressed: p.isSending ? null : p.clear,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'AI dựa trên số liệu tổng hợp 3 tháng gần nhất. Không gửi số dư và ghi chú giao dịch.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: p.messages.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const Text('Bạn có thể hỏi:',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        for (final q in _examples)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ActionChip(
                                label: Text(q), onPressed: () => _send(q)),
                          ),
                      ],
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: p.messages.length + (p.isSending ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == p.messages.length) {
                          return _bubble(
                              const ChatMessage(false, 'Đang phân tích...'),
                              width);
                        }
                        return _bubble(p.messages[i], width);
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 3,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        hintText: 'Hỏi về chi tiêu của bạn...',
                        counterText: '',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: p.isSending ? null : _send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: p.isSending ? null : () => _send(_input.text),
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(ChatMessage message, double width) {
    final color = message.isError
        ? AppColors.danger.withValues(alpha: 0.1)
        : message.fromUser
            ? AppColors.primary.withValues(alpha: 0.12)
            : Colors.grey.shade100;
    return Align(
      alignment: message.fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: BoxConstraints(maxWidth: width * 0.8),
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        child: Text(message.text,
            style: const TextStyle(fontSize: 14, height: 1.4)),
      ),
    );
  }
}
