import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/entities/repair_job.dart';
import '../controllers/repair_reports_provider.dart';
import '../widgets/repair_status_ui.dart';

class RepairHistoryPage extends ConsumerStatefulWidget {
  const RepairHistoryPage({super.key});

  @override
  ConsumerState<RepairHistoryPage> createState() => _RepairHistoryPageState();
}

class _RepairHistoryPageState extends ConsumerState<RepairHistoryPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<RepairJob> _filter(List<RepairJob> jobs) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return jobs;
    return jobs.where((j) {
      return j.jobNumber.toLowerCase().contains(q) ||
          (j.customerName?.toLowerCase().contains(q) ?? false) ||
          (j.imei?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(closedRepairJobsProvider);
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
        title: Text('Repair History', style: AppTypography.headline),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding,
                  AppSpacing.sm, AppSpacing.screenPadding, AppSpacing.sm),
              child: AppTextField(
                controller: _searchCtrl,
                label: 'Search',
                prefixIcon: Icons.search,
                hint: 'Job #, customer, or IMEI',
                onSubmitted: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: async.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.screenPadding),
                    child: AppInlineBanner(
                        message: 'Could not load history.',
                        type: BannerType.error),
                  ),
                ),
                data: (jobs) {
                  final filtered = _filter(jobs);
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        jobs.isEmpty
                            ? 'No delivered or cancelled jobs yet.'
                            : 'No matches.',
                        style: AppTypography.footnote
                            .copyWith(color: AppColors.textMuted),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenPadding),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _HistoryRow(job: filtered[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.job});
  final RepairJob job;

  @override
  Widget build(BuildContext context) {
    final device = [job.deviceBrand, job.deviceModel]
        .where((e) => e != null && e.isNotEmpty)
        .join(' ');
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.separator, width: 0.5),
      ),
      child: InkWell(
        onTap: () => context.push('/repair/${job.id}'),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.jobNumber,
                        style: AppTypography.footnote
                            .copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(device.isEmpty ? job.deviceType : device,
                        style: AppTypography.subhead),
                    if (job.customerName != null)
                      Text(job.customerName!,
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
              RepairStatusBadge(status: job.status),
            ],
          ),
        ),
      ),
    );
  }
}
