import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../failures/hr_failure.dart';
import '../repositories/hr_repository.dart';
import '../../data/repositories/hr_repository_impl.dart';

class MarkAttendance {
  final HrRepository _repo;
  MarkAttendance(this._repo);

  Future<HrFailure?> call(Map<String, dynamic> data) =>
      _repo.markAttendance(data);
}

final markAttendanceUseCaseProvider = Provider<MarkAttendance>((ref) {
  return MarkAttendance(ref.read(hrRepositoryProvider));
});
