import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../failures/hr_failure.dart';
import '../repositories/hr_repository.dart';
import '../../data/repositories/hr_repository_impl.dart';

class DecideLeave {
  final HrRepository _repo;
  DecideLeave(this._repo);

  Future<HrFailure?> call({
    required String leaveId,
    required bool approve,
    String? rejectionReason,
  }) {
    return _repo.decideLeave(
      leaveId: leaveId,
      approve: approve,
      rejectionReason: rejectionReason,
    );
  }
}

final decideLeaveUseCaseProvider = Provider<DecideLeave>((ref) {
  return DecideLeave(ref.read(hrRepositoryProvider));
});
