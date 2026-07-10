import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/auth_failure.dart';
import '../../../../core/error/supabase_error_mapper.dart';
import '../datasources/auth_remote_datasource.dart';
import '../../domain/repositories/login_throttle_repository.dart';

final loginThrottleRepositoryProvider = Provider<LoginThrottleRepository>((ref) {
  return LoginThrottleRepositoryImpl(ref.read(authRemoteDataSourceProvider));
});

class LoginThrottleRepositoryImpl implements LoginThrottleRepository {
  final AuthRemoteDataSource _ds;

  LoginThrottleRepositoryImpl(this._ds);

  @override
  Future<(Map<String, dynamic>?, AuthFailure?)> incrementFailedLogin(
      String email) async {
    try {
      return (await _ds.incrementFailedLogin(email), null);
    } catch (e) {
      debugPrint('[LoginThrottleRepository] increment failed: $e');
      return (null, mapSupabaseFailure(e));
    }
  }

  @override
  Future<AuthFailure?> resetFailedLogin(String email) async {
    try {
      await _ds.resetFailedLogin(email);
      return null;
    } catch (e) {
      debugPrint('[LoginThrottleRepository] reset failed: $e');
      return mapSupabaseFailure(e);
    }
  }
}
