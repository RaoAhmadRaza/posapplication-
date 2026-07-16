import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';
import 'core/env.dart';
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
  runApp(const ProviderScope(child: App()));
}