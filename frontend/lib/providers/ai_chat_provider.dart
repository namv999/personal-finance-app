import 'package:flutter/foundation.dart';

import '../repositories/ai_chat_repository.dart';
import '../repositories/auto_sync_service.dart';

class AiChatProvider extends ChangeNotifier {
  final AiChatRepository _repo;
  final AutoSyncService _sync;

  AiChatProvider(this._repo, this._sync);

  final List<ChatMessage> messages = [];
  bool isSending = false;
  bool _synced = false;
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void clear() {
    messages.clear();
    notifyListeners();
  }

  Future<void> send(String raw) async {
    var text = raw.trim();
    if (text.isEmpty || isSending) return;
    if (text.length > 500) text = text.substring(0, 500);
    messages.add(ChatMessage(true, text));
    isSending = true;
    notifyListeners();
    try {
      if (!_synced) {
        final sync = await _sync.syncNow();
        if (!sync.ok) {
          _addError(_text(sync.error == 'NO_TOKEN'
              ? ChatStatus.offline
              : sync.unauthorized
                  ? ChatStatus.unauthorized
                  : ChatStatus.syncFailed));
          return;
        }
        _synced = true;
      }
      final out = await _repo.ask(messages);
      if (out.status == ChatStatus.ok) {
        messages.add(ChatMessage(false, out.reply!));
      } else if (out.status == ChatStatus.insufficientData) {
        _addError(
            '${out.message ?? 'Chưa đủ dữ liệu.'} Hãy ghi thêm giao dịch rồi hỏi lại.');
      } else {
        _addError(_text(out.status));
      }
    } finally {
      isSending = false;
      notifyListeners();
    }
  }

  void _addError(String text) =>
      messages.add(ChatMessage(false, text, isError: true));

  static String _text(ChatStatus status) => switch (status) {
        ChatStatus.offline => 'Cần kết nối mạng và đăng nhập online để hỏi AI',
        ChatStatus.unauthorized => 'Phiên hết hạn, hãy đăng nhập lại',
        ChatStatus.syncFailed =>
          'Không đồng bộ được dữ liệu nên chưa thể trả lời. Thử lại sau',
        ChatStatus.rateLimited =>
          'Dịch vụ AI đang quá tải, thử lại sau ít phút',
        ChatStatus.unavailable => 'Dịch vụ AI tạm thời không khả dụng',
        _ => 'Có lỗi, vui lòng thử lại',
      };
}
