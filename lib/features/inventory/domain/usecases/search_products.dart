import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/product.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class SearchProducts {
  final InventoryRepository _repo;
  SearchProducts(this._repo);

  Future<(List<Product>, InventoryFailure?)> call(String q) async {
    return _repo.searchProducts(q);
  }
}

final searchProductsUseCaseProvider = Provider<SearchProducts>((ref) {
  return SearchProducts(ref.read(inventoryRepositoryProvider));
});
