import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../failures/hr_failure.dart';
import '../repositories/hr_repository.dart';
import '../../data/repositories/hr_repository_impl.dart';

class ApplyLeave {
  final HrRepository _repo;
  ApplyLeave(this._repo);

  Future<HrFailure?> call(Map<String, dynamic> data) => _repo.applyLeave(data);
}

final applyLeaveUseCaseProvider = Provider<ApplyLeave>((ref) {
  return ApplyLeave(ref.read(hrRepositoryProvider));
});
