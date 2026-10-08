import 'package:flutter/foundation.dart';
import '../models/wallet.dart';
import '../repositories/wallet_repository.dart';

class WalletProvider extends ChangeNotifier {
  final WalletRepository _repo;
  final String userId;
  WalletProvider(this._repo, this.userId);

  List<Wallet> wallets = [];
  bool isLoading = false;
  int totalBalance = 0;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    wallets = await _repo.getAll(userId);
    totalBalance = await _repo.getTotalBalance(userId);
    isLoading = false;
    notifyListeners();
  }

  Future<void> addWallet({
    required String name,
    required String type,
    int initialBalance = 0,
    String? color,
    String? icon,
  }) async {
    await _repo.create(
        userId: userId, walletName: name, walletType: type, initialBalance: initialBalance, color: color, icon: icon);
    await load();
  }

  Future<void> editWallet(Wallet wallet) async {
    await _repo.update(wallet);
    await load();
  }

  Future<void> deleteWallet(String id) async {
    await _repo.delete(id);
    await load();
  }
}
