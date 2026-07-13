import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/repair_job.dart';
import '../../domain/entities/repair_part.dart';
import '../../domain/entities/repair_status_history.dart';
import '../../domain/entities/repair_results.dart';
import '../../domain/usecases/load_repair_job.dart';
import '../../domain/usecases/load_repair_links.dart';
import '../../domain/usecases/load_technicians.dart';

/// Full detail bundle for one repair job.
class RepairDetail {
  final RepairJob job;
  final List<RepairPart> parts;
  final List<RepairStatusHistory> history;

  /// The original job this is a warranty claim of (null unless this is a claim).
  final RepairLink? original;

  /// Warranty claims raised against this job (empty if none).
  final List<RepairLink> claims;

  const RepairDetail({
    required this.job,
    required this.parts,
    required this.history,
    this.original,
    this.claims = const [],
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

  // Warranty linkage: parent (id == originalRepairId) + child claims.
  final (links, _) = await ref
      .read(loadRepairLinksUseCaseProvider)
      .call(id, job.originalRepairId);
  RepairLink? original;
  final claims = <RepairLink>[];
  for (final l in links) {
    if (l.id == job.originalRepairId) {
      original = l;
    } else {
      claims.add(l);
    }
  }

  return RepairDetail(
    job: job,
    parts: parts,
    history: history,
    original: original,
    claims: claims,
  );
});

final techniciansProvider = FutureProvider<List<Technician>>((ref) async {
  final (techs, failure) =
      await ref.read(loadTechniciansUseCaseProvider).call();
  if (failure != null) throw failure;
  return techs;
});
