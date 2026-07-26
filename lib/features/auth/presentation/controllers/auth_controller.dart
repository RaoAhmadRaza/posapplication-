import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/audit_service.dart';
import '../../../../core/supabase.dart';
import '../../domain/usecases/sign_out.dart';

final authControllerProvider = NotifierProvider<AuthController, void>(
  AuthController.new,
);

class AuthController extends Notifier<void> {
  @override
  void build() {}

  Future<void> signOut() async {
    AuditService.instance.log(action: 'LOGOUT', entity: 'auth');
    // Sign out FIRST and let the SIGNED_OUT handler in router.dart do the
    // user-scoped reset. Clearing the gate flags here while the session was
    // still alive made _redirect bounce the still-logged-in user through
    // /workspace-init on the way out: that screen mounted, fired its profile
    // load + 10s timer, then was torn down a moment later when signOut landed
    // and the redirect resolved to /login. Two overlapping page transitions
    // plus a half-built screen is what tripped the intermittent
    // 'check that it really is our descendant' element assertion. One hop now.
    await ref.read(signOutUseCaseProvider).call();
  }

  Session? get currentSession => supabase.auth.currentSession;
}
