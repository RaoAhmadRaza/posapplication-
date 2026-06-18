import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase.dart';
import '../../domain/entities/import_result.dart';

final migrationRemoteDataSourceProvider =
    Provider<MigrationRemoteDataSource>((ref) {
  return MigrationRemoteDataSource(supabase);
});

class MigrationRemoteDataSource {
  final SupabaseClient _client;

  MigrationRemoteDataSource(this._client);

  Future<ImportResult> importCategories(
      List<Map<String, dynamic>> rows) async {
    final result = await _client.rpc('migrate_import_categories', params: {
      'p_rows': rows,
    });
    return _parseResult(result as Map<String, dynamic>);
  }

  Future<ImportResult> importBrands(List<Map<String, dynamic>> rows) async {
    final result = await _client.rpc('migrate_import_brands', params: {
      'p_rows': rows,
    });
    return _parseResult(result as Map<String, dynamic>);
  }

  Future<ImportResult> importProducts(List<Map<String, dynamic>> rows) async {
    final result = await _client.rpc('migrate_import_products', params: {
      'p_rows': rows,
    });
    return _parseResult(result as Map<String, dynamic>);
  }

  Future<ImportResult> importStock(
      String branchId, List<Map<String, dynamic>> rows) async {
    final result = await _client.rpc('migrate_import_stock', params: {
      'p_branch_id': branchId,
      'p_rows': rows,
    });
    return _parseResult(result as Map<String, dynamic>);
  }

  ImportResult _parseResult(Map<String, dynamic> data) {
    final errorsRaw = data['errors'] as List<dynamic>? ?? [];
    final ok = data['ok'] as int? ?? 0;
    final inserted = data['inserted'] as int? ?? ok;
    final skipped = data['skipped'] as int? ?? 0;
    final failed = data['failed'] as int? ?? 0;
    return ImportResult(
      ok: ok,
      inserted: inserted,
      skipped: skipped,
      failed: failed,
      errors: errorsRaw
          .map((e) => ImportRowError(
                row: (e as Map<String, dynamic>)['row'] as int? ?? 0,
                error: (e)['error'] as String? ?? '',
              ))
          .toList(),
    );
  }
}
