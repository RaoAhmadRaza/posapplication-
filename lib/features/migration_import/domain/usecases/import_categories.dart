import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../inventory/domain/failures/inventory_failure.dart';
import '../../domain/entities/import_result.dart';
import '../../domain/repositories/migration_repository.dart';
import '../../data/repositories/migration_repository_impl.dart';

class ImportCategories {
  final MigrationRepository _repo;
  ImportCategories(this._repo);

  Future<(ImportResult?, InventoryFailure?)> call(
      List<Map<String, dynamic>> rows) async {
    return _repo.importCategories(rows);
  }
}

final importCategoriesUseCaseProvider = Provider<ImportCategories>((ref) {
  return ImportCategories(ref.read(migrationRepositoryProvider));
});
