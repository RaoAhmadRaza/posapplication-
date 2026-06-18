import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class LoadInventorySettings {
  final InventoryRepository _repo;
  LoadInventorySettings(this._repo);

  Future<(Map<String, dynamic>, InventoryFailure?)> call() async {
    return _repo.loadInventorySettings();
  }
}

final loadInventorySettingsUseCaseProvider = Provider<LoadInventorySettings>((ref) {
  return LoadInventorySettings(ref.read(inventoryRepositoryProvider));
});
