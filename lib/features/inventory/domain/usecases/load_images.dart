import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/product_image.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class LoadImages {
  final InventoryRepository _repo;
  LoadImages(this._repo);

  Future<(List<ProductImage>, InventoryFailure?)> call(String productId) async {
    return _repo.loadImages(productId);
  }
}

final loadImagesUseCaseProvider = Provider<LoadImages>((ref) {
  return LoadImages(ref.read(inventoryRepositoryProvider));
});
