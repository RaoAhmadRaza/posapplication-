import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/supabase.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/watch_auth_state.dart';

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.read(watchAuthStateUseCaseProvider).call();
});

final authControllerProvider = NotifierProvider<AuthController, void>(
  AuthController.new,
);

class AuthController extends Notifier<void> {
  @override
  void build() {}

  Future<void> signOut() async {
    await ref.read(signOutUseCaseProvider).call();
  }

  Session? get currentSession => supabase.auth.currentSession;
}
