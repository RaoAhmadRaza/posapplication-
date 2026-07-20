import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';
import 'core/env.dart';
import 'core/services/pin_service.dart';
import 'core/state/app_flow_state.dart';
import 'core/state/theme_controller.dart';
import 'core/supabase.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final isDesktop = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);
  if (isDesktop) {
    // sqflite has no native desktop impl — route it through the FFI factory.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await windowManager.ensureInitialized();
    await windowManager.setMinimumSize(const Size(420, 640));
  }

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
  );

  // Cold-start re-lock: a restored session must sit behind the PIN. The
  // lifecycle observer (app.dart) only arms the lock on resume, so without
  // this a force-quit + relaunch would skip /pin-lock entirely and land on the
  // dashboard. Arm synchronously before runApp so the first frame already
  // shows the lock — no bypass window. Guarded on a LOCAL PIN hash so a device
  // that never set/reconciled a PIN is never stranded on an unverifiable lock.
  if (supabase.auth.currentSession != null &&
      await PinService.instance.hasPin()) {
    PinLockState.instance.lock();
  }

  // Restore the saved light/dark choice before the first frame.
  await ThemeController.load();

  runApp(const ProviderScope(child: App()));
}