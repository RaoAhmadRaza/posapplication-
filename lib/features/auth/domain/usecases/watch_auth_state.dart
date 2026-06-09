import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../repositories/auth_repository.dart';

class WatchAuthState {
  final AuthRepository _repo;
  WatchAuthState(this._repo);

  Stream<AuthState> call() => _repo.watchAuthState();
}

final watchAuthStateUseCaseProvider = Provider<WatchAuthState>((ref) {
  return WatchAuthState(ref.read(authRepositoryProvider));
});
