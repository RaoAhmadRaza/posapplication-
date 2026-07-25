import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class UploadProductImage {
  final InventoryRepository _repo;
  UploadProductImage(this._repo);

  Future<(String?, InventoryFailure?)> call(
    String productId,
    Uint8List bytes,
    String ext,
  ) async {
    return _repo.uploadImage(productId, bytes, ext);
  }
}

final uploadProductImageUseCaseProvider = Provider<UploadProductImage>((ref) {
  return UploadProductImage(ref.read(inventoryRepositoryProvider));
});
