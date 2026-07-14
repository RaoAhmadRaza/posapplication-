import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../failures/hr_failure.dart';
import '../repositories/hr_repository.dart';
import '../../data/repositories/hr_repository_impl.dart';

class UpsertShift {
  final HrRepository _repo;
  UpsertShift(this._repo);

  Future<HrFailure?> call(Map<String, dynamic> data) =>
      _repo.upsertShift(data);
}

final upsertShiftUseCaseProvider = Provider<UpsertShift>((ref) {
  return UpsertShift(ref.read(hrRepositoryProvider));
});
