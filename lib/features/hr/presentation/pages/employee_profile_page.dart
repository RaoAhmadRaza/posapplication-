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
import '../../domain/entities/employee.dart';
import '../controllers/employees_controller.dart';
import '../widgets/hr_status_ui.dart';

class EmployeeProfilePage extends ConsumerWidget {
  const EmployeeProfilePage({super.key, required this.employeeId});
  final String employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(employeeDetailProvider(employeeId));
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: AppColors.background,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                color: AppColors.accent, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text('Employee', style: AppTypography.headline),
          bottom: TabBar(
            labelColor: AppColors.accent,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.accent,
            labelStyle: AppTypography.footnote
                .copyWith(fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Profile'),
              Tab(text: 'Attendance'),
              Tab(text: 'Leaves'),
              Tab(text: 'Payroll'),
            ],
          ),
        ),
        body: SafeArea(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: AppInlineBanner(
                    message: 'Could not load employee.',
                    type: BannerType.error),
              ),
            ),
            data: (employee) => TabBarView(
              children: [
                _ProfileTab(employee: employee),
                const _ComingSoon(label: 'Attendance'),
                const _ComingSoon(label: 'Leaves'),
                const _ComingSoon(label: 'Payroll history'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab({required this.employee});
  final Employee employee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(employee.name, style: AppTypography.title2),
                  const SizedBox(height: 2),
                  Text(employee.employeeCode,
                      style: AppTypography.footnote
                          .copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
            EmployeeStatusBadge(status: employee.status),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _Section(title: 'Employment', rows: [
          ('Designation', employee.designation ?? '—'),
          ('Department', employee.department ?? '—'),
          ('Branch', employee.branchName ?? '—'),
          ('Joined', employee.joiningDate.toIso8601String().substring(0, 10)),
          if (employee.terminationDate != null)
            ('Ended',
                employee.terminationDate!.toIso8601String().substring(0, 10)),
        ]),
        _Section(title: 'Salary', rows: [
          ('Type', salaryTypeLabels[employee.salaryType]!),
          ('Base salary', formatPkr(employee.baseSalary)),
        ]),
        _Section(title: 'Contact', rows: [
          ('Phone', employee.phone ?? '—'),
          ('Email', employee.email ?? '—'),
          ('CNIC', employee.cnic ?? '—'),
          ('Address', employee.address ?? '—'),
        ]),
        if (employee.bankName != null || employee.bankAccountNumber != null)
          _Section(title: 'Bank', rows: [
            ('Bank', employee.bankName ?? '—'),
            ('Account', employee.bankAccountNumber ?? '—'),
          ]),
        if (employee.notes != null && employee.notes!.isNotEmpty)
          _Section(title: 'Notes', rows: [('', employee.notes!)]),
        const SizedBox(height: AppSpacing.lg),
        PermissionGate(
          module: 'hr',
          action: 'update',
          child: Column(
            children: [
              AppButton(
                label: 'Edit',
                icon: Icons.edit_outlined,
                variant: AppButtonVariant.tinted,
                fullWidth: true,
                onPressed: () => context.push(
                    '/hr/employees/${employee.id}/edit',
                    extra: employee),
              ),
              if (employee.status != EmployeeStatus.terminated &&
                  employee.status != EmployeeStatus.resigned) ...[
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Terminate / Resign',
                  variant: AppButtonVariant.destructive,
                  fullWidth: true,
                  onPressed: () => _terminate(context, ref, employee),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  Future<void> _terminate(
      BuildContext context, WidgetRef ref, Employee employee) async {
    final result = await showModalBottomSheet<_TerminateResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (_) => _TerminateSheet(employee: employee),
    );
    if (result == null || !context.mounted) return;
    final failure = await ref.read(employeesProvider.notifier).terminate(
          employeeId: employee.id,
          status: result.status,
          terminationDate: result.date,
          notes: result.notes,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(failure?.message ??
          '${employee.name} marked ${employeeStatusLabels[result.status]}'),
    ));
  }
}

class _TerminateResult {
  const _TerminateResult(this.status, this.date, this.notes);
  final EmployeeStatus status;
  final DateTime date;
  final String? notes;
}

class _TerminateSheet extends StatefulWidget {
  const _TerminateSheet({required this.employee});
  final Employee employee;

  @override
  State<_TerminateSheet> createState() => _TerminateSheetState();
}

class _TerminateSheetState extends State<_TerminateSheet> {
  EmployeeStatus _status = EmployeeStatus.terminated;
  DateTime _date = DateTime.now();
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _notesCtrl.dispose();
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
          Text('End Employment', style: AppTypography.headline),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final s in [
                EmployeeStatus.terminated,
                EmployeeStatus.resigned
              ])
                ChoiceChip(
                  label: Text(employeeStatusLabels[s]!),
                  selected: _status == s,
                  onSelected: (_) => setState(() => _status = s),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _date = picked);
            },
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.fieldFill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined,
                    color: AppColors.textMuted, size: 20),
                const SizedBox(width: 10),
                Text(_date.toIso8601String().substring(0, 10),
                    style: AppTypography.fieldText),
              ]),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
              controller: _notesCtrl,
              label: 'Notes (optional)',
              prefixIcon: Icons.notes),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Confirm',
            variant: AppButtonVariant.destructive,
            fullWidth: true,
            onPressed: () => Navigator.of(context).pop(_TerminateResult(
                _status,
                _date,
                _notesCtrl.text.trim().isEmpty
                    ? null
                    : _notesCtrl.text.trim())),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});
  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.separator, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          for (final (k, v) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (k.isNotEmpty)
                    SizedBox(
                      width: 110,
                      child: Text(k,
                          style: AppTypography.footnote
                              .copyWith(color: AppColors.textMuted)),
                    ),
                  Expanded(
                    child: Text(v, style: AppTypography.footnote),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('$label — coming soon',
          style:
              AppTypography.footnote.copyWith(color: AppColors.textMuted)),
    );
  }
}
