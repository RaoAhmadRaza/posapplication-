import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/category.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../domain/usecases/load_categories.dart';
import '../../domain/usecases/save_category.dart';
import '../../domain/usecases/delete_category.dart';

final categoriesProvider =
    AsyncNotifierProvider<CategoriesController, List<Category>>(
  CategoriesController.new,
);

class CategoriesController extends AsyncNotifier<List<Category>> {
  @override
  Future<List<Category>> build() async {
    final (categories, failure) =
        await ref.read(loadCategoriesUseCaseProvider).call();
    if (failure != null) throw failure;
    return categories;
  }

  void refresh() => ref.invalidateSelf();

  Future<InventoryFailure?> save({
    required Map<String, dynamic> data,
    String? id,
  }) async {
    final (_, failure) = await ref
        .read(saveCategoryUseCaseProvider)
        .call(data: data, id: id);
    if (failure != null) return failure;
    ref.invalidateSelf();
    return null;
  }

  Future<void> remove(String id) async {
    final (_, failure) =
        await ref.read(deleteCategoryUseCaseProvider).call(id);
    if (failure != null) {
      state = AsyncValue.error(failure, StackTrace.current);
      return;
    }
    ref.invalidateSelf();
  }
}
