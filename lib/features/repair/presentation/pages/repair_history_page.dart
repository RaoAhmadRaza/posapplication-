import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_list_skeleton.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/widgets/module_scaffold.dart';
import '../../domain/entities/repair_job.dart';
import '../controllers/repair_reports_provider.dart';
import '../widgets/repair_states.dart';

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
    final isWide = ModuleScaffold.isWideOf(context);

    return ModuleScaffold(
      title: 'Repair History',
      leading: _BackButton(onTap: () => Navigator.of(context).maybePop()),
      maxContentWidth: 900,
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 28 : 14,
        vertical: isWide ? 22 : 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SearchWell(
            controller: _searchCtrl,
            hint: 'Job #, customer, or IMEI',
            onSubmitted: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: async.when(
              loading: () => const AppListSkeleton(rows: 5, rowHeight: 66),
              error: (e, _) => RepairErrorState(
                title: 'Could not load history',
                body: 'The closed jobs did not come back. Check the '
                    'connection and try again.',
                onRetry: () => ref.invalidate(closedRepairJobsProvider),
              ),
              data: (jobs) {
                final filtered = _filter(jobs);
                if (filtered.isEmpty) {
                  return RepairEmptyState(
                    icon: LucideIcons.history,
                    title: jobs.isEmpty ? 'No closed jobs yet' : 'No matches',
                    body: jobs.isEmpty
                        ? 'Delivered and warranty jobs will be archived here.'
                        : 'Nothing matches that job number, customer or IMEI.',
                  );
                }
                return SingleChildScrollView(
                  child: AppCard(
                    padding: EdgeInsets.zero,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: Column(
                        children: [
                          for (var i = 0; i < filtered.length; i++) ...[
                            _HistoryRow(job: filtered[i], isWide: isWide),
                            if (i != filtered.length - 1)
                              Divider(
                                height: 1,
                                thickness: 1,
                                indent: 16,
                                endIndent: 16,
                                color: context.lum.hairline,
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.job, required this.isWide});

  final RepairJob job;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final device = [job.deviceBrand, job.deviceModel]
        .where((e) => e != null && e.isNotEmpty)
        .join(' ');
    final isWarranty =
        job.isWarrantyClaim || job.status == RepairStatus.warrantyClaim;
    final amount = job.finalCost ?? job.estimatedCost;
    final closedAt = job.deliveredAt;

    return Semantics(
      button: true,
      label: '${job.jobNumber}, ${device.isEmpty ? job.deviceType : device}',
      child: InkWell(
        onTap: () => context.push('/repair/${job.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isWarranty ? lum.transitSoft : lum.g100,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  isWarranty ? LucideIcons.shieldCheck : LucideIcons.circleCheck,
                  size: 18,
                  color: isWarranty ? lum.transitText : lum.g500,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          job.jobNumber,
                          style: AppTypography.monoValue.copyWith(
                            fontSize: 12.5,
                            color: lum.g500,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Flexible(
                          child: Text(
                            device.isEmpty ? job.deviceType : device,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.label.copyWith(
                              fontSize: 14,
                              color: lum.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (job.customerName != null &&
                            job.customerName!.isNotEmpty)
                          job.customerName!,
                        job.reportedIssue,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        color: lum.g600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isWarranty)
                    const AppPill(label: 'Warranty', tone: AppPillTone.transit)
                  else if (amount != null)
                    AppMoneyText(amount, size: 14),
                  if (closedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(closedAt),
                      style: AppTypography.caption.copyWith(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        color: lum.g400,
                      ),
                    ),
                  ],
                ],
              ),
              if (isWide) ...[
                const SizedBox(width: 8),
                Icon(LucideIcons.chevronRight, size: 18, color: lum.g400),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// '12 Mar 2026' — local date only; no intl dependency for one label.
String _formatDate(DateTime d) {
  final local = d.toLocal();
  return '${local.day} ${_months[local.month - 1]} ${local.year}';
}

/// The design's inset search well: 48 high, magnifier, no label.
class _SearchWell extends StatelessWidget {
  const _SearchWell({
    required this.controller,
    required this.hint,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return ClayContainer(
      variant: ClayVariant.inset,
      color: lum.surface2,
      borderRadius: AppRadius.md,
      isDark: lum.isDark,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(LucideIcons.search, size: 18, color: lum.g400),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              textField: true,
              label: 'Search repair history',
              child: TextField(
                controller: controller,
                onSubmitted: onSubmitted,
                textInputAction: TextInputAction.search,
                cursorColor: lum.accent,
                style: AppTypography.fieldText.copyWith(color: lum.textPrimary),
                decoration: InputDecoration(
                  isCollapsed: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: hint,
                  hintStyle: AppTypography.fieldHint
                      .copyWith(color: lum.textTertiary),
                ),
              ),
            ),
          ),
        ],
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
