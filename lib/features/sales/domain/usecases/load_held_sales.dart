import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/held_sale.dart';
import '../../domain/failures/sales_failure.dart';
import '../../data/repositories/sales_repository_impl.dart';
import '../../domain/repositories/sales_repository.dart';

class LoadHeldSales {
  final SalesRepository _repo;
  LoadHeldSales(this._repo);

  Future<(List<HeldSale>, SalesFailure?)> call({String? branchId}) async {
    return _repo.loadHeldSales(branchId: branchId);
  }
}

final loadHeldSalesUseCaseProvider = Provider<LoadHeldSales>((ref) {
  return LoadHeldSales(ref.read(salesRepositoryProvider));
});
