import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/product.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class GetProduct {
  final InventoryRepository _repo;
  GetProduct(this._repo);

  Future<(Product?, InventoryFailure?)> call(String id) async {
    return _repo.getProduct(id);
  }
}

final getProductUseCaseProvider = Provider<GetProduct>((ref) {
  return GetProduct(ref.read(inventoryRepositoryProvider));
});
