import 'package:flutter/foundation.dart';
import '../models/transfer.dart';
import '../repositories/transfer_repository.dart';

class TransferProvider extends ChangeNotifier {
  final TransferRepository _repo;
  final String userId;
  TransferProvider(this._repo, this.userId);

  List<Transfer> transfers = [];
  bool isLoading = false;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    transfers = await _repo.getAll(userId, limit: 200);
    isLoading = false;
    notifyListeners();
  }

  Future<void> addTransfer({
    required String sourceWalletId,
    required String destinationWalletId,
    String? goalId,
    required int amount,
    required DateTime date,
    String? note,
  }) async {
    await _repo.create(
      userId: userId,
      sourceWalletId: sourceWalletId,
      destinationWalletId: destinationWalletId,
      goalId: goalId,
      amount: amount,
      transferDate: date,
      note: note,
    );
    await load();
  }

  Future<void> deleteTransfer(Transfer transfer) async {
    await _repo.delete(transfer);
    await load();
  }
}
