import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../../data/repositories/inventory_repository_impl.dart';

class BulkImportProducts {
  final InventoryRepository _repo;
  BulkImportProducts(this._repo);

  Future<(Map<String, dynamic>, InventoryFailure?)> call(
      List<Map<String, dynamic>> rows) async {
    return _repo.bulkImportProducts(rows);
  }
}

final bulkImportProductsUseCaseProvider = Provider<BulkImportProducts>((ref) {
  return BulkImportProducts(ref.read(inventoryRepositoryProvider));
});
