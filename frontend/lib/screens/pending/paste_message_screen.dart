import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/network/api_client.dart';
import '../../providers/pending_provider.dart';
import '../../repositories/pending_transaction_repository.dart';

class PasteMessageScreen extends StatefulWidget {
  const PasteMessageScreen({super.key});

  @override
  State<PasteMessageScreen> createState() => _PasteMessageScreenState();
}

class _PasteMessageScreenState extends State<PasteMessageScreen> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final provider = context.read<PendingProvider>();
      final outcome = await provider.submitText(_controller.text);
      if (!mounted) return;
      switch (outcome) {
        case PasteOutcome.invalid:
          _show('Yêu cầu nhập nội dung không quá 1000 ký tự.');
          break;
        case PasteOutcome.duplicate:
          _show('Tin nhắn đã có trong hộp thư.');
          break;
        case PasteOutcome.parsed:
          context.go(AppRoutes.pendingInbox);
          break;
        case PasteOutcome.queued:
          final message = switch (provider.lastRun) {
            AiRunResult.offline =>
              'Đang offline. Tin vẫn được lưu trên máy để phân tích khi có mạng.',
            AiRunResult.rateLimited =>
              'AI đang giới hạn lượt gọi. Tin vẫn được lưu trên máy để thử lại sau.',
            AiRunResult.unavailable || AiRunResult.error =>
              'AI tạm lỗi hoặc cần thử lại. Tin vẫn được lưu trên máy.',
            AiRunResult.done =>
              'Chưa phân tích được giao dịch. Tin vẫn được lưu trên máy để thử lại.',
            _ => 'Tin vẫn được lưu trên máy để thử lại sau.',
          };
          _show(message);
          _returnToInbox();
          break;
      }
    } on NetworkException {
      if (mounted) {
        _show(
            'Đang offline. Tin vẫn được lưu trên máy để phân tích khi có mạng.');
        _returnToInbox();
      }
    } catch (e) {
      if (mounted) {
        _show('AI tạm lỗi hoặc cần thử lại. Tin vẫn được lưu trên máy.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _returnToInbox() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dán tin nhắn')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              key: const ValueKey('paste_message_input'),
              controller: _controller,
              minLines: 5,
              maxLines: 10,
              maxLength: 1000,
              decoration: const InputDecoration(
                hintText: 'Dán nội dung tin nhắn giao dịch tại đây...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined,
                    size: 16, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Số tài khoản, số điện thoại và số dư được che trước khi gửi.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Đang phân tích...'),
                      ],
                    )
                  : const Text('Phân tích'),
            ),
          ],
        ),
      ),
    );
  }
}
