import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../providers/budget_provider.dart';
import '../../providers/pet_streak_provider.dart';
import '../../providers/saving_goal_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/transfer_provider.dart';
import '../../providers/wallet_provider.dart';

/// Refreshes providers derived from ledger data after a successful DB write.
class LedgerRefresh {
  final List<Future<void> Function()> _loaders;
  LedgerRefresh._(this._loaders);

  static List<Future<void> Function()> _derived(BuildContext context) => [
        context.read<WalletProvider>().load,
        context.read<SavingGoalProvider>().load,
        context.read<BudgetProvider>().load,
        context.read<PetStreakProvider>().load,
      ];

  /// TransactionProvider and TransferProvider reload themselves after writes.
  factory LedgerRefresh.of(BuildContext context) =>
      LedgerRefresh._(_derived(context));

  /// Also reload ledger lists after cascading operations such as wallet deletion.
  factory LedgerRefresh.all(BuildContext context) => LedgerRefresh._([
        ..._derived(context),
        context.read<TransactionProvider>().load,
        context.read<TransferProvider>().load,
      ]);

  /// A refresh failure must not report a successful DB write as failed.
  Future<void> run() async {
    await Future.wait(_loaders.map((load) async {
      try {
        await load();
      } catch (_) {
        // Data was already written; this refresh is best effort.
      }
    }));
  }
}
