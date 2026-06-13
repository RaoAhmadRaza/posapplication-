import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/brand.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../domain/usecases/load_brands.dart';
import '../../domain/usecases/save_brand.dart';
import '../../domain/usecases/delete_brand.dart';

final brandsProvider =
    AsyncNotifierProvider<BrandsController, List<Brand>>(
  BrandsController.new,
);

class BrandsController extends AsyncNotifier<List<Brand>> {
  @override
  Future<List<Brand>> build() async {
    final (brands, failure) =
        await ref.read(loadBrandsUseCaseProvider).call();
    if (failure != null) throw failure;
    return brands;
  }

  void refresh() => ref.invalidateSelf();

  Future<InventoryFailure?> save({
    required Map<String, dynamic> data,
    String? id,
  }) async {
    final (_, failure) =
        await ref.read(saveBrandUseCaseProvider).call(data: data, id: id);
    if (failure != null) return failure;
    ref.invalidateSelf();
    return null;
  }

  Future<void> remove(String id) async {
    final (_, failure) =
        await ref.read(deleteBrandUseCaseProvider).call(id);
    if (failure != null) {
      state = AsyncValue.error(failure, StackTrace.current);
      return;
    }
    ref.invalidateSelf();
  }
}
