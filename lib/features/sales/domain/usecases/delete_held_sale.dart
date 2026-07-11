import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/failures/sales_failure.dart';
import '../../data/repositories/sales_repository_impl.dart';
import '../../domain/repositories/sales_repository.dart';

class DeleteHeldSale {
  final SalesRepository _repo;
  DeleteHeldSale(this._repo);

  Future<(bool, SalesFailure?)> call(String id) async {
    return _repo.deleteHeldSale(id);
  }
}

final deleteHeldSaleUseCaseProvider = Provider<DeleteHeldSale>((ref) {
  return DeleteHeldSale(ref.read(salesRepositoryProvider));
});
