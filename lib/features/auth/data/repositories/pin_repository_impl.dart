import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/auth_failure.dart';
import '../../../../core/error/supabase_error_mapper.dart';
import '../datasources/auth_remote_datasource.dart';
import '../../domain/repositories/pin_repository.dart';

final pinRepositoryProvider = Provider<PinRepository>((ref) {
  return PinRepositoryImpl(ref.read(authRemoteDataSourceProvider));
});

class PinRepositoryImpl implements PinRepository {
  final AuthRemoteDataSource _ds;

  PinRepositoryImpl(this._ds);

  @override
  Future<AuthFailure?> updatePinHash(String userId, String? hash) async {
    try {
      await _ds.updatePinHash(userId, hash);
      return null;
    } catch (e) {
      debugPrint('[PinRepository] updatePinHash failed: $e');
      return mapSupabaseFailure(e);
    }
  }

  @override
  Future<(String?, AuthFailure?)> getServerPinHash(String userId) async {
    try {
      return (await _ds.selectPinHash(userId), null);
    } catch (e) {
      debugPrint('[PinRepository] getServerPinHash failed: $e');
      return (null, mapSupabaseFailure(e));
    }
  }
}
