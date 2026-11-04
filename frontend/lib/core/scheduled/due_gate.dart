import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/scheduled_provider.dart';
import '../notifications/notification_service.dart';

/// Watches schedules while the app is open and hands due occurrences to UI.
class DueGate extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Future<void> Function(BuildContext context) onShowDue;
  final Widget child;

  const DueGate({
    super.key,
    required this.navigatorKey,
    required this.onShowDue,
    required this.child,
  });

  @override
  State<DueGate> createState() => _DueGateState();
}

class _DueGateState extends State<DueGate> with WidgetsBindingObserver {
  Timer? _timer;
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.instance.tapTick.addListener(_reload);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationService.instance.tapTick.removeListener(_reload);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reload();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
    }
  }

  void _reload() {
    if (!mounted) return;
    context.read<ScheduledProvider>().load().catchError((Object e) {
      debugPrint('GDHT due check lỗi: $e');
    });
  }

  Future<void> _evaluate() async {
    if (_showing || !mounted) return;
    final auth = context.read<AuthProvider>();
    final provider = context.read<ScheduledProvider>();
    if (auth.status != AuthStatus.authenticated ||
        provider.userId == '_none_') {
      _timer?.cancel();
      return;
    }
    if (provider.due.isNotEmpty) {
      final navContext = widget.navigatorKey.currentContext;
      if (navContext == null) {
        _armTimer();
        return;
      }
      _showing = true;
      _timer?.cancel();
      try {
        await widget.onShowDue(navContext);
      } finally {
        _showing = false;
      }
    }
    if (mounted) _armTimer();
  }

  void _armTimer() {
    _timer?.cancel();
    final wait = context.read<ScheduledProvider>().timeUntilNextDue();
    if (wait == null || wait == Duration.zero) return;
    const cap = Duration(hours: 6);
    _timer =
        Timer((wait > cap ? cap : wait) + const Duration(seconds: 1), _reload);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ScheduledProvider>();
    context.watch<AuthProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _evaluate());
    return widget.child;
  }
}
