import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../inventory/domain/failures/inventory_failure.dart';
import '../../domain/entities/import_result.dart';
import '../../domain/repositories/migration_repository.dart';
import '../../data/repositories/migration_repository_impl.dart';

class ImportStock {
  final MigrationRepository _repo;
  ImportStock(this._repo);

  Future<(ImportResult?, InventoryFailure?)> call(
      String branchId, List<Map<String, dynamic>> rows) async {
    return _repo.importStock(branchId, rows);
  }
}

final importStockUseCaseProvider = Provider<ImportStock>((ref) {
  return ImportStock(ref.read(migrationRepositoryProvider));
});
