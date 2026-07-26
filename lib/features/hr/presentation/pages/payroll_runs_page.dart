import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_filter_chips.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_sheet.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/widgets/module_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/payroll.dart';
import '../controllers/payroll_controller.dart';
import '../widgets/hr_ui.dart';

class PayrollRunsPage extends ConsumerStatefulWidget {
  const PayrollRunsPage({super.key});

  @override
  ConsumerState<PayrollRunsPage> createState() => _PayrollRunsPageState();
}

class _PayrollRunsPageState extends ConsumerState<PayrollRunsPage> {
  PayrollStatus? _status;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(payrollRunsProvider);

    final labels = ['All', for (final s in PayrollStatus.values) payrollStatusLabels[s]!];
    final selected =
        _status == null ? 0 : PayrollStatus.values.indexOf(_status!) + 1;

    return ModuleScaffold(
      title: 'Payroll runs',
      maxContentWidth: 720,
      floatingActionButton: PermissionGate(
        module: 'hr',
        action: 'create',
        child: AppButton(
          label: 'New run',
          icon: LucideIcons.calendarPlus,
          onPressed: () => _newRun(),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
            child: AppFilterChips(
              labels: labels,
              selected: selected,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              onSelected: (i) => setState(
                () => _status = i == 0 ? null : PayrollStatus.values[i - 1],
              ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => AppErrorState(
                title: "Unable to load payroll runs",
                body:
                    "Unable to reach the server. Try again once you're back online.",
                onRetry: () => ref.invalidate(payrollRunsProvider),
              ),
              data: (runs) {
                final list = _status == null
                    ? runs
                    : runs.where((r) => r.status == _status).toList();
                if (list.isEmpty) {
                  return const AppEmptyState(
                    icon: LucideIcons.wallet,
                    title: 'No payroll runs',
                    body:
                        'Start a run to calculate payslips for a pay period.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _RunCard(run: list[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _newRun() async {
    final branch = ref.read(currentBranchProvider);
    if (branch == null) {
      showAppToast(context, 'Select a branch first.', type: BannerType.error);
      return;
    }
    final data = await showAppSheet<Map<String, dynamic>>(
      context: context,
      builder: (_) => _NewRunSheet(branchId: branch.id),
    );
    if (data == null || !mounted) return;
    final (id, failure) =
        await ref.read(payrollRunsProvider.notifier).create(data);
    if (!mounted) return;
    if (failure != null) {
      showAppToast(context, failure.message, type: BannerType.error);
      return;
    }
    if (id != null) context.push('/hr/payroll/$id');
  }
}

class _RunCard extends StatelessWidget {
  const _RunCard({required this.run});
  final PayrollRun run;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final range = '${run.startDate.toIso8601String().substring(0, 10)} → '
        '${run.endDate.toIso8601String().substring(0, 10)}';
    return AppCard(
      onTap: () => context.push('/hr/payroll/${run.id}'),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          ClayContainer(
            variant: ClayVariant.soft,
            color: lum.surface,
            borderRadius: AppRadius.sm,
            isDark: lum.isDark,
            width: 44,
            height: 44,
            child: Icon(LucideIcons.wallet, size: 20, color: lum.g500),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(run.period,
                    style: AppTypography.subhead
                        .copyWith(fontWeight: FontWeight.w600, color: lum.textPrimary)),
                const SizedBox(height: 2),
                Text('$range · ${run.employeeCount} employees',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(color: lum.g500)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppPill(
                label: payrollStatusLabels[run.status]!,
                tone: payrollStatusTone(run.status),
              ),
              const SizedBox(height: 6),
              AppMoneyText(run.totalNet, size: 14),
            ],
          ),
          const SizedBox(width: 6),
          Icon(LucideIcons.chevronRight, size: 18, color: lum.g400),
        ],
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
    final lum = context.lum;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSheetHeader(title: 'New payroll run'),
        Row(
          children: [
            IconButton(
              icon: Icon(LucideIcons.chevronLeft, color: lum.accent),
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
                  style: AppTypography.subhead.copyWith(color: lum.textPrimary)),
            ),
            IconButton(
              icon: Icon(LucideIcons.chevronRight, color: lum.accent),
              onPressed: () => setState(() {
                _month = DateTime(_month.year, _month.month + 1);
                _periodCtrl.text = _periodOf(_month);
              }),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppTextField(
            controller: _periodCtrl,
            label: 'Period label',
            prefixIcon: Icons.event),
        const SizedBox(height: 20),
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
    );
  }
}
