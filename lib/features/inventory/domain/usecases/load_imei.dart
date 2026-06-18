import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/imei_record.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class LoadImei {
  final InventoryRepository _repo;
  LoadImei(this._repo);

  Future<(List<ImeiRecord>, InventoryFailure?)> call({
    String? productId,
    String? status,
  }) async {
    return _repo.loadImei(productId: productId, status: status);
  }
}

final loadImeiUseCaseProvider = Provider<LoadImei>((ref) {
  return LoadImei(ref.read(inventoryRepositoryProvider));
});
