import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide light/dark ("Counter mode") toggle, persisted across launches.
///
/// A tiny singleton [ValueNotifier] the root [MaterialApp] listens to. Call
/// [load] once at startup (after WidgetsFlutterBinding) to restore the saved
/// choice; [set]/[toggle] persist automatically.
class ThemeController {
  ThemeController._();

  static const _prefKey = 'theme_mode';

  static final ValueNotifier<ThemeMode> mode =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  /// Restore the persisted mode. Safe to call before runApp.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    mode.value = switch (saved) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.light,
    };
  }

  static void toggle() {
    set(mode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  static void set(ThemeMode value) {
    mode.value = value;
    _persist(value);
  }

  static Future<void> _persist(ThemeMode value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, value == ThemeMode.dark ? 'dark' : 'light');
  }
}
