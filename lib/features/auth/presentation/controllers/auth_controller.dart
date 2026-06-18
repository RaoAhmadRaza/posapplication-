import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/audit_service.dart';
import '../../../../core/state/app_flow_state.dart';
import '../../../../core/supabase.dart';
import '../../domain/usecases/sign_out.dart';
import '../controllers/branch_controller.dart' show BranchRouterState;

final authControllerProvider = NotifierProvider<AuthController, void>(
  AuthController.new,
);

class AuthController extends Notifier<void> {
  @override
  void build() {}

  Future<void> signOut() async {
    AuditService.instance.log(action: 'LOGOUT', entity: 'auth');
    BranchRouterState.instance.reset();
    await resetUserScopedState();
    await ref.read(signOutUseCaseProvider).call();
  }

  Session? get currentSession => supabase.auth.currentSession;
}
