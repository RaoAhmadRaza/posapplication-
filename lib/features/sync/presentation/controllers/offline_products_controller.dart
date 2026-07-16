import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../inventory/domain/entities/product.dart';
import '../../domain/entities/cached_product.dart';
import '../../domain/usecases/read_cache.dart';

/// Offline product search backed by the local reference cache. Maps a
/// CachedProduct onto the inventory Product entity the POS grid already renders,
/// so nothing downstream changes.
///
/// ponytail: tenantId/type/costPrice/unitOfMeasure/reorder* are fabricated with
/// inert defaults — none are read on the offline cash-sale path (COGS, stock and
/// serialization are resolved server-side at replay, D7.2). Upgrade to real
/// values only if an offline flow starts depending on them.
final offlineProductSearchProvider =
    FutureProvider.family<List<Product>, String>((ref, query) async {
  final (rows, failure) =
      await ref.read(searchCachedProductsUseCaseProvider).call(query);
  if (failure != null) return const [];
  return rows.map(_toProduct).toList();
});

Product _toProduct(CachedProduct c) => Product(
      id: c.id,
      tenantId: '',
      sku: c.sku,
      name: c.name,
      barcode: c.barcode,
      type: ProductType.standard,
      unitOfMeasure: 'unit',
      costPrice: 0,
      sellingPrice: c.sellingPrice,
      minSellingPrice: c.minSellingPrice,
      taxRate: c.taxRate,
      taxInclusive: c.taxInclusive,
      reorderPoint: 0,
      reorderQty: 0,
      isActive: c.isActive,
      status: ProductStatus.active,
    );
