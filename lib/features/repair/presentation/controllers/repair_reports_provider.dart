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

/// Per-technician workload + performance: open counts by status, delivered
/// total, and average turnaround (received→delivered) in days.
class TechnicianWorkload {
  final Technician? technician; // null = unassigned bucket
  final Map<RepairStatus, int> byStatus;
  final int delivered;
  final double? avgTurnaroundDays; // null when nothing delivered with timestamps
  const TechnicianWorkload({
    required this.technician,
    required this.byStatus,
    this.delivered = 0,
    this.avgTurnaroundDays,
  });

  int get total => byStatus.values.fold(0, (a, b) => a + b);
}

/// Groups jobs by technician: open jobs → status counts (workload), delivered
/// jobs → count + avg turnaround (performance). A tech with only delivered jobs
/// still appears. Cancelled jobs are excluded from both.
final technicianWorkloadProvider =
    FutureProvider<List<TechnicianWorkload>>((ref) async {
  final (jobs, jobFailure) =
      await ref.read(loadRepairJobsUseCaseProvider).call();
  if (jobFailure != null) throw jobFailure;
  final (techs, techFailure) =
      await ref.read(loadTechniciansUseCaseProvider).call();
  if (techFailure != null) throw techFailure;

  final techById = {for (final t in techs) t.id: t};

  // Open-job status counts per technician (null bucket = unassigned).
  final buckets = <String?, Map<RepairStatus, int>>{};
  // Delivered turnaround samples (days) per technician.
  final turnaround = <String?, List<double>>{};

  for (final j in jobs) {
    if (j.status == RepairStatus.cancelled) continue;
    if (j.status == RepairStatus.delivered) {
      if (j.deliveredAt != null) {
        final days =
            j.deliveredAt!.difference(j.receivedAt).inMinutes / 1440.0;
        turnaround.putIfAbsent(j.technicianId, () => []).add(days);
      }
      continue;
    }
    final b = buckets.putIfAbsent(j.technicianId, () => {});
    b[j.status] = (b[j.status] ?? 0) + 1;
  }

  final keys = <String?>{...buckets.keys, ...turnaround.keys};
  final result = keys.map((k) {
    final samples = turnaround[k];
    final avg = (samples == null || samples.isEmpty)
        ? null
        : samples.reduce((a, b) => a + b) / samples.length;
    return TechnicianWorkload(
      technician: k == null ? null : techById[k],
      byStatus: buckets[k] ?? const {},
      delivered: samples?.length ?? 0,
      avgTurnaroundDays: avg,
    );
  }).toList();
  result.sort((a, b) {
    final byOpen = b.total.compareTo(a.total);
    return byOpen != 0 ? byOpen : b.delivered.compareTo(a.delivered);
  });
  return result;
});
