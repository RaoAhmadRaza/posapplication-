import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/auth_profile.dart';
import '../../domain/usecases/load_profile.dart';

final profileControllerProvider =
    NotifierProvider<ProfileController, AsyncValue<AuthProfile?>>(
  ProfileController.new,
);

class ProfileController extends Notifier<AsyncValue<AuthProfile?>> {
  @override
  AsyncValue<AuthProfile?> build() => const AsyncValue.data(null);

  Future<void> load(String userId) async {
    state = const AsyncValue.loading();
    final (profile, failure) =
        await ref.read(loadProfileUseCaseProvider).call(userId);
    if (failure != null) {
      state = AsyncValue.error(failure, StackTrace.current);
    } else {
      state = AsyncValue.data(profile);
    }
  }
}
