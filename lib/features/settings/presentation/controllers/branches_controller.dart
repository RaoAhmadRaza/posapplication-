import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/supabase.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/branch_config.dart';
import '../../domain/failures/settings_failure.dart';
import '../../domain/usecases/settings_usecases.dart';

final branchesProvider =
    AsyncNotifierProvider<BranchesController, List<BranchConfig>>(
  BranchesController.new,
);

class BranchesController extends AsyncNotifier<List<BranchConfig>> {
  @override
  Future<List<BranchConfig>> build() async {
    final (branches, failure) = await ref.read(loadBranchesUseCaseProvider)();
    if (failure != null) throw failure;
    return branches;
  }

  Future<SettingsFailure?> saveBranch({
    required String branchId,
    String? name,
    String? city,
    String? country,
    String? currency,
    String? timezone,
    bool? isActive,
  }) async {
    final failure = await ref.read(updateBranchSettingsUseCaseProvider)(
      branchId: branchId,
      name: name,
      city: city,
      country: country,
      currency: currency,
      timezone: timezone,
      isActive: isActive,
    );
    if (failure != null) return failure;
    ref.invalidateSelf();
    await future;
    return null;
  }

  Future<SettingsFailure?> createBranch({
    required String name,
    String? city,
    String? country,
    String? currency,
    String? timezone,
  }) async {
    final failure = await ref.read(createBranchUseCaseProvider)(
      name: name,
      city: city,
      country: country,
      currency: currency,
      timezone: timezone,
    );
    if (failure != null) return failure;
    ref.invalidateSelf();
    await future;
    // Refresh the user's own branch list too (create_branch assigns the creator),
    // so "Switch branch" becomes available once a second branch exists — no relogin.
    final uid = supabase.auth.currentUser?.id;
    if (uid != null) {
      await ref.read(userBranchesProvider.notifier).load(uid);
    }
    return null;
  }
}
