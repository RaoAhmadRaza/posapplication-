import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/features/inventory/data/repositories/inventory_repository_impl.dart';
import 'package:pos_app/features/inventory/domain/entities/product.dart';
import 'package:pos_app/features/inventory/domain/failures/inventory_failure.dart';
import 'package:pos_app/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:pos_app/features/inventory/presentation/controllers/product_edit_controller.dart';

/// Records which write path the controller took. Only the two product methods
/// matter here; noSuchMethod covers the rest of the repository surface.
class _FakeRepo implements InventoryRepository {
  int creates = 0;
  final updatedIds = <String>[];

  @override
  Future<(Product?, InventoryFailure?)> createProduct(
      Map<String, dynamic> data) async {
    creates++;
    return (_product('p$creates'), null);
  }

  @override
  Future<(Product?, InventoryFailure?)> updateProduct(
      String id, Map<String, dynamic> data) async {
    updatedIds.add(id);
    return (_product(id), null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

Product _product(String id) => Product(
      id: id,
      tenantId: 't1',
      sku: id,
      name: id,
      type: ProductType.standard,
      unitOfMeasure: 'PCS',
      costPrice: 1,
      sellingPrice: 2,
      taxRate: 0,
      taxInclusive: false,
      reorderPoint: 0,
      reorderQty: 0,
      isActive: true,
      status: ProductStatus.active,
    );

void main() {
  test('a second new product inserts instead of updating the first', () async {
    final repo = _FakeRepo();
    final container = ProviderContainer(
      overrides: [inventoryRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(productEditProvider.notifier);

    // First "New product" form.
    notifier.startNew();
    await notifier.saveProduct({'name': 'A'});

    // Second one, opened on the same (non-autoDispose) controller.
    notifier.startNew();
    await notifier.saveProduct({'name': 'B'});

    expect(repo.creates, 2);
    expect(repo.updatedIds, isEmpty);
    expect(notifier.editingId, 'p2');
  });

  test('editing an existing product still updates it', () async {
    final repo = _FakeRepo();
    final container = ProviderContainer(
      overrides: [inventoryRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(productEditProvider.notifier);
    notifier.editingId = 'existing';
    await notifier.saveProduct({'name': 'A'});

    expect(repo.creates, 0);
    expect(repo.updatedIds, ['existing']);
  });
}
