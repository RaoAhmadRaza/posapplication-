import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../domain/entities/repair_job.dart';
import '../controllers/repair_jobs_controller.dart';
import '../controllers/repair_reports_provider.dart';
import '../widgets/repair_status_ui.dart';

class TechnicianWorkloadPage extends ConsumerWidget {
  const TechnicianWorkloadPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(technicianWorkloadProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Technician Workload', style: AppTypography.headline),
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: AppInlineBanner(
                  message: 'Could not load workload.',
                  type: BannerType.error),
            ),
          ),
          data: (rows) {
            if (rows.isEmpty) {
              return Center(
                child: Text('No open jobs.',
                    style: AppTypography.footnote
                        .copyWith(color: AppColors.textMuted)),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              itemCount: rows.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _WorkloadCard(row: rows[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WorkloadCard extends ConsumerWidget {
  const _WorkloadCard({required this.row});
  final TechnicianWorkload row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tech = row.technician;
    return AppCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        // Unassigned bucket has no technician filter → not tappable.
        onTap: tech == null
            ? null
            : () {
                ref
                    .read(repairJobsProvider.notifier)
                    .setFilters(technicianId: tech.id);
                context.push('/repair');
              },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(tech == null ? Icons.person_off_outlined : Icons.build,
                      size: 18, color: AppColors.textMuted),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(tech?.name ?? 'Unassigned',
                        style: AppTypography.headline),
                  ),
                  Text('${row.total} open',
                      style: AppTypography.footnote
                          .copyWith(color: AppColors.accent)),
                  if (tech != null)
                    const Padding(
                      padding: EdgeInsets.only(left: AppSpacing.xs),
                      child: Icon(Icons.chevron_right,
                          size: 18, color: AppColors.separator),
                    ),
                ],
              ),
              if (row.byStatus.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final entry in row.byStatus.entries)
                      _StatusCount(status: entry.key, count: entry.value),
                  ],
                ),
              ],
              if (row.delivered > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 14, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text('${row.delivered} delivered',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textMuted)),
                    if (row.avgTurnaroundDays != null) ...[
                      const SizedBox(width: AppSpacing.md),
                      const Icon(Icons.schedule,
                          size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                          'avg ${row.avgTurnaroundDays!.toStringAsFixed(1)}d',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textMuted)),
                    ],
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

class _StatusCount extends StatelessWidget {
  const _StatusCount({required this.status, required this.count});
  final RepairStatus status;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = repairStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('${repairStatusLabels[status]!} $count',
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
