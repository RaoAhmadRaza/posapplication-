import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/auth_profile.dart';
import '../../domain/usecases/load_profile.dart';
import '../../../../core/supabase.dart';

final profileControllerProvider =
    NotifierProvider<ProfileController, AsyncValue<AuthProfile?>>(
  ProfileController.new,
);

class ProfileController extends Notifier<AsyncValue<AuthProfile?>> {
  @override
  AsyncValue<AuthProfile?> build() => const AsyncValue.data(null);

  Future<void> load(String userId) async {
    // TEMP debug
    debugPrint('[PROFILE] load called for userId=$userId, current auth.uid=${supabase.auth.currentUser?.id}');
    state = const AsyncValue.loading();
    final (profile, failure) =
        await ref.read(loadProfileUseCaseProvider).call(userId);
    if (failure != null) {
      state = AsyncValue.error(failure, StackTrace.current);
    } else {
      // TEMP debug
      debugPrint('[PROFILE] loaded: fullName=${profile?.fullName} email=${profile?.email} tenant=${profile?.tenantName} role=${profile?.roleName}');
      state = AsyncValue.data(profile);
    }
  }
}
