import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/product_image.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class SaveImage {
  final InventoryRepository _repo;
  SaveImage(this._repo);

  Future<(ProductImage?, InventoryFailure?)> call(Map<String, dynamic> data) async {
    return _repo.addImage(data);
  }
}

final saveImageUseCaseProvider = Provider<SaveImage>((ref) {
  return SaveImage(ref.read(inventoryRepositoryProvider));
});
