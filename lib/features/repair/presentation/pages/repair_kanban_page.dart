import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/widgets/module_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../auth/presentation/controllers/permission_controller.dart';
import '../../domain/entities/repair_job.dart';
import '../../domain/entities/repair_results.dart';
import '../controllers/repair_jobs_controller.dart';
import '../controllers/repair_detail_provider.dart';
import '../widgets/repair_job_card.dart';
import '../widgets/repair_sheet.dart';
import '../widgets/repair_states.dart';
import '../widgets/repair_status_ui.dart';

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

/// Board column width when the columns cannot all fit on screen at their
/// comfortable size — the board then scrolls horizontally instead of squeezing.
const _kMinColumnWidth = 268.0;
const _kColumnGap = 12.0;

class RepairKanbanPage extends ConsumerStatefulWidget {
  const RepairKanbanPage({super.key});

  @override
  ConsumerState<RepairKanbanPage> createState() => _RepairKanbanPageState();
}

class _RepairKanbanPageState extends ConsumerState<RepairKanbanPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Client-side filter over the jobs already loaded — no query change.
  List<RepairJob> _filter(List<RepairJob> jobs) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return jobs;
    return [
      for (final j in jobs)
        if ([
          j.jobNumber,
          j.deviceType,
          j.deviceBrand,
          j.deviceModel,
          j.customerName,
          j.imei,
        ].any((f) => f != null && f.toLowerCase().contains(q)))
          j,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(repairJobsProvider);
    final techs = ref.watch(techniciansProvider).value ?? const <Technician>[];
    final techNames = {for (final t in techs) t.id: t.name};
    final activeTech = ref.watch(repairJobsProvider.notifier).technicianFilter;

    return ModuleScaffold(
      title: 'Repair jobs',
      actions: [
        if (techs.isNotEmpty)
          _TechFilterButton(techs: techs, activeTech: activeTech),
      ],
      child: Stack(
        children: [
          Column(
            children: [
              _Toolbar(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
              ),
              if (activeTech != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Filtered by ${techNames[activeTech] ?? "technician"}',
                      style: AppTypography.caption
                          .copyWith(color: context.lum.g500),
                    ),
                  ),
                ),
              Expanded(
                child: state.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => RepairErrorState(
                    title: "We couldn't load repair jobs",
                    body: 'Check your connection and try again. Any jobs you '
                        'created are saved.',
                    onRetry: () =>
                        ref.read(repairJobsProvider.notifier).refresh(),
                  ),
                  data: (jobs) {
                    if (jobs.isEmpty) {
                      return RepairEmptyState(
                        icon: LucideIcons.wrench,
                        title: 'No open repair jobs',
                        body: 'New jobs will show up here as they come in. '
                            'Start one from intake.',
                        action: PermissionGate(
                          module: 'repair',
                          action: 'create',
                          child: AppButton(
                            label: 'Start a repair',
                            icon: LucideIcons.plus,
                            onPressed: () => context.push('/repair/intake'),
                          ),
                        ),
                      );
                    }
                    final visible = _filter(jobs);
                    if (visible.isEmpty) {
                      return const RepairEmptyState(
                        icon: LucideIcons.searchX,
                        title: 'No matching jobs',
                        body: 'Nothing on the board matches that search.',
                      );
                    }
                    return LayoutBuilder(
                      builder: (context, constraints) =>
                          constraints.maxWidth >= kModuleWideBreakpoint
                              ? _BoardView(
                                  jobs: visible,
                                  techNames: techNames,
                                  available: constraints.maxWidth,
                                )
                              : _GroupedListView(
                                  jobs: visible,
                                  techNames: techNames,
                                ),
                    );
                  },
                ),
              ),
            ],
          ),
          state.maybeWhen(
            data: (jobs) => _BulkBar(jobs: jobs),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// Search well plus the New job action. Workload and History are reachable from
/// the module rail / bottom bar, so they are not repeated here.
class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final isWide = ModuleScaffold.isWideOf(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(isWide ? 24 : 14, 16, isWide ? 24 : 14, 6),
      child: Row(
        children: [
          Expanded(
            child: ClayContainer(
              variant: ClayVariant.inset,
              color: lum.surface2,
              borderRadius: AppRadius.md,
              isDark: lum.isDark,
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(LucideIcons.search, size: 18, color: lum.g400),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      onChanged: onChanged,
                      textInputAction: TextInputAction.search,
                      style: AppTypography.fieldText
                          .copyWith(fontSize: 14, color: lum.textPrimary),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Search jobs…',
                        hintStyle: AppTypography.fieldHint
                            .copyWith(fontSize: 14, color: lum.g400),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          PermissionGate(
            module: 'repair',
            action: 'create',
            child: AppButton(
              label: 'New job',
              icon: LucideIcons.plus,
              size: AppButtonSize.sm,
              onPressed: () => context.push('/repair/intake'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TechFilterButton extends ConsumerWidget {
  const _TechFilterButton({required this.techs, required this.activeTech});

  final List<Technician> techs;
  final String? activeTech;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    return Semantics(
      button: true,
      label: 'Filter by technician',
      child: PopupMenuButton<String?>(
        tooltip: 'Filter by technician',
        icon: Icon(
          LucideIcons.userSearch,
          size: 20,
          color: activeTech != null ? lum.accent : lum.g600,
        ),
        onSelected: (id) => ref
            .read(repairJobsProvider.notifier)
            .setFilters(technicianId: id, clearTechnician: id == null),
        itemBuilder: (_) => [
          const PopupMenuItem(value: null, child: Text('All technicians')),
          for (final t in techs)
            PopupMenuItem(value: t.id, child: Text(t.name)),
        ],
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
    await showRepairSheet<void>(
      context: context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RepairSheetHeader(
            title: '${r.failed.length} could not be updated',
            subtitle: 'Everything else moved successfully.',
          ),
          for (final f in r.failed)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                '${numbersById[f.repairId] ?? f.repairId}: ${f.error}',
                style: AppTypography.caption
                    .copyWith(color: context.lum.g600),
              ),
            ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Close',
            variant: AppButtonVariant.tinted,
            fullWidth: true,
            onPressed: () => Navigator.of(sheetContext).pop(),
          ),
        ],
      ),
    );
  }
}

/// Status picker used by a card's Move button and by the bulk bar.
Future<void> _pickStatus(
  BuildContext context,
  WidgetRef ref, {
  RepairJob? job,
  List<RepairJob>? jobs,
}) {
  final lum = context.lum;
  return showRepairSheet<void>(
    context: context,
    width: 400,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RepairSheetHeader(
          title: job == null ? 'Change status' : 'Move job',
          subtitle: job == null
              ? 'Apply a new status to the selected jobs.'
              : '${job.jobNumber} · currently '
                  '${repairStatusLabels[job.status]}',
        ),
        for (final s in _bulkTargetStatuses)
          if (job == null || s != job.status)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  if (job != null) {
                    _changeStatus(context, ref, job, s);
                  } else {
                    _applyBulk(context, ref, s, jobs ?? const []);
                  }
                },
                child: ClayContainer(
                  variant: ClayVariant.inset,
                  color: lum.surface2,
                  borderRadius: AppRadius.md,
                  isDark: lum.isDark,
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: repairStatusColor(context, s),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          repairStatusLabels[s]!,
                          style: AppTypography.label.copyWith(
                            fontSize: 14.5,
                            color: lum.textPrimary,
                          ),
                        ),
                      ),
                      Icon(LucideIcons.arrowRight, size: 16, color: lum.g400),
                    ],
                  ),
                ),
              ),
            ),
      ],
    ),
  );
}

/// Floating ink pill shown while cards are selected. Gated behind repair:update.
class _BulkBar extends ConsumerWidget {
  const _BulkBar({required this.jobs});
  final List<RepairJob> jobs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final count = ref.watch(_selectedProvider).length;
    if (count == 0) return const SizedBox.shrink();

    return Positioned(
      left: 0,
      right: 0,
      bottom: 22,
      child: Center(
        child: PermissionGate(
          module: 'repair',
          action: 'update',
          child: Material(
            color: lum.ink,
            borderRadius: BorderRadius.circular(14),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 12, 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$count selected',
                    style: AppTypography.label.copyWith(color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  _InkAction(
                    label: 'Change status',
                    background: lum.accent,
                    icon: LucideIcons.chevronUp,
                    onTap: () => _pickStatus(context, ref, jobs: jobs),
                  ),
                  const SizedBox(width: 8),
                  _InkAction(
                    label: 'Clear',
                    background: Colors.white.withValues(alpha: 0.12),
                    onTap: () => ref.read(_selectedProvider.notifier).clear(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InkAction extends StatelessWidget {
  const _InkAction({
    required this.label,
    required this.background,
    required this.onTap,
    this.icon,
  });

  final String label;
  final Color background;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTypography.label.copyWith(color: Colors.white),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 5),
                  Icon(icon, size: 15, color: Colors.white),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wide layout: status columns with drag-to-update. Columns share the available
/// width when they fit and scroll horizontally when they do not — the width is
/// derived, never hand-picked.
class _BoardView extends ConsumerWidget {
  const _BoardView({
    required this.jobs,
    required this.techNames,
    required this.available,
  });

  final List<RepairJob> jobs;
  final Map<String, String> techNames;
  final double available;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = repairBoardStatuses.length;
    const horizontalPadding = 24.0 * 2;
    final gaps = _kColumnGap * (count - 1);
    final fitted = (available - horizontalPadding - gaps) / count;
    final columnWidth = fitted >= _kMinColumnWidth ? fitted : _kMinColumnWidth;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: _kColumnGap),
            SizedBox(
              width: columnWidth,
              child: _BoardColumn(
                status: repairBoardStatuses[i],
                jobs: jobs
                    .where((j) => j.status == repairBoardStatuses[i])
                    .toList(),
                techNames: techNames,
                onDropped: (job) =>
                    _changeStatus(context, ref, job, repairBoardStatuses[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BoardColumn extends StatelessWidget {
  const _BoardColumn({
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
    final lum = context.lum;
    return DragTarget<RepairJob>(
      onWillAcceptWithDetails: (d) => d.data.status != status,
      onAcceptWithDetails: (d) => onDropped(d.data),
      builder: (context, candidate, _) {
        final hovering = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: hovering ? lum.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ColumnHeader(status: status, count: jobs.length),
              const SizedBox(height: 10),
              if (jobs.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 18),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: lum.hairline),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    'Nothing here',
                    style: AppTypography.caption
                        .copyWith(fontSize: 12.5, color: lum.g400),
                  ),
                )
              else
                for (final job in jobs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Draggable<RepairJob>(
                      data: job,
                      feedback: Material(
                        color: Colors.transparent,
                        child: SizedBox(
                          width: 256,
                          child: _Card(job: job, techNames: techNames),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.4,
                        child: _Card(job: job, techNames: techNames),
                      ),
                      child: _Card(job: job, techNames: techNames),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({required this.status, required this.count});

  final RepairStatus status;
  final int count;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: repairStatusColor(context, status),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              repairStatusLabels[status]!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label
                  .copyWith(fontSize: 13.5, color: lum.textPrimary),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            decoration: BoxDecoration(
              color: lum.surface2,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              '$count',
              style: AppTypography.monoValue
                  .copyWith(fontSize: 12, color: lum.g500),
            ),
          ),
        ],
      ),
    );
  }
}

/// Narrow layout: a flat list grouped by status header.
class _GroupedListView extends StatelessWidget {
  const _GroupedListView({required this.jobs, required this.techNames});

  final List<RepairJob> jobs;
  final Map<String, String> techNames;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
      children: [
        for (final status in repairBoardStatuses)
          if (jobs.any((j) => j.status == status)) ...[
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 10),
              child: _ColumnHeader(
                status: status,
                count: jobs.where((j) => j.status == status).length,
              ),
            ),
            for (final job in jobs.where((j) => j.status == status))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _Card(job: job, techNames: techNames),
              ),
          ],
      ],
    );
  }
}

/// Board/list card bound to the selection state and the status picker.
class _Card extends ConsumerWidget {
  const _Card({required this.job, required this.techNames});

  final RepairJob job;
  final Map<String, String> techNames;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_selectedProvider);
    final isSelected = selected.contains(job.id);
    final selecting = selected.isNotEmpty;
    // Same matrix PermissionGate reads; the Move affordance is inline on the
    // card, so it is gated by value rather than by wrapping the whole card.
    final canUpdate = (ref.watch(permissionMatrixProvider).value ?? const {})
        .contains('repair:update');

    return RepairJobCard(
      job: job,
      technicianName:
          job.technicianId == null ? null : techNames[job.technicianId],
      selected: isSelected,
      onToggleSelect: () => ref.read(_selectedProvider.notifier).toggle(job.id),
      // While a selection is running, tapping a card extends it rather than
      // navigating away from the board.
      onTap: selecting
          ? () => ref.read(_selectedProvider.notifier).toggle(job.id)
          : () => context.push('/repair/${job.id}'),
      onMove: canUpdate ? () => _pickStatus(context, ref, job: job) : null,
    );
  }
}
