import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/grn.dart';
import '../failures/purchase_failure.dart';
import '../repositories/purchasing_repository.dart';
import '../../data/repositories/purchasing_repository_impl.dart';

class LoadGrns {
  final PurchasingRepository _repo;
  LoadGrns(this._repo);

  Future<(List<Grn>, PurchaseFailure?)> call(String poId) {
    return _repo.loadGrns(poId);
  }
}

final loadGrnsUseCaseProvider = Provider<LoadGrns>((ref) {
  return LoadGrns(ref.read(purchasingRepositoryProvider));
});
