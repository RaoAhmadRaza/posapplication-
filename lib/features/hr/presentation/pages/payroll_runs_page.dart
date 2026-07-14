import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/payroll.dart';
import '../controllers/payroll_controller.dart';
import '../widgets/hr_status_ui.dart';

class PayrollRunsPage extends ConsumerWidget {
  const PayrollRunsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(payrollRunsProvider);
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
        title: Text('Payroll', style: AppTypography.headline),
      ),
      floatingActionButton: PermissionGate(
        module: 'hr',
        action: 'create',
        child: FloatingActionButton.extended(
          backgroundColor: AppColors.accent,
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text('New Run',
              style: AppTypography.callout
                  .copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
          onPressed: () => _newRun(context, ref),
        ),
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: AppInlineBanner(
                  message: 'Could not load payroll runs.',
                  type: BannerType.error),
            ),
          ),
          data: (runs) {
            if (runs.isEmpty) {
              return Center(
                child: Text('No payroll runs yet.',
                    style: AppTypography.footnote
                        .copyWith(color: AppColors.textMuted)),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
                for (final r in runs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _RunRow(run: r),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _newRun(BuildContext context, WidgetRef ref) async {
    final branch = ref.read(currentBranchProvider);
    if (branch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a branch first.')));
      return;
    }
    final data = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (_) => _NewRunSheet(branchId: branch.id),
    );
    if (data == null || !context.mounted) return;
    final (id, failure) = await ref.read(payrollRunsProvider.notifier).create(data);
    if (!context.mounted) return;
    if (failure != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message)));
      return;
    }
    if (id != null) context.push('/hr/payroll/$id');
  }
}

class _RunRow extends StatelessWidget {
  const _RunRow({required this.run});
  final PayrollRun run;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.separator, width: 0.5),
      ),
      child: InkWell(
        onTap: () => context.push('/hr/payroll/${run.id}'),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(run.period,
                        style: AppTypography.subhead
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                        '${run.employeeCount} employees · net ${formatPkr(run.totalNet)}',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
              HrStatusBadge(
                label: payrollStatusLabels[run.status]!,
                color: payrollStatusColor(run.status),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewRunSheet extends StatefulWidget {
  const _NewRunSheet({required this.branchId});
  final String branchId;

  @override
  State<_NewRunSheet> createState() => _NewRunSheetState();
}

class _NewRunSheetState extends State<_NewRunSheet> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late final _periodCtrl = TextEditingController(text: _periodOf(_month));

  static String _periodOf(DateTime m) =>
      '${m.year}-${m.month.toString().padLeft(2, '0')}';

  DateTime get _start => DateTime(_month.year, _month.month, 1);
  DateTime get _end => DateTime(_month.year, _month.month + 1, 0);

  @override
  void dispose() {
    _periodCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.screenPadding,
        right: AppSpacing.screenPadding,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New Payroll Run', style: AppTypography.headline),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: AppColors.accent),
                onPressed: () => setState(() {
                  _month = DateTime(_month.year, _month.month - 1);
                  _periodCtrl.text = _periodOf(_month);
                }),
              ),
              Expanded(
                child: Text(
                    '${_start.toIso8601String().substring(0, 10)} → '
                    '${_end.toIso8601String().substring(0, 10)}',
                    textAlign: TextAlign.center,
                    style: AppTypography.subhead),
              ),
              IconButton(
                icon:
                    const Icon(Icons.chevron_right, color: AppColors.accent),
                onPressed: () => setState(() {
                  _month = DateTime(_month.year, _month.month + 1);
                  _periodCtrl.text = _periodOf(_month);
                }),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
              controller: _periodCtrl,
              label: 'Period label',
              prefixIcon: Icons.event),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Create',
            fullWidth: true,
            onPressed: () => Navigator.of(context).pop({
              'p_branch_id': widget.branchId,
              'p_period': _periodCtrl.text.trim(),
              'p_start': _start.toIso8601String().substring(0, 10),
              'p_end': _end.toIso8601String().substring(0, 10),
              'p_notes': null,
            }),
          ),
        ],
      ),
    );
  }
}
