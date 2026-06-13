import 'package:flutter/foundation.dart';

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

class WorkspaceInitState extends ChangeNotifier {
  static final instance = WorkspaceInitState();

  bool _completed = false;
  bool get completed => _completed;

  set completed(bool v) {
    if (_completed != v) {
      _completed = v;
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

  void clear() {
    if (_needsMfa) {
      _needsMfa = false;
      notifyListeners();
    }
  }
}
