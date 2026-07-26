import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/widgets/module_scaffold.dart';
import '../controllers/repair_jobs_controller.dart';
import '../controllers/repair_reports_provider.dart';
import '../widgets/repair_job_card.dart';
import '../widgets/repair_states.dart';
import '../widgets/repair_status_ui.dart';

class TechnicianWorkloadPage extends ConsumerWidget {
  const TechnicianWorkloadPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(technicianWorkloadProvider);
    final isWide = ModuleScaffold.isWideOf(context);

    return ModuleScaffold(
      title: 'Technician Workload',
      leading: _BackButton(onTap: () => Navigator.of(context).maybePop()),
      maxContentWidth: 900,
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 28 : 14,
        vertical: isWide ? 22 : 14,
      ),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => RepairErrorState(
          title: 'Unable to load workload',
          body: 'The technician figures did not come back. Check the '
              'connection and try again.',
          onRetry: () => ref.invalidate(technicianWorkloadProvider),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return const RepairEmptyState(
              icon: LucideIcons.users,
              title: 'No open jobs',
              body: 'Once jobs are booked in, each technician\'s load shows '
                  'up here.',
            );
          }

          final unassigned = rows.where((r) => r.technician == null).toList();
          final assigned = rows.where((r) => r.technician != null).toList();
          final unassignedCount =
              unassigned.fold<int>(0, (sum, r) => sum + r.total);
          final maxTotal = assigned.fold<int>(
              1, (m, r) => r.total > m ? r.total : m);

          return LayoutBuilder(
            builder: (context, constraints) {
              // Two columns at/above the module breakpoint. The screen width
              // decides (the content box is already capped at 900, so its own
              // width never reaches the breakpoint); the builder supplies the
              // measure the cards are sized against.
              final columns = isWide ? 2 : 1;
              const gap = 12.0;
              final cardWidth = columns == 1
                  ? constraints.maxWidth
                  : (constraints.maxWidth - gap) / 2;

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (unassignedCount > 0) ...[
                      _UnassignedStrip(count: unassignedCount),
                      const SizedBox(height: gap),
                    ],
                    Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final row in assigned)
                          SizedBox(
                            width: cardWidth,
                            child: _WorkloadCard(
                              row: row,
                              maxTotal: maxTotal,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Warning strip for the unassigned bucket. Not tappable — the bucket has no
/// technician filter to push, exactly as before.
class _UnassignedStrip extends StatelessWidget {
  const _UnassignedStrip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final text = '$count ${count == 1 ? 'job' : 'jobs'} unassigned — assign '
        'from the job detail.';
    return Semantics(
      label: text,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: lum.warningSoft,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.userPlus, size: 18, color: lum.warningText),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: AppTypography.subhead.copyWith(
                  fontSize: 13.5,
                  color: lum.warningText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkloadCard extends ConsumerWidget {
  const _WorkloadCard({required this.row, required this.maxTotal});

  final TechnicianWorkload row;

  /// Busiest technician's open count — the progress bar's full width.
  final int maxTotal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final tech = row.technician;
    final name = tech?.name ?? 'Unassigned';

    // Real figures only: open count plus the delivered / turnaround numbers the
    // provider actually carries. TechnicianWorkload has no priority breakdown.
    final subline = [
      '${row.total} open',
      if (row.delivered > 0) '${row.delivered} delivered',
      if (row.avgTurnaroundDays != null)
        'avg ${row.avgTurnaroundDays!.toStringAsFixed(1)}d',
    ].join(' · ');

    return Semantics(
      button: tech != null,
      label: '$name, $subline',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        // Unassigned bucket has no technician filter → not tappable.
        onTap: tech == null
            ? null
            : () {
                ref
                    .read(repairJobsProvider.notifier)
                    .setFilters(technicianId: tech.id);
                context.push('/repair');
              },
        child: ClayContainer(
          variant: ClayVariant.soft,
          color: lum.surface,
          borderRadius: AppRadius.lg,
          isDark: lum.isDark,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  RepairTechAvatar(name: tech?.name, size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.label.copyWith(
                            fontSize: 15,
                            color: lum.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                            color: lum.g500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${row.total}',
                    style: AppTypography.monoValue.copyWith(
                      fontSize: 26,
                      color: lum.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _LoadBar(value: maxTotal == 0 ? 0 : row.total / maxTotal),
              if (row.byStatus.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in row.byStatus.entries)
                      AppPill(
                        label: '${entry.value} '
                            '${repairStatusLabels[entry.key]!.toLowerCase()}',
                        tone: repairStatusTone(entry.key),
                        showDot: false,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 8px rounded track with an accent fill sized to the technician's share of
/// the busiest load.
class _LoadBar extends StatelessWidget {
  const _LoadBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return LayoutBuilder(
      builder: (context, constraints) => Container(
        height: 8,
        decoration: BoxDecoration(
          color: lum.surface2,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        alignment: Alignment.centerLeft,
        child: Container(
          width: constraints.maxWidth * value.clamp(0.0, 1.0),
          height: 8,
          decoration: BoxDecoration(
            color: lum.accent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Semantics(
      button: true,
      label: 'Back',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: SizedBox(
          width: 40,
          height: 44,
          child: Icon(LucideIcons.arrowLeft, size: 20, color: lum.g600),
        ),
      ),
    );
  }
}
