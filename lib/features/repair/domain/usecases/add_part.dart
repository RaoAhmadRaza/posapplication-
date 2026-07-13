import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/repair_results.dart';
import '../failures/repair_failure.dart';
import '../repositories/repair_repository.dart';
import '../../data/repositories/repair_repository_impl.dart';

class AddPart {
  final RepairRepository _repo;
  AddPart(this._repo);

  Future<(RepairPartResult?, RepairFailure?)> call({
    required String repairId,
    required String productId,
    String? variantId,
    required double qty,
    String? notes,
  }) {
    return _repo.addPart(
      repairId: repairId,
      productId: productId,
      variantId: variantId,
      qty: qty,
      notes: notes,
    );
  }
}

final addPartUseCaseProvider = Provider<AddPart>((ref) {
  return AddPart(ref.read(repairRepositoryProvider));
});
