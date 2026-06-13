import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/barcode_template.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class SaveBarcodeTemplate {
  final InventoryRepository _repo;
  SaveBarcodeTemplate(this._repo);

  Future<(BarcodeTemplate?, InventoryFailure?)> call({
    required Map<String, dynamic> data,
    String? id,
  }) async {
    if (id != null) {
      return _repo.updateBarcodeTemplate(id, data);
    }
    return _repo.createBarcodeTemplate(data);
  }
}

final saveBarcodeTemplateUseCaseProvider = Provider<SaveBarcodeTemplate>((ref) {
  return SaveBarcodeTemplate(ref.read(inventoryRepositoryProvider));
});
