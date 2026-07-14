import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/shift.dart';
import '../../domain/failures/hr_failure.dart';
import '../../domain/usecases/load_shifts.dart';
import '../../domain/usecases/upsert_shift.dart';

final shiftsProvider =
    AsyncNotifierProvider<ShiftsController, List<Shift>>(ShiftsController.new);

class ShiftsController extends AsyncNotifier<List<Shift>> {
  @override
  Future<List<Shift>> build() async {
    final (shifts, failure) = await ref.read(loadShiftsUseCaseProvider).call();
    if (failure != null) throw failure;
    return shifts;
  }

  Future<HrFailure?> upsert(Map<String, dynamic> data) async {
    final failure = await ref.read(upsertShiftUseCaseProvider).call(data);
    if (failure != null) return failure;
    ref.invalidateSelf();
    return null;
  }
}
