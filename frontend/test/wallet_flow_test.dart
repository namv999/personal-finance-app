import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:personal_finance_app/core/constants/app_routes.dart';
import 'package:personal_finance_app/models/wallet.dart';
import 'package:personal_finance_app/providers/auth_provider.dart';
import 'package:personal_finance_app/providers/wallet_provider.dart';
import 'package:personal_finance_app/routes/app_router.dart';

class _Auth extends ChangeNotifier implements AuthProvider {
  @override
  AuthStatus status = AuthStatus.authenticated;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Wallets extends ChangeNotifier implements WalletProvider {
  final List<Wallet> _wallets = [];

  @override
  List<Wallet> get wallets => _wallets;

  @override
  bool isLoaded = true;

  @override
  bool isLoading = false;

  @override
  Future<void> addWallet({
    required String name,
    required String type,
    int initialBalance = 0,
    String? color,
    String? icon,
  }) async {
    _wallets.add(Wallet(
      id: 'w1',
      userId: 'u1',
      walletName: name,
      walletType: type,
      currentBalance: initialBalance,
      openingBalance: initialBalance,
      color: color,
      icon: icon,
    ));
    notifyListeners();
  }

  @override
  Future<void> load() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Auth auth;
  late _Wallets wallets;
  late GoRouter router;

  setUp(() {
    auth = _Auth();
    wallets = _Wallets();
    router = buildRouter(auth, wallets);
  });

  tearDown(() => router.dispose());

  Widget app() => MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<WalletProvider>.value(value: wallets),
        ],
        child: MaterialApp.router(routerConfig: router),
      );

  testWidgets('first wallet creation returns to wallet list', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path,
        AppRoutes.walletCreateRequired);

    await tester.enterText(find.byType(TextFormField).first, 'Ví chính');
    await tester.enterText(find.byType(TextFormField).last, '250000');
    await tester.ensureVisible(find.text('Tạo ví & Bắt đầu'));
    await tester.tap(find.text('Tạo ví & Bắt đầu'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.wallets);
    expect(find.text('Ví của tôi'), findsOneWidget);
    expect(find.text('Tạo ví đầu tiên'), findsNothing);
  });

  testWidgets('deleting the last wallet returns to required creation screen',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Ví chính');
    await tester.enterText(find.byType(TextFormField).last, '250000');
    await tester.ensureVisible(find.text('Tạo ví & Bắt đầu'));
    await tester.tap(find.text('Tạo ví & Bắt đầu'));
    await tester.pumpAndSettle();

    wallets.wallets.clear();
    wallets.notifyListeners();
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path,
        AppRoutes.walletCreateRequired);
    expect(find.text('Tạo ví đầu tiên'), findsOneWidget);
  });

  testWidgets('editing a wallet exposes its current balance', (tester) async {
    wallets.wallets.add(Wallet(
      id: 'w1',
      userId: 'u1',
      walletName: 'Ví chính',
      walletType: 'SPENDING',
      currentBalance: 1250000,
      openingBalance: 1000000,
    ));
    router.go(AppRoutes.walletEditPath('w1'));

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.pump();

    expect(find.text('Số dư hiện tại'), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) =>
          widget is TextFormField && widget.controller?.text == '1250000'),
      findsOneWidget,
    );
  });
}
