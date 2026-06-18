import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/entities/branch.dart';
import '../../domain/usecases/load_user_branches.dart';

const _storage = FlutterSecureStorage();
const _branchIdKey = 'current_branch_id';

final userBranchesProvider =
    NotifierProvider<UserBranchesController, AsyncValue<List<Branch>>>(
  UserBranchesController.new,
);

final currentBranchProvider =
    NotifierProvider<CurrentBranchNotifier, Branch?>(
  CurrentBranchNotifier.new,
);

final branchesReadyProvider = Provider<bool>((ref) {
  final state = ref.watch(userBranchesProvider);
  return !state.isLoading && !state.hasError && state.value != null;
});

class CurrentBranchNotifier extends Notifier<Branch?> {
  @override
  Branch? build() => null;

  void setBranch(Branch? branch) => state = branch;
}

class BranchRouterState extends ChangeNotifier {
  static final instance = BranchRouterState();

  bool _loaded = false;
  bool _autoSelected = false;
  int _count = 0;

  bool get needsSelection => _loaded && _count > 1 && !_autoSelected;

  void reset() {
    if (_loaded || _autoSelected || _count != 0) {
      _loaded = false;
      _autoSelected = false;
      _count = 0;
      notifyListeners();
    }
  }

  void onBranchesLoaded(List<Branch> branches) {
    _loaded = true;
    _count = branches.length;
    _autoSelected = branches.length <= 1;
    notifyListeners();
  }

  void onBranchSelected() {
    _autoSelected = true;
    notifyListeners();
  }
}

class UserBranchesController extends Notifier<AsyncValue<List<Branch>>> {
  @override
  AsyncValue<List<Branch>> build() => const AsyncValue.loading();

  Future<void> load(String userId) async {
    state = const AsyncValue.loading();
    final (branches, failure) =
        await ref.read(loadUserBranchesUseCaseProvider).call(userId);

    if (failure != null) {
      state = AsyncValue.error(failure, StackTrace.current);
      return;
    }

    state = AsyncValue.data(branches);

    if (branches.length <= 1) {
      final selected = branches.isNotEmpty ? branches.first : null;
      ref.read(currentBranchProvider.notifier).setBranch(selected);
      if (selected != null) {
        await _storage.write(key: _branchIdKey, value: selected.id);
      }
    } else {
      final storedId = await _storage.read(key: _branchIdKey);
      final current = storedId != null
          ? branches.where((b) => b.id == storedId).firstOrNull
          : null;
      final selected = current ??
          branches.where((b) => b.isDefault).firstOrNull ??
          branches.first;
      ref.read(currentBranchProvider.notifier).setBranch(selected);
      await _storage.write(key: _branchIdKey, value: selected.id);
    }

    BranchRouterState.instance.onBranchesLoaded(branches);
  }

  Future<void> selectBranch(Branch branch) async {
    ref.read(currentBranchProvider.notifier).setBranch(branch);
    await _storage.write(key: _branchIdKey, value: branch.id);
    BranchRouterState.instance.onBranchSelected();
  }
}
