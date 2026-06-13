import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/warehouse.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../domain/usecases/load_warehouses.dart';
import '../../domain/usecases/create_warehouse.dart';
import '../../domain/usecases/update_warehouse.dart';
import '../../domain/usecases/delete_warehouse.dart';
import '../../domain/usecases/set_default_warehouse.dart';
import '../../domain/usecases/ensure_default_warehouse.dart';

final warehousesProvider =
    AsyncNotifierProvider<WarehousesController, List<Warehouse>>(
  WarehousesController.new,
);

class WarehousesController extends AsyncNotifier<List<Warehouse>> {
  @override
  Future<List<Warehouse>> build() async {
    final branch = ref.read(currentBranchProvider);
    if (branch == null) return <Warehouse>[];

    await ref.read(ensureDefaultWarehouseUseCaseProvider).call(branch.id);

    final (warehouses, failure) = await ref
        .read(loadWarehousesUseCaseProvider)
        .call(branchId: branch.id);
    if (failure != null) throw failure;
    return warehouses;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    final branch = ref.read(currentBranchProvider);
    if (branch == null) {
      state = AsyncValue.error(
        NotFoundFailure(),
        StackTrace.current,
      );
      return;
    }

    final (warehouses, failure) = await ref
        .read(loadWarehousesUseCaseProvider)
        .call(branchId: branch.id);
    if (failure != null) {
      state = AsyncValue.error(failure, StackTrace.current);
      return;
    }
    state = AsyncValue.data(warehouses);
  }

  Future<InventoryFailure?> save({
    required Map<String, dynamic> data,
    String? id,
  }) async {
    if (id != null) {
      final (_, failure) =
          await ref.read(updateWarehouseUseCaseProvider).call(id, data);
      if (failure != null) return failure;
    } else {
      final branch = ref.read(currentBranchProvider);
      if (branch == null) return NotFoundFailure();
      final payload = {...data, 'branch_id': branch.id};
      final (_, failure) =
          await ref.read(createWarehouseUseCaseProvider).call(payload);
      if (failure != null) return failure;
    }
    refresh();
    return null;
  }

  Future<void> remove(String id) async {
    final (_, failure) =
        await ref.read(deleteWarehouseUseCaseProvider).call(id);
    if (failure != null) {
      state = AsyncValue.error(failure, StackTrace.current);
      return;
    }
    refresh();
  }

  Future<void> setDefault(String id) async {
    final (_, failure) =
        await ref.read(setDefaultWarehouseUseCaseProvider).call(id);
    if (failure != null) {
      state = AsyncValue.error(failure, StackTrace.current);
      return;
    }
    refresh();
  }
}
