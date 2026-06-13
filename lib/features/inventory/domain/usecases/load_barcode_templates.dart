import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/barcode_template.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class LoadBarcodeTemplates {
  final InventoryRepository _repo;
  LoadBarcodeTemplates(this._repo);

  Future<(List<BarcodeTemplate>, InventoryFailure?)> call() async {
    return _repo.loadBarcodeTemplates();
  }
}

final loadBarcodeTemplatesUseCaseProvider = Provider<LoadBarcodeTemplates>((ref) {
  return LoadBarcodeTemplates(ref.read(inventoryRepositoryProvider));
});
