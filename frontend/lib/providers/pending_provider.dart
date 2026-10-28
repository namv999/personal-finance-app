import 'package:flutter/foundation.dart';

import '../models/category.dart';
import '../models/pending_transaction.dart';
import '../repositories/pending_transaction_repository.dart';

enum PasteOutcome { invalid, duplicate, parsed, queued }

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
