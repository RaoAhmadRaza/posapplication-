import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase.dart';

/// Root scope that throws away every cached provider when the signed-in user
/// changes, so no data outlives the session that fetched it.
///
/// Why this exists: ~80 controllers are plain (non-autoDispose) Notifier /
/// AsyncNotifier providers. Their `build()` runs once and caches, so after an
/// account switch the next user saw the previous user's dashboard figures, POS
/// cart, customer lists — anything already fetched — until a manual refresh.
/// With two tenants that is a cross-tenant disclosure, not just a stale screen.
///
/// Why a container swap rather than the obvious alternatives:
/// - Invalidating a hand-written list of providers is incomplete the day
///   someone adds the 83rd controller, and it cannot express the two duplicate
///   provider names that exist today.
/// - Keying the `ProviderScope` would rebuild `MaterialApp.router` from
///   scratch. GoRouter holds an internal navigator GlobalKey, and tearing the
///   old tree down alongside the new one is exactly the duplicate-key crash
///   this project has hit before.
/// - A nested `ProviderScope` does not isolate: without overrides, providers
///   still initialise in the root container.
///
/// Swapping the container on an `UncontrolledProviderScope` disposes every
/// provider (closing their realtime channels through `ref.onDispose`) while the
/// widget tree stays mounted — dependents just re-read from the new container.
///
/// Fires only on a real uid change, so token refreshes and `initialSession`
/// never disturb a live session.
class SessionScope extends StatefulWidget {
  const SessionScope({super.key, required this.child});

  final Widget child;

  @override
  State<SessionScope> createState() => _SessionScopeState();
}

class _SessionScopeState extends State<SessionScope> {
  ProviderContainer _container = ProviderContainer();
  StreamSubscription<AuthState>? _sub;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _uid = supabase.auth.currentUser?.id;
    _sub = supabase.auth.onAuthStateChange.listen((event) {
      final uid = event.session?.user.id;
      if (uid == _uid) return;
      _uid = uid;
      final previous = _container;
      setState(() => _container = ProviderContainer());
      // Dispose after the frame that adopts the new container, so nothing is
      // still reading the old one as it goes away.
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _container.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UncontrolledProviderScope(
        container: _container,
        child: widget.child,
      );
}
