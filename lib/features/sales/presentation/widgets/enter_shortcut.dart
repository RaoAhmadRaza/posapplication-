import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Runs [onEnter] when Enter is pressed, wherever focus happens to be.
///
/// The counter flow is keyboard-first: Enter charges the cart, confirms the
/// payment, opens the receipt, then prints. A null [onEnter] means the page has
/// nothing to commit yet (empty cart, sale in flight) and Enter is left alone.
///
/// Deliberately NOT `Shortcuts`/`CallbackShortcuts`: those only see keys that
/// bubble up from whatever holds focus, and this app's shell owns a focus node
/// above the branch navigator, so a pushed page could come up without focus and
/// swallow the first Enter. Chasing the focus back with `requestFocus` fixed it
/// most of the time, which is worse than not at all on a till. A keyboard
/// handler does not care where focus is.
class EnterShortcut extends StatefulWidget {
  const EnterShortcut({super.key, required this.onEnter, required this.child});

  final VoidCallback? onEnter;
  final Widget child;

  @override
  State<EnterShortcut> createState() => _EnterShortcutState();
}

class _EnterShortcutState extends State<EnterShortcut> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    // KeyDownEvent only: a held Enter also emits KeyRepeatEvent, and repeating
    // 'complete sale' is not a feature.
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.enter &&
        event.logicalKey != LogicalKeyboardKey.numpadEnter) {
      return false;
    }
    final onEnter = widget.onEnter;
    if (onEnter == null) return false;
    // Every mounted EnterShortcut is handed this event, and pages stay mounted
    // when something is stacked on them — only the topmost route may act.
    if (ModalRoute.of(context)?.isCurrent != true) return false;
    // ...and the register also stays mounted while another module's tab is on
    // screen, where its route is still 'current' in its own branch navigator.
    // Offstage branches and covered routes are ticker-disabled; visible ones
    // are not.
    if (!TickerMode.valuesOf(context).enabled) return false;
    onEnter();
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
