import 'package:flutter/material.dart';
import 'core/design/app_theme.dart';
import 'core/services/pin_service.dart';
import 'core/state/app_flow_state.dart';
import 'router.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPinLock();
    }
  }

  Future<void> _checkPinLock() async {
    final hasPin = await PinService.instance.hasPin();
    if (hasPin && mounted) {
      PinLockState.instance.lock();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: appRouter,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
    );
  }
}
