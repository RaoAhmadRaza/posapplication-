import 'package:flutter/services.dart';

/// Centralized haptic semantics so feedback is consistent across the app
/// (raw HapticFeedback calls were previously scattered in the PIN screens).
class AppHaptics {
  const AppHaptics._();

  /// Light tick — selection, key press, toggle.
  static void selection() => HapticFeedback.selectionClick();

  /// Positive confirmation — success toast, completed action.
  static void success() => HapticFeedback.mediumImpact();

  /// Negative — error, rejected input, wrong PIN.
  static void error() => HapticFeedback.heavyImpact();

  /// Warning / caution.
  static void warning() => HapticFeedback.mediumImpact();
}
