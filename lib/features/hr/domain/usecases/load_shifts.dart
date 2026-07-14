import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/shift.dart';
import '../failures/hr_failure.dart';
import '../repositories/hr_repository.dart';
import '../../data/repositories/hr_repository_impl.dart';

class LoadShifts {
  final HrRepository _repo;
  LoadShifts(this._repo);

  Future<(List<Shift>, HrFailure?)> call() => _repo.loadShifts();
}

final loadShiftsUseCaseProvider = Provider<LoadShifts>((ref) {
  return LoadShifts(ref.read(hrRepositoryProvider));
});
