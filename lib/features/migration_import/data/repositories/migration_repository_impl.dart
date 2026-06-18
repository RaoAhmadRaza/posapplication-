import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../inventory/domain/failures/inventory_failure.dart';
import '../../domain/entities/import_result.dart';
import '../../domain/repositories/migration_repository.dart';
import '../datasources/migration_remote_datasource.dart';

final migrationRepositoryProvider = Provider<MigrationRepository>((ref) {
  return MigrationRepositoryImpl(
      ref.read(migrationRemoteDataSourceProvider));
});

class MigrationRepositoryImpl implements MigrationRepository {
  final MigrationRemoteDataSource _ds;

  MigrationRepositoryImpl(this._ds);

  InventoryFailure _mapError(Object e) {
    return UnknownFailure(e.toString());
  }

  @override
  Future<(ImportResult?, InventoryFailure?)> importCategories(
      List<Map<String, dynamic>> rows) async {
    try {
      final result = await _ds.importCategories(rows);
      return (result, null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(ImportResult?, InventoryFailure?)> importBrands(
      List<Map<String, dynamic>> rows) async {
    try {
      final result = await _ds.importBrands(rows);
      return (result, null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(ImportResult?, InventoryFailure?)> importProducts(
      List<Map<String, dynamic>> rows) async {
    try {
      final result = await _ds.importProducts(rows);
      return (result, null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(ImportResult?, InventoryFailure?)> importStock(
      String branchId, List<Map<String, dynamic>> rows) async {
    try {
      final result = await _ds.importStock(branchId, rows);
      return (result, null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }
}
