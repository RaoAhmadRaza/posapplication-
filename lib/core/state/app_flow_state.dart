import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../error/auth_failure.dart';

const _storage = FlutterSecureStorage();
const _branchIdKey = 'current_branch_id';

class EnvCheckState extends ChangeNotifier {
  static final instance = EnvCheckState();

  bool _passed = false;
  bool get passed => _passed;

  set passed(bool v) {
    if (_passed != v) {
      _passed = v;
      notifyListeners();
    }
  }
}

/// Cold-start brand splash. Held on `/splash` until [shown] flips true (the
/// splash page sets it after a brief display), then the router proceeds to the
/// env-check gate. Lives for the app's lifetime — shown once per launch.
class SplashState extends ChangeNotifier {
  static final instance = SplashState();

  bool _shown = false;
  bool get shown => _shown;

  set shown(bool v) {
    if (_shown != v) {
      _shown = v;
      notifyListeners();
    }
  }
}

class WorkspaceInitState extends ChangeNotifier {
  static final instance = WorkspaceInitState();

  bool _completed = false;
  bool get completed => _completed;

  void reset() {
    if (_completed) {
      _completed = false;
      debugPrint('[WORKSPACE-STATE] reset: completed=false');
      notifyListeners();
    }
  }

  set completed(bool v) {
    if (_completed != v) {
      _completed = v;
      debugPrint('[WORKSPACE-STATE] completed=$v');
      notifyListeners();
    }
  }
}

class PinLockState extends ChangeNotifier {
  static final instance = PinLockState();

  bool _locked = false;
  bool get locked => _locked;

  void lock() {
    if (!_locked) {
      _locked = true;
      notifyListeners();
    }
  }

  void unlock() {
    if (_locked) {
      _locked = false;
      notifyListeners();
    }
  }
}

class MfaState extends ChangeNotifier {
  static final instance = MfaState();

  bool _needsMfa = false;
  bool get needsMfa => _needsMfa;

  void require() {
    if (!_needsMfa) {
      _needsMfa = true;
      notifyListeners();
    }
  }

  void reset() {
    if (_needsMfa) {
      _needsMfa = false;
      notifyListeners();
    }
  }

  void clear() {
    if (_needsMfa) {
      _needsMfa = false;
      notifyListeners();
    }
  }
}

Future<void> resetUserScopedState() async {
  debugPrint('[AUTH-LIFECYCLE] resetUserScopedState called');
  WorkspaceInitState.instance.reset();
  PinLockState.instance.unlock();
  MfaState.instance.reset();
  RecoveryState.instance.reset();
  try {
    await _storage.delete(key: _branchIdKey);
    debugPrint('[AUTH-LIFECYCLE] cleared branch storage');
  } catch (_) {}
}
