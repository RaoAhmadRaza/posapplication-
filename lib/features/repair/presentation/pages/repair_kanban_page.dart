import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/repair_job.dart';
import '../../domain/entities/repair_results.dart';
import '../controllers/repair_jobs_controller.dart';
import '../controllers/repair_detail_provider.dart';
import '../widgets/repair_status_ui.dart';

const _wideBreakpoint = 900.0;

/// Ids of cards selected for a bulk status change (empty = not in select mode).
final _selectedProvider =
    NotifierProvider.autoDispose<_SelectionNotifier, Set<String>>(
        _SelectionNotifier.new);

class _SelectionNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void toggle(String id) => state = {
        for (final e in state)
          if (e != id) e,
        if (!state.contains(id)) id,
      };

  void clear() => state = const {};
}

class RepairKanbanPage extends ConsumerWidget {
  const RepairKanbanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(repairJobsProvider);
    final techs = ref.watch(techniciansProvider).value ?? const <Technician>[];
    final techNames = {for (final t in techs) t.id: t.name};
    final activeTech = ref.watch(repairJobsProvider.notifier).technicianFilter;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        title: Text('Repairs', style: AppTypography.headline),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline, color: AppColors.accent),
            tooltip: 'Technician workload',
            onPressed: () => context.push('/repair/workload'),
          ),
          IconButton(
            icon: const Icon(Icons.history, color: AppColors.accent),
            tooltip: 'History',
            onPressed: () => context.push('/repair/history'),
          ),
          if (techs.isNotEmpty)
            PopupMenuButton<String?>(
              icon: const Icon(Icons.person_search, color: AppColors.accent),
              onSelected: (id) => ref
                  .read(repairJobsProvider.notifier)
                  .setFilters(
                      technicianId: id, clearTechnician: id == null),
              itemBuilder: (_) => [
                const PopupMenuItem(value: null, child: Text('All technicians')),
                for (final t in techs)
                  PopupMenuItem(value: t.id, child: Text(t.name)),
              ],
            ),
        ],
      ),
      bottomNavigationBar: state.maybeWhen(
        data: (jobs) => _BulkBar(jobs: jobs),
        orElse: () => null,
      ),
      floatingActionButton: PermissionGate(
        module: 'repair',
        action: 'create',
        child: FloatingActionButton.extended(
          backgroundColor: AppColors.accent,
          onPressed: () => context.push('/repair/intake'),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('New Job', style: TextStyle(color: Colors.white)),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (activeTech != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                    vertical: AppSpacing.xs),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Filtered by ${techNames[activeTech] ?? "technician"}',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted),
                  ),
                ),
              ),
            Expanded(
              child: state.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorState(
                  onRetry: () =>
                      ref.read(repairJobsProvider.notifier).refresh(),
                ),
                data: (jobs) => jobs.isEmpty
                    ? const _EmptyState()
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= _wideBreakpoint;
                          return wide
                              ? _BoardView(jobs: jobs, techNames: techNames)
                              : _ListView(jobs: jobs, techNames: techNames);
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _changeStatus(
    BuildContext context, WidgetRef ref, RepairJob job, RepairStatus to) async {
  final failure = await ref
      .read(repairJobsProvider.notifier)
      .changeStatus(repairId: job.id, newStatus: to);
  if (!context.mounted) return;
  if (failure != null) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(failure.message)));
  }
}

/// Statuses offered for a bulk change. DELIVERED is excluded — delivery must go
/// through close_repair_job (invoice first); the RPC rejects it anyway.
const _bulkTargetStatuses = [
  RepairStatus.received,
  RepairStatus.diagnosed,
  RepairStatus.awaitingApproval,
  RepairStatus.inRepair,
  RepairStatus.qc,
  RepairStatus.ready,
  RepairStatus.cancelled,
];

Future<void> _applyBulk(
  BuildContext context,
  WidgetRef ref,
  RepairStatus to,
  List<RepairJob> jobs,
) async {
  final ids = ref.read(_selectedProvider).toList();
  if (ids.isEmpty) return;
  final numbersById = {for (final j in jobs) j.id: j.jobNumber};

  final (result, failure) = await ref
      .read(repairJobsProvider.notifier)
      .bulkChangeStatus(repairIds: ids, newStatus: to, notes: 'bulk');
  if (!context.mounted) return;

  if (failure != null) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(failure.message)));
    return;
  }
  ref.read(_selectedProvider.notifier).clear();
  final r = result!;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${r.succeeded} updated to ${repairStatusLabels[to]}'
          '${r.failed.isEmpty ? '' : ', ${r.failed.length} failed'}')));
  if (r.failed.isNotEmpty) {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${r.failed.length} could not be updated'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final f in r.failed)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    '${numbersById[f.repairId] ?? f.repairId}: ${f.error}',
                    style: AppTypography.caption,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close')),
        ],
      ),
    );
  }
}

/// Bottom action bar shown while cards are selected: count + status picker +
/// clear. Gated behind repair:update.
class _BulkBar extends ConsumerWidget {
  const _BulkBar({required this.jobs});
  final List<RepairJob> jobs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(_selectedProvider).length;
    if (count == 0) return const SizedBox.shrink();
    return PermissionGate(
      module: 'repair',
      action: 'update',
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding, vertical: AppSpacing.sm),
          decoration: const BoxDecoration(
            color: AppColors.background,
            border: Border(
                top: BorderSide(color: AppColors.separator, width: 0.5)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textMuted),
                tooltip: 'Clear selection',
                onPressed: () => ref.read(_selectedProvider.notifier).clear(),
              ),
              Text('$count selected', style: AppTypography.subhead),
              const Spacer(),
              PopupMenuButton<RepairStatus>(
                onSelected: (to) => _applyBulk(context, ref, to, jobs),
                itemBuilder: (_) => [
                  for (final s in _bulkTargetStatuses)
                    PopupMenuItem(
                        value: s, child: Text(repairStatusLabels[s]!)),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Change status',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wide layout: horizontal status columns with drag-to-update.
class _BoardView extends ConsumerWidget {
  const _BoardView({required this.jobs, required this.techNames});
  final List<RepairJob> jobs;
  final Map<String, String> techNames;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final status in repairBoardStatuses)
            _Column(
              status: status,
              jobs: jobs.where((j) => j.status == status).toList(),
              techNames: techNames,
              onDropped: (job) => _changeStatus(context, ref, job, status),
            ),
        ],
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.status,
    required this.jobs,
    required this.techNames,
    required this.onDropped,
  });
  final RepairStatus status;
  final List<RepairJob> jobs;
  final Map<String, String> techNames;
  final ValueChanged<RepairJob> onDropped;

  @override
  Widget build(BuildContext context) {
    return DragTarget<RepairJob>(
      onWillAcceptWithDetails: (d) => d.data.status != status,
      onAcceptWithDetails: (d) => onDropped(d.data),
      builder: (context, candidate, _) {
        return Container(
          width: 260,
          margin: const EdgeInsets.only(right: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: candidate.isNotEmpty
                ? AppColors.accent.withValues(alpha: 0.06)
                : AppColors.fieldFill,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: candidate.isNotEmpty
                  ? AppColors.accent
                  : AppColors.separator,
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Row(
                  children: [
                    Text(repairStatusLabels[status]!,
                        style: AppTypography.footnote
                            .copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(width: AppSpacing.xs),
                    Text('${jobs.length}',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
              for (final job in jobs)
                Draggable<RepairJob>(
                  data: job,
                  feedback: Material(
                    color: Colors.transparent,
                    child: SizedBox(
                      width: 244,
                      child: _JobCard(job: job, techNames: techNames),
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.4,
                    child: _JobCard(job: job, techNames: techNames),
                  ),
                  child: _JobCard(job: job, techNames: techNames),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Narrow layout: a flat, tappable list grouped by status header.
class _ListView extends StatelessWidget {
  const _ListView({required this.jobs, required this.techNames});
  final List<RepairJob> jobs;
  final Map<String, String> techNames;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        for (final status in repairBoardStatuses)
          if (jobs.any((j) => j.status == status)) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  RepairStatusBadge(status: status),
                  const SizedBox(width: AppSpacing.sm),
                  Text('${jobs.where((j) => j.status == status).length}',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
            for (final job in jobs.where((j) => j.status == status))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _JobCard(job: job, techNames: techNames),
              ),
          ],
      ],
    );
  }
}

class _JobCard extends ConsumerWidget {
  const _JobCard({required this.job, required this.techNames});
  final RepairJob job;
  final Map<String, String> techNames;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_selectedProvider);
    final isSelected = selected.contains(job.id);
    final selecting = selected.isNotEmpty;
    final device = [job.deviceBrand, job.deviceModel]
        .where((e) => e != null && e.isNotEmpty)
        .join(' ');
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.accent.withValues(alpha: 0.06)
            : AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.separator,
            width: isSelected ? 1 : 0.5),
      ),
      child: InkWell(
        // Long-press to start selecting; tap toggles while selecting, else opens.
        onLongPress: () => ref.read(_selectedProvider.notifier).toggle(job.id),
        onTap: selecting
            ? () => ref.read(_selectedProvider.notifier).toggle(job.id)
            : () => context.push('/repair/${job.id}'),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (selecting)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: isSelected
                            ? AppColors.accent
                            : AppColors.textHint,
                      ),
                    ),
                  Expanded(
                    child: Text(job.jobNumber,
                        style: AppTypography.footnote
                            .copyWith(fontWeight: FontWeight.w700)),
                  ),
                  RepairPriorityChip(priority: job.priority),
                ],
              ),
              const SizedBox(height: 4),
              Text(device.isEmpty ? job.deviceType : device,
                  style: AppTypography.subhead,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              if (job.customerName != null)
                Text(job.customerName!,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              if (job.technicianId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.build_outlined,
                          size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          techNames[job.technicianId] ?? 'Technician',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.build_circle_outlined,
                size: 48, color: AppColors.textHint),
            const SizedBox(height: AppSpacing.md),
            Text('No repair jobs yet',
                style: AppTypography.subhead
                    .copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.xl),
            PermissionGate(
              module: 'repair',
              action: 'create',
              child: AppButton(
                label: 'New Job',
                onPressed: () => context.push('/repair/intake'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppInlineBanner(
                message: 'Could not load repair jobs.',
                type: BannerType.error),
            const SizedBox(height: AppSpacing.md),
            AppButton(label: 'Retry', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
