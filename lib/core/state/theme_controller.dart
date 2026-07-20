import 'package:flutter/material.dart';

/// App-wide light/dark ("Counter mode") toggle.
///
/// A tiny singleton [ValueNotifier] the root [MaterialApp] listens to. In-memory
/// only for now — resets to [ThemeMode.light] on cold start (persistence can be
/// added later via shared_preferences without changing callers).
class ThemeController {
  ThemeController._();
  static final ValueNotifier<ThemeMode> mode =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  static void toggle() {
    mode.value =
        mode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  static void set(ThemeMode value) => mode.value = value;
}
