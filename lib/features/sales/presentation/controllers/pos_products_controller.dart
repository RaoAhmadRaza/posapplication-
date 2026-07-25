import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../inventory/domain/entities/product.dart';
import '../../../inventory/presentation/controllers/products_controller.dart';

/// POS's own product loader: a SECOND, independent instance of the inventory
/// [ProductsController]. Reuses its pagination (loadMore), search and
/// stock-merge, but keeps separate state so POS and the catalog page never
/// cross-filter. Stock for the grid still comes from `stockLevelsProvider`.
final posProductsProvider =
    AsyncNotifierProvider<ProductsController, List<Product>>(
  ProductsController.new,
);
