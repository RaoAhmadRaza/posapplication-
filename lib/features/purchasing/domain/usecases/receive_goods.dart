import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/purchase_results.dart';
import '../failures/purchase_failure.dart';
import '../repositories/purchasing_repository.dart';
import '../../data/repositories/purchasing_repository_impl.dart';

class ReceiveGoods {
  final PurchasingRepository _repo;
  ReceiveGoods(this._repo);

  Future<(ReceiveResult?, PurchaseFailure?)> call({
    required String poId,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) {
    return _repo.receiveGoods(poId: poId, notes: notes, items: items);
  }
}

final receiveGoodsUseCaseProvider = Provider<ReceiveGoods>((ref) {
  return ReceiveGoods(ref.read(purchasingRepositoryProvider));
});
