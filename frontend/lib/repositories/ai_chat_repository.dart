import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';

enum ChatStatus {
  ok,
  insufficientData,
  offline,
  unauthorized,
  syncFailed,
  rateLimited,
  unavailable,
  error,
}

class ChatMessage {
  final bool fromUser;
  final String text;
  final bool isError;

  const ChatMessage(this.fromUser, this.text, {this.isError = false});
}

class ChatOutcome {
  final ChatStatus status;
  final String? reply;
  final String? message;

  const ChatOutcome(this.status, {this.reply, this.message});
}

class AiChatRepository {
  static const maxMessages = 6;

  Future<ChatOutcome> ask(List<ChatMessage> history) async {
    if (!ApiClient.instance.hasToken) {
      return const ChatOutcome(ChatStatus.offline);
    }
    final sendable = history.where((m) => !m.isError).toList();
    final window = sendable.length > maxMessages
        ? sendable.sublist(sendable.length - maxMessages)
        : sendable;
    dynamic res;
    try {
      res = await ApiClient.instance.post(
        ApiEndpoints.aiChat,
        body: {
          'messages': [
            for (final m in window)
              {'role': m.fromUser ? 'USER' : 'ASSISTANT', 'content': m.text},
          ],
        },
        receiveTimeout: const Duration(seconds: 60),
      );
    } on NetworkException {
      return const ChatOutcome(ChatStatus.offline);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        return ChatOutcome(ChatStatus.unauthorized, message: e.message);
      }
      if (e.statusCode == 429 || e.code == 'AI_RATE_LIMITED') {
        return ChatOutcome(ChatStatus.rateLimited, message: e.message);
      }
      if (e.statusCode == 503 || e.code == 'AI_UNAVAILABLE') {
        return ChatOutcome(ChatStatus.unavailable, message: e.message);
      }
      return ChatOutcome(ChatStatus.error, message: e.message);
    }
    if (res is! Map) return const ChatOutcome(ChatStatus.error);
    if (res['status'] == 'INSUFFICIENT_DATA') {
      return ChatOutcome(
        ChatStatus.insufficientData,
        message: res['message']?.toString(),
      );
    }
    final reply = res['reply'];
    if (res['status'] != 'OK' || reply is! String || reply.trim().isEmpty) {
      return const ChatOutcome(ChatStatus.error);
    }
    return ChatOutcome(ChatStatus.ok, reply: reply.trim());
  }
}
