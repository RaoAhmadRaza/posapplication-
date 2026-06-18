import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/imei_record.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class RegisterImei {
  final InventoryRepository _repo;
  RegisterImei(this._repo);

  Future<(ImeiRecord?, InventoryFailure?)> call({
    required String productId,
    required String? variantId,
    required String branchId,
    required String? warehouseId,
    required String imei,
    required String sourceType,
    required double costPrice,
    bool postStock = true,
  }) async {
    return _repo.registerImei(
      productId: productId,
      variantId: variantId,
      branchId: branchId,
      warehouseId: warehouseId,
      imei: imei,
      sourceType: sourceType,
      costPrice: costPrice,
      postStock: postStock,
    );
  }
}

final registerImeiUseCaseProvider = Provider<RegisterImei>((ref) {
  return RegisterImei(ref.read(inventoryRepositoryProvider));
});
