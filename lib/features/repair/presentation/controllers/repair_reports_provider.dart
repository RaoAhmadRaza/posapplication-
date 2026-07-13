import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/repair_job.dart';
import '../../domain/entities/repair_results.dart';
import '../../domain/usecases/load_repair_jobs.dart';
import '../../domain/usecases/load_closed_repair_jobs.dart';
import '../../domain/usecases/load_technicians.dart';

/// Delivered + cancelled jobs for the history view.
final closedRepairJobsProvider =
    FutureProvider<List<RepairJob>>((ref) async {
  final (jobs, failure) =
      await ref.read(loadClosedRepairJobsUseCaseProvider).call();
  if (failure != null) throw failure;
  return jobs;
});

/// Open-job counts per technician, broken down by status.
class TechnicianWorkload {
  final Technician? technician; // null = unassigned bucket
  final Map<RepairStatus, int> byStatus;
  const TechnicianWorkload({required this.technician, required this.byStatus});

  int get total => byStatus.values.fold(0, (a, b) => a + b);
}

/// Groups open jobs (not delivered/cancelled) by technician → status count.
final technicianWorkloadProvider =
    FutureProvider<List<TechnicianWorkload>>((ref) async {
  final (jobs, jobFailure) =
      await ref.read(loadRepairJobsUseCaseProvider).call();
  if (jobFailure != null) throw jobFailure;
  final (techs, techFailure) =
      await ref.read(loadTechniciansUseCaseProvider).call();
  if (techFailure != null) throw techFailure;

  final techById = {for (final t in techs) t.id: t};
  final open = jobs.where((j) =>
      j.status != RepairStatus.delivered &&
      j.status != RepairStatus.cancelled);

  // Group by technicianId (null bucket for unassigned).
  final buckets = <String?, Map<RepairStatus, int>>{};
  for (final j in open) {
    final b = buckets.putIfAbsent(j.technicianId, () => {});
    b[j.status] = (b[j.status] ?? 0) + 1;
  }

  final result = buckets.entries
      .map((e) => TechnicianWorkload(
            technician: e.key == null ? null : techById[e.key],
            byStatus: e.value,
          ))
      .toList();
  result.sort((a, b) => b.total.compareTo(a.total));
  return result;
});
