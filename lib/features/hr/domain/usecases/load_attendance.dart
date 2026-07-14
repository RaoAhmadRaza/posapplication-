import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/attendance.dart';
import '../failures/hr_failure.dart';
import '../repositories/hr_repository.dart';
import '../../data/repositories/hr_repository_impl.dart';

class LoadAttendance {
  final HrRepository _repo;
  LoadAttendance(this._repo);

  Future<(List<Attendance>, HrFailure?)> call({
    required String from,
    required String to,
    String? employeeId,
  }) {
    return _repo.loadAttendance(from: from, to: to, employeeId: employeeId);
  }
}

final loadAttendanceUseCaseProvider = Provider<LoadAttendance>((ref) {
  return LoadAttendance(ref.read(hrRepositoryProvider));
});
