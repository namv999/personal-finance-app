import 'package:flutter/foundation.dart';

import '../core/sms/bank_sms_filter.dart';
import '../core/sms/sms_reader.dart';
import '../models/category.dart';
import '../models/pending_transaction.dart';
import '../repositories/pending_transaction_repository.dart';

enum PasteOutcome { invalid, duplicate, parsed, queued }

enum SmsScanStatus { done, denied, permanentlyDenied, busy, error }

class SmsScanResult {
  final SmsScanStatus status;
  final int found;
  final int added;

  const SmsScanResult(this.status, {this.found = 0, this.added = 0});
}

class PendingProvider extends ChangeNotifier {
  final PendingTransactionRepository _repository;
  final String userId;

  PendingProvider(this._repository, this.userId);

  List<PendingTransaction> _items = [];
  bool _busy = false;
  bool _disposed = false;
  AiRunResult lastRun = AiRunResult.nothing;

  List<PendingTransaction> get needsAi =>
      _items.where((item) => item.status == PendingStatus.needsAi).toList();
  List<PendingTransaction> get pending =>
      _items.where((item) => item.status == PendingStatus.pending).toList();
  int get pendingCount => pending.length;
  bool get busy => _busy;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> load() async {
    _items = await _repository.getByStatus(userId, const [
      PendingStatus.needsAi,
      PendingStatus.pending,
    ]);
    notifyListeners();
  }

  Future<PasteOutcome> submitText(String raw) async {
    final text = raw.trim();
    if (text.isEmpty ||
        text.length > PendingTransactionRepository.maxContentLength) {
      return PasteOutcome.invalid;
    }
    final pending = await _repository.addRaw(userId, text);
    if (pending == null) return PasteOutcome.duplicate;
    await retryNeedsAi();
    return _items.any((item) =>
            item.id == pending.id && item.status == PendingStatus.pending)
        ? PasteOutcome.parsed
        : PasteOutcome.queued;
  }

  Future<void> retryNeedsAi() async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      lastRun = await _repository.processNeedsAi(userId);
      await load();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Analyzes an image while sharing the busy state with SMS scanning.
  Future<ImageRunResult> submitImage(Uint8List bytes) async {
    if (_busy) return const ImageRunResult(ImageRunStatus.busy);
    _busy = true;
    notifyListeners();
    try {
      final result = await _repository.processImage(userId, bytes);
      if (result.status == ImageRunStatus.added) await load();
      return result;
    } catch (_) {
      return const ImageRunResult(ImageRunStatus.error);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Scans only after an explicit user action and adds at most [maxNew] messages.
  Future<SmsScanResult> scanSms({int maxNew = 30}) async {
    if (_busy) return const SmsScanResult(SmsScanStatus.busy);
    _busy = true;
    notifyListeners();
    try {
      var permission = await SmsReader.status();
      if (permission != SmsPermission.granted) {
        permission = await SmsReader.request();
      }
      if (permission == SmsPermission.permanentlyDenied) {
        return const SmsScanResult(SmsScanStatus.permanentlyDenied);
      }
      if (permission != SmsPermission.granted) {
        return const SmsScanResult(SmsScanStatus.denied);
      }

      final inbox = await SmsReader.readInbox();
      final candidates = inbox
          .where((sms) => BankSmsFilter.looksLikeTransaction(sms.body))
          .toList();
      var added = 0;
      for (final sms in candidates) {
        if (added >= maxNew) break;
        try {
          final item = await _repository.addRaw(
            userId,
            sms.body,
            source: PendingSource.sms,
            receivedAt: sms.date,
          );
          if (item != null) added++;
        } on ArgumentError {
          continue;
        }
      }
      await load();

      for (var attempt = 0; attempt < 3; attempt++) {
        final before = needsAi.length;
        if (before == 0) break;
        lastRun = await _repository.processNeedsAi(userId);
        await load();
        if (lastRun != AiRunResult.done || needsAi.length >= before) break;
      }
      return SmsScanResult(SmsScanStatus.done,
          found: candidates.length, added: added);
    } catch (_) {
      return const SmsScanResult(SmsScanStatus.error);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> confirm({
    required String pendingId,
    required String walletId,
    required int amount,
    required CategoryType type,
    required DateTime date,
    String? note,
    String? categoryId,
  }) async {
    await _repository.confirm(
      userId: userId,
      pendingId: pendingId,
      walletId: walletId,
      amount: amount,
      type: type,
      date: date,
      note: note,
      categoryId: categoryId,
    );
    await load();
  }

  Future<void> reject(String pendingId) async {
    await _repository.reject(userId, pendingId);
    await load();
  }
}
