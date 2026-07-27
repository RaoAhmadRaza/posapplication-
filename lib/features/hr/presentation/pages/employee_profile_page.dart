import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_filter_chips.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_section_card.dart';
import '../../../../core/design/widgets/app_sheet.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/attendance.dart';
import '../../domain/entities/employee.dart';
import '../../domain/entities/salary_advance.dart';
import '../controllers/advances_controller.dart';
import '../controllers/attendance_controller.dart';
import '../controllers/employees_controller.dart';
import '../controllers/leaves_controller.dart';
import '../widgets/hr_ui.dart';
import '../widgets/leave_request_card.dart';
import 'attendance_grid_page.dart' show showMarkAttendanceSheet;
import 'leaves_page.dart' show showApplyLeaveSheet;
import 'salary_advance_sheet.dart' show showGiveAdvanceSheet;

class EmployeeProfilePage extends ConsumerStatefulWidget {
  const EmployeeProfilePage({super.key, required this.employeeId});
  final String employeeId;

  @override
  ConsumerState<EmployeeProfilePage> createState() =>
      _EmployeeProfilePageState();
}

class _EmployeeProfilePageState extends ConsumerState<EmployeeProfilePage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(employeeDetailProvider(widget.employeeId));

    Widget shell(String title, Widget child) => AppDetailScaffold(
          eyebrow: 'HR · Employees',
          title: title,
          child: child,
        );

    return async.when(
      loading: () => shell(
        'Employee',
        const SizedBox(
          height: 220,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => shell(
        'Employee',
        const AppErrorState(
          title: 'Unable to load this profile',
          body: 'Check your connection and try again.',
        ),
      ),
      data: (employee) => shell(
        employee.name,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _IdentityCard(employee: employee),
            const SizedBox(height: AppSpacing.lg),
            AppFilterChips(
              labels: const ['Profile', 'Attendance', 'Leaves', 'Payroll'],
              selected: _tab,
              onSelected: (i) => setState(() => _tab = i),
            ),
            const SizedBox(height: AppSpacing.lg),
            switch (_tab) {
              0 => _ProfileTab(employee: employee),
              1 => _AttendanceTab(employee: employee),
              2 => _LeavesTab(employee: employee),
              _ => _PayrollTab(employee: employee),
            },
          ],
        ),
      ),
    );
  }
}

// ── Header identity card ──────────────────────────────────────────────────────

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.employee});
  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final subtitle = '${employee.designation ?? '—'} · '
        '${employee.department ?? '—'} · ';
    final (loginLabel, loginTone) = employeeLoginUi(employee.userId);

    return AppCard(
      raised: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClayContainer(
                variant: ClayVariant.lumen,
                color: lum.accent,
                borderRadius: 20,
                isDark: lum.isDark,
                width: 64,
                height: 64,
                child: Center(
                  child: Text(
                    hrInitials(employee.name),
                    style: AppTypography.title2.copyWith(
                      color: Colors.white,
                      fontSize: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(employee.name, style: AppTypography.title2),
                    const SizedBox(height: 3),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          subtitle,
                          style: AppTypography.footnote
                              .copyWith(color: lum.textSecondary),
                        ),
                        Text(
                          employee.employeeCode,
                          style: AppTypography.monoValue.copyWith(
                            fontSize: 12,
                            color: lum.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        AppPill(
                          label: employeeStatusLabels[employee.status]!,
                          tone: employeeStatusTone(employee.status),
                        ),
                        // Both states here, unlike the list: this is the screen
                        // offering "Create login", so "No login" is the cue for
                        // it rather than noise.
                        AppPill(
                          label: loginLabel,
                          tone: loginTone,
                          showDot: false,
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppMoneyText(employee.baseSalary, size: 15),
                            const SizedBox(width: 4),
                            Text(
                              salaryUnitLabels[employee.salaryType]!,
                              style: AppTypography.caption
                                  .copyWith(color: lum.g500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              PermissionGate(
                module: 'hr',
                action: 'update',
                child: AppButton(
                  label: 'Edit',
                  icon: LucideIcons.pencil,
                  variant: AppButtonVariant.tinted,
                  size: AppButtonSize.sm,
                  onPressed: () => context.push(
                    '/hr/employees/${employee.id}/edit',
                    extra: employee,
                  ),
                ),
              ),
              if (employee.userId == null)
                PermissionGate(
                  module: 'users',
                  action: 'create',
                  child: AppButton(
                    label: 'Create login',
                    icon: LucideIcons.userPlus,
                    variant: AppButtonVariant.plain,
                    size: AppButtonSize.sm,
                    onPressed: () => context.push('/staff/invite', extra: {
                      'employeeId': employee.id,
                      'name': employee.name,
                      'email': employee.email,
                    }),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Profile tab ───────────────────────────────────────────────────────────────

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab({required this.employee});
  final Employee employee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasBank =
        employee.bankName != null || employee.bankAccountNumber != null;
    final hasNotes = employee.notes != null && employee.notes!.isNotEmpty;

    final cards = <Widget>[
      AppSectionCard(
        eyebrow: 'Employment',
        child: _InfoRows(rows: [
          ('Designation', employee.designation ?? '—'),
          ('Department', employee.department ?? '—'),
          ('Branch', employee.branchName ?? '—'),
          ('Joined', employee.joiningDate.toIso8601String().substring(0, 10)),
          if (employee.terminationDate != null)
            ('Ended',
                employee.terminationDate!.toIso8601String().substring(0, 10)),
        ]),
      ),
      AppSectionCard(
        eyebrow: 'Contact',
        child: _InfoRows(rows: [
          ('Phone', employee.phone ?? '—'),
          ('Email', employee.email ?? '—'),
          ('CNIC', employee.cnic ?? '—'),
          ('Address', employee.address ?? '—'),
        ]),
      ),
      AppSectionCard(
        eyebrow: 'Salary & bank',
        child: _InfoRows(
          rows: [
            ('Type', salaryTypeLabels[employee.salaryType]!),
            if (hasBank) ('Bank', employee.bankName ?? '—'),
            if (hasBank) ('Account', employee.bankAccountNumber ?? '—'),
          ],
          leading: _InfoMoneyRow(
            label: 'Base',
            value: employee.baseSalary,
          ),
        ),
      ),
      if (hasNotes)
        AppSectionCard(
          eyebrow: 'Notes',
          child: Text(
            employee.notes!,
            style: AppTypography.footnote.copyWith(height: 1.55),
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final twoCol = constraints.maxWidth >= 620;
            final width =
                twoCol ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final card in cards) SizedBox(width: width, child: card),
              ],
            );
          },
        ),
        if (employee.status != EmployeeStatus.terminated &&
            employee.status != EmployeeStatus.resigned)
          PermissionGate(
            module: 'hr',
            action: 'update',
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.lg),
              child: AppButton(
                label: 'Terminate / resign',
                icon: LucideIcons.userRoundX,
                variant: AppButtonVariant.destructive,
                fullWidth: true,
                onPressed: () => _terminate(context, ref, employee),
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  Future<void> _terminate(
      BuildContext context, WidgetRef ref, Employee employee) async {
    final result = await showAppSheet<_TerminateResult>(
      context: context,
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
    showAppToast(
      context,
      failure?.message ??
          '${employee.name} marked ${employeeStatusLabels[result.status]}',
      type: failure != null ? BannerType.error : BannerType.success,
    );
  }
}

/// Label/value rows with hairline dividers for a section card.
class _InfoRows extends StatelessWidget {
  const _InfoRows({required this.rows, this.leading});
  final List<(String, String)> rows;

  /// Optional first row that renders a money value (e.g. Base salary).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final children = <Widget>[];
    if (leading != null) children.add(leading!);
    for (final (k, v) in rows) {
      children.add(_InfoRow(label: k, value: v));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            Divider(height: 1, thickness: 0.5, color: lum.hairline),
          children[i],
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  AppTypography.footnote.copyWith(color: lum.textSecondary)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTypography.footnote
                  .copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoMoneyRow extends StatelessWidget {
  const _InfoMoneyRow({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Text(label,
              style:
                  AppTypography.footnote.copyWith(color: lum.textSecondary)),
          const Spacer(),
          AppMoneyText(value, size: 15),
        ],
      ),
    );
  }
}

// ── Terminate sheet ───────────────────────────────────────────────────────────

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
  static const _statuses = [
    EmployeeStatus.terminated,
    EmployeeStatus.resigned,
  ];
  int _statusIndex = 0;
  DateTime _date = DateTime.now();
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSheetHeader(
          title: 'End employment',
          subtitle: widget.employee.name,
        ),
        AppFilterChips(
          labels: [for (final s in _statuses) employeeStatusLabels[s]!],
          selected: _statusIndex,
          onSelected: (i) => setState(() => _statusIndex = i),
        ),
        const SizedBox(height: AppSpacing.base),
        Text('End date', style: AppTypography.fieldLabel.copyWith(color: lum.g700)),
        const SizedBox(height: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _pickDate,
          child: ClayContainer(
            variant: ClayVariant.inset,
            color: lum.surface2,
            borderRadius: AppRadius.md,
            isDark: lum.isDark,
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(LucideIcons.calendar, size: 18, color: lum.g400),
                const SizedBox(width: 10),
                Text(
                  _date.toIso8601String().substring(0, 10),
                  style: AppTypography.fieldText.copyWith(color: lum.textPrimary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.base),
        AppTextField(
          controller: _notesCtrl,
          label: 'Notes (optional)',
          prefixIcon: Icons.notes,
          maxLines: 3,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Confirm',
          variant: AppButtonVariant.destructive,
          fullWidth: true,
          onPressed: () => Navigator.of(context).pop(
            _TerminateResult(
              _statuses[_statusIndex],
              _date,
              _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Attendance tab ────────────────────────────────────────────────────────────

class _AttendanceTab extends ConsumerWidget {
  const _AttendanceTab({required this.employee});
  final Employee employee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final now = DateTime.now();
    final query = (year: now.year, month: now.month, employeeId: employee.id);
    final async = ref.watch(attendanceMonthProvider(query));

    Future<void> mark(DateTime date, Attendance? existing) =>
        showMarkAttendanceSheet(
          context: context,
          employee: employee,
          date: date,
          existing: existing,
          invalidateQuery: query,
        );

    return async.when(
      loading: () => const _TabLoading(),
      error: (e, _) => const AppErrorState(
        title: 'Unable to load attendance',
        body: 'Attendance for this month is unavailable right now.',
      ),
      data: (rows) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('This month',
                    style: AppTypography.headline
                        .copyWith(color: lum.textPrimary)),
              ),
              AppButton(
                label: 'Mark a day',
                icon: LucideIcons.calendarPlus,
                variant: AppButtonVariant.tinted,
                size: AppButtonSize.sm,
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: now,
                    firstDate: DateTime(now.year, now.month, 1),
                    lastDate: DateTime(now.year, now.month + 1, 0),
                  );
                  if (picked == null) return;
                  Attendance? existing;
                  for (final a in rows) {
                    if (a.date.day == picked.day) {
                      existing = a;
                      break;
                    }
                  }
                  await mark(picked, existing);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          if (rows.isEmpty)
            const AppEmptyState(
              icon: LucideIcons.calendarCheck,
              title: 'No attendance yet',
              body: 'No days have been marked for this employee this month.',
            )
          else
            for (final a in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _AttendanceRow(
                  attendance: a,
                  onTap: () => mark(a.date, a),
                ),
              ),
        ],
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({required this.attendance, required this.onTap});
  final Attendance attendance;
  final VoidCallback onTap;

  String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final a = attendance;
    final (bg, fg) = attendanceCellColors(context, a.status);
    final extras = <String>[
      if (a.lateMinutes > 0) 'late ${a.lateMinutes}m',
      if (a.overtimeHours > 0) 'OT ${a.overtimeHours}h',
    ];
    final subtitle = [attendanceStatusLabels[a.status]!, ...extras].join(' · ');

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              attendanceStatusShort[a.status]!,
              style: AppTypography.monoValue.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.date.toIso8601String().substring(0, 10),
                  style: AppTypography.subhead
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: AppTypography.caption
                        .copyWith(color: lum.textSecondary)),
              ],
            ),
          ),
          if (a.checkIn != null || a.checkOut != null)
            Text(
              '${a.checkIn != null ? _hm(a.checkIn!) : '—'} – '
              '${a.checkOut != null ? _hm(a.checkOut!) : '—'}',
              style: AppTypography.monoValue
                  .copyWith(fontSize: 12.5, color: lum.textSecondary),
            ),
        ],
      ),
    );
  }
}

// ── Leaves tab ────────────────────────────────────────────────────────────────

class _LeavesTab extends ConsumerWidget {
  const _LeavesTab({required this.employee});
  final Employee employee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = (employeeId: employee.id, status: null);
    final async = ref.watch(leavesProvider(query));
    return async.when(
      loading: () => const _TabLoading(),
      error: (e, _) => const AppErrorState(
        title: 'Unable to load leaves',
        body: 'Leave history is unavailable right now.',
      ),
      data: (leaves) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PermissionGate(
            module: 'hr',
            action: 'create',
            child: Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                label: 'Apply leave',
                icon: LucideIcons.plus,
                variant: AppButtonVariant.tinted,
                size: AppButtonSize.sm,
                onPressed: () => showApplyLeaveSheet(
                    context: context,
                    employeeId: employee.id,
                    invalidateQuery: query),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          if (leaves.isEmpty)
            const AppEmptyState(
              icon: LucideIcons.plane,
              title: 'No leaves',
              body: 'This employee has no leave requests on record.',
            )
          else
            for (final l in leaves)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: LeaveRequestCard(leave: l, invalidateQuery: query),
              ),
        ],
      ),
    );
  }
}

// ── Payroll tab ───────────────────────────────────────────────────────────────

class _PayrollTab extends ConsumerWidget {
  const _PayrollTab({required this.employee});
  final Employee employee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(employeeAdvancesProvider(employee.id));
    return async.when(
      loading: () => const _TabLoading(),
      error: (e, _) => const AppErrorState(
        title: 'Unable to load advances',
        body: 'Salary advances are unavailable right now.',
      ),
      data: (advances) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PermissionGate(
            module: 'hr',
            action: 'approve',
            child: Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                label: 'Give advance',
                icon: LucideIcons.handCoins,
                variant: AppButtonVariant.tinted,
                size: AppButtonSize.sm,
                onPressed: () => showGiveAdvanceSheet(
                    context: context, employeeId: employee.id),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          if (advances.isEmpty)
            const AppEmptyState(
              icon: LucideIcons.wallet,
              title: 'No advances',
              body: 'This employee has no salary advances on record.',
            )
          else
            for (final a in advances)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _AdvanceCard(advance: a),
              ),
        ],
      ),
    );
  }
}

class _AdvanceCard extends StatelessWidget {
  const _AdvanceCard({required this.advance});
  final SalaryAdvance advance;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final a = advance;
    final recovered = a.amount - a.balance;
    final fraction =
        a.amount <= 0 ? 0.0 : (recovered / a.amount).clamp(0.0, 1.0);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: AppMoneyText(a.amount, size: 17)),
              AppPill(
                label: a.isFullyRecovered ? 'Recovered' : 'Active',
                tone:
                    a.isFullyRecovered ? AppPillTone.success : AppPillTone.warning,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Given ${a.disbursedAt.toIso8601String().substring(0, 10)} · '
            '${formatPkr(recovered)} recovered · '
            '${formatPkr(a.recoveryAmount)} per run',
            style: AppTypography.caption.copyWith(color: lum.textSecondary),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: lum.surface2,
              valueColor: AlwaysStoppedAnimation(lum.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabLoading extends StatelessWidget {
  const _TabLoading();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
}
