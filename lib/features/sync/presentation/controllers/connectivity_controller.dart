import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ConnectivityMonitor as a plain Riverpod stream — online/offline, no singleton.
/// NOTE (ponytail): connectivity_plus reports interface presence, not actual
/// internet reachability; good enough for airplane-mode / offline gating. A real
/// reachability probe (ping the API) is the upgrade if false-online bites.
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  yield _isOnline(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(_isOnline);
});

bool _isOnline(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);

/// Synchronous best-effort read for gating logic (defaults to online while the
/// first value is still loading, so a momentary unknown never blocks a sale).
extension ConnectivityRead on WidgetRef {
  bool get isOnline =>
      watch(connectivityProvider).maybeWhen(data: (v) => v, orElse: () => true);
}
