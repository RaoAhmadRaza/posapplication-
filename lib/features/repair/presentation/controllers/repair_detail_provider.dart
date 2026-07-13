import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/repair_job.dart';
import '../../domain/entities/repair_part.dart';
import '../../domain/entities/repair_status_history.dart';
import '../../domain/entities/repair_results.dart';
import '../../domain/usecases/load_repair_job.dart';
import '../../domain/usecases/load_technicians.dart';

/// Full detail bundle for one repair job.
class RepairDetail {
  final RepairJob job;
  final List<RepairPart> parts;
  final List<RepairStatusHistory> history;
  const RepairDetail({
    required this.job,
    required this.parts,
    required this.history,
  });

  double get partsCost =>
      parts.fold(0, (sum, p) => sum + p.totalCost);
}

final repairJobDetailProvider =
    FutureProvider.family<RepairDetail, String>((ref, id) async {
  final (job, parts, history, failure) =
      await ref.read(loadRepairJobUseCaseProvider).call(id);
  if (failure != null) throw failure;
  if (job == null) throw StateError('Repair job not found');
  return RepairDetail(job: job, parts: parts, history: history);
});

final techniciansProvider = FutureProvider<List<Technician>>((ref) async {
  final (techs, failure) =
      await ref.read(loadTechniciansUseCaseProvider).call();
  if (failure != null) throw failure;
  return techs;
});
