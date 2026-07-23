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
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_dropdown.dart';
import '../../../../core/design/widgets/app_filter_chips.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_sheet.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/widgets/module_scaffold.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/attendance.dart';
import '../../domain/entities/employee.dart';
import '../../domain/entities/shift.dart';
import '../../data/models/attendance_model.dart';
import '../controllers/attendance_controller.dart';
import '../controllers/shifts_controller.dart';
import '../widgets/hr_ui.dart';

/// Monthly attendance matrix. Fixed cell geometry drives the whole grid: a
/// square [_kCell] tile per employee-day, a [_kDayHead]-tall day-number row and
/// a sticky [_kNameCol]-wide employee column. Nothing is a hand-picked ratio.
const double _kCell = 30.0;
const double _kCellGap = 4.0;
const double _kDayHead = 24.0;
const double _kNameCol = 150.0;

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

class AttendanceGridPage extends ConsumerStatefulWidget {
  const AttendanceGridPage({super.key});

  @override
  ConsumerState<AttendanceGridPage> createState() =>
      _AttendanceGridPageState();
}

class _AttendanceGridPageState extends ConsumerState<AttendanceGridPage> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String? _branchId;

  @override
  Widget build(BuildContext context) {
    final currentBranch = ref.watch(currentBranchProvider);
    final branchId = _branchId ?? currentBranch?.id;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final pad = ModuleScaffold.isWideOf(context) ? 32.0 : 16.0;

    return ModuleScaffold(
      title: 'Attendance',
      maxContentWidth: 1120,
      actions: [
        _MonthPager(
          month: _month,
          onPrev: () => setState(
              () => _month = DateTime(_month.year, _month.month - 1)),
          onNext: () => setState(
              () => _month = DateTime(_month.year, _month.month + 1)),
        ),
        const SizedBox(width: 8),
        AppButton(
          label: 'Clock',
          icon: LucideIcons.fingerprint,
          variant: AppButtonVariant.tinted,
          size: AppButtonSize.sm,
          onPressed: () => context.go('/hr/clock'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(pad, 14, pad, 4),
            child: const _StatusLegend(),
          ),
          Expanded(
            child: branchId == null
                ? const _CenteredState(
                    icon: LucideIcons.building2,
                    title: 'No branch selected',
                    body: 'Pick a branch to see its attendance grid.',
                  )
                : _grid(branchId, days, pad),
          ),
        ],
      ),
    );
  }

  Widget _grid(String branchId, int days, double pad) {
    final employeesAsync = ref.watch(branchEmployeesProvider(branchId));
    final query =
        (year: _month.year, month: _month.month, employeeId: null);
    final attendanceAsync = ref.watch(attendanceMonthProvider(query));

    return employeesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const _CenteredState(
        icon: LucideIcons.cloudOff,
        title: "Couldn't load employees",
        body: 'Something went wrong reaching the server. Try again in a moment.',
      ),
      data: (employees) => attendanceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const _CenteredState(
          icon: LucideIcons.cloudOff,
          title: "Couldn't load attendance",
          body:
              'Something went wrong reaching the server. Try again in a moment.',
        ),
        data: (rows) {
          if (employees.isEmpty) {
            return const _CenteredState(
              icon: LucideIcons.users,
              title: 'No employees',
              body: 'This branch has no employees to track yet.',
            );
          }
          // pivot: employeeId → day → attendance
          final byEmp = <String, Map<int, Attendance>>{};
          for (final a in rows) {
            byEmp.putIfAbsent(a.employeeId, () => {})[a.date.day] = a;
          }
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(pad, 6, pad, pad),
            child: AppCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sticky left employee column — stays put while the day
                  // matrix scrolls horizontally beside it.
                  _EmployeeColumn(employees: employees),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _DayHeaderRow(days: days),
                          for (final e in employees)
                            _DayCellsRow(
                              days: days,
                              byDay: byEmp[e.id] ?? const {},
                              onTapDay: (d) =>
                                  _openSheet(e, d, (byEmp[e.id] ?? const {})[d]),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openSheet(Employee e, int day, Attendance? existing) async {
    final date = DateTime(_month.year, _month.month, day);
    await showMarkAttendanceSheet(
      context: context,
      employee: e,
      date: date,
      existing: existing,
      invalidateQuery:
          (year: _month.year, month: _month.month, employeeId: null),
    );
    if (mounted) setState(() {}); // refresh cell after mutation
  }
}

/// Clay pill month pager for the module header.
class _MonthPager extends StatelessWidget {
  const _MonthPager(
      {required this.month, required this.onPrev, required this.onNext});
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return ClayContainer(
      variant: ClayVariant.soft,
      color: lum.surface,
      borderRadius: AppRadius.pill,
      isDark: lum.isDark,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _chevron(context, LucideIcons.chevronLeft, 'Previous month', onPrev),
          SizedBox(
            width: 78,
            child: Text(
              '${_monthNames[month.month - 1]} ${month.year}',
              textAlign: TextAlign.center,
              style: AppTypography.subhead.copyWith(
                fontWeight: FontWeight.w600,
                color: lum.textPrimary,
              ),
            ),
          ),
          _chevron(context, LucideIcons.chevronRight, 'Next month', onNext),
        ],
      ),
    );
  }

  Widget _chevron(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    final lum = context.lum;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 18, color: lum.textPrimary),
        ),
      ),
    );
  }
}

/// Tinted marker tile + label for each attendance status.
class _StatusLegend extends StatelessWidget {
  const _StatusLegend();

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        for (final s in AttendanceStatus.values)
          () {
            final (bg, fg) = attendanceCellColors(context, s);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: lum.hairline),
                  ),
                  child: Text(
                    attendanceStatusShort[s]!,
                    style: AppTypography.monoValue.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  attendanceStatusLabels[s]!,
                  style:
                      AppTypography.caption.copyWith(color: lum.textSecondary),
                ),
              ],
            );
          }(),
      ],
    );
  }
}

/// Sticky left column: a corner spacer aligning with the day header, then one
/// initials-tile + name row per employee, each [_kCell] tall.
class _EmployeeColumn extends StatelessWidget {
  const _EmployeeColumn({required this.employees});
  final List<Employee> employees;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: _kNameCol, height: _kDayHead),
        for (final e in employees)
          SizedBox(
            width: _kNameCol,
            height: _kCell,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: lum.accentSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      hrInitials(e.name),
                      style: AppTypography.label.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: lum.accentPress,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      e.name,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption
                          .copyWith(color: lum.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Day-number header row inside the horizontally scrolling matrix.
class _DayHeaderRow extends StatelessWidget {
  const _DayHeaderRow({required this.days});
  final int days;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Row(
      children: [
        for (var d = 1; d <= days; d++)
          Padding(
            padding: const EdgeInsets.only(right: _kCellGap),
            child: SizedBox(
              width: _kCell,
              height: _kDayHead,
              child: Center(
                child: Text(
                  '$d',
                  style: AppTypography.monoValue.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: lum.g500,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// One employee's row of per-day cells.
class _DayCellsRow extends StatelessWidget {
  const _DayCellsRow(
      {required this.days, required this.byDay, required this.onTapDay});
  final int days;
  final Map<int, Attendance> byDay;
  final ValueChanged<int> onTapDay;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kCell,
      child: Row(
        children: [
          for (var d = 1; d <= days; d++)
            Padding(
              padding: const EdgeInsets.only(right: _kCellGap),
              child: _AttendanceCell(
                attendance: byDay[d],
                onTap: () => onTapDay(d),
              ),
            ),
        ],
      ),
    );
  }
}

class _AttendanceCell extends StatelessWidget {
  const _AttendanceCell({required this.attendance, required this.onTap});
  final Attendance? attendance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final a = attendance;
    final (bg, fg) = a == null
        ? (Colors.transparent, lum.g400)
        : attendanceCellColors(context, a.status);
    return Semantics(
      button: true,
      label: a == null ? 'Not marked' : attendanceStatusLabels[a.status]!,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: _kCell,
          height: _kCell,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(7),
            border: a == null ? Border.all(color: lum.hairline) : null,
          ),
          child: a == null
              ? null
              : Text(
                  attendanceStatusShort[a.status]!,
                  style: AppTypography.monoValue.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Centred empty/error state used inside the grid body.
class _CenteredState extends StatelessWidget {
  const _CenteredState(
      {required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: AppEmptyState(icon: icon, title: title, body: body),
      ),
    );
  }
}

/// Shared mark-attendance sheet (grid cell + profile tab). Performs the
/// mutation itself so it can surface EditReasonRequired inline. Returns true on
/// success.
Future<bool> showMarkAttendanceSheet({
  required BuildContext context,
  required Employee employee,
  required DateTime date,
  Attendance? existing,
  required AttendanceQuery invalidateQuery,
}) async {
  final result = await showAppSheet<bool>(
    context: context,
    builder: (_) => _MarkAttendanceSheet(
      employee: employee,
      date: date,
      existing: existing,
      invalidateQuery: invalidateQuery,
    ),
  );
  return result ?? false;
}

class _MarkAttendanceSheet extends ConsumerStatefulWidget {
  const _MarkAttendanceSheet({
    required this.employee,
    required this.date,
    required this.existing,
    required this.invalidateQuery,
  });
  final Employee employee;
  final DateTime date;
  final Attendance? existing;
  final AttendanceQuery invalidateQuery;

  @override
  ConsumerState<_MarkAttendanceSheet> createState() =>
      _MarkAttendanceSheetState();
}

class _MarkAttendanceSheetState extends ConsumerState<_MarkAttendanceSheet> {
  late AttendanceStatus _status =
      widget.existing?.status ?? AttendanceStatus.present;
  late String? _shiftId = widget.existing?.shiftId;
  TimeOfDay? _checkIn;
  TimeOfDay? _checkOut;
  late final _otCtrl = TextEditingController(
      text: (widget.existing?.overtimeHours ?? 0).toString());
  late final _notesCtrl =
      TextEditingController(text: widget.existing?.notes);
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final ci = widget.existing?.checkIn;
    final co = widget.existing?.checkOut;
    if (ci != null) _checkIn = TimeOfDay.fromDateTime(ci.toLocal());
    if (co != null) _checkOut = TimeOfDay.fromDateTime(co.toLocal());
  }

  @override
  void dispose() {
    _otCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String? _ts(TimeOfDay? t) {
    if (t == null) return null;
    final d = DateTime(widget.date.year, widget.date.month, widget.date.day,
        t.hour, t.minute);
    return d.toIso8601String();
  }

  Future<void> _pick(bool checkIn) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (checkIn ? _checkIn : _checkOut) ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => checkIn ? _checkIn = picked : _checkOut = picked);
    }
  }

  Future<void> _save() async {
    if (_isEdit && _notesCtrl.text.trim().isEmpty) {
      setState(() => _error = 'A reason is required to edit an existing day.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final failure = await ref.read(attendanceActionsProvider).mark({
      'p_employee_id': widget.employee.id,
      'p_date': widget.date.toIso8601String().substring(0, 10),
      'p_shift_id': _shiftId,
      'p_check_in': _ts(_checkIn),
      'p_check_out': _ts(_checkOut),
      'p_status': AttendanceModel.statusToDb(_status),
      'p_overtime_hours': double.tryParse(_otCtrl.text.trim()) ?? 0,
      'p_source': 'MANUAL',
      'p_notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    }, widget.invalidateQuery);
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _saving = false;
        _error = failure.message;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final shiftsAsync = ref.watch(shiftsProvider);
    final statuses = AttendanceStatus.values;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSheetHeader(
          title: _isEdit ? 'Edit attendance' : 'Mark attendance',
          subtitle: '${widget.employee.name} · '
              '${widget.date.toIso8601String().substring(0, 10)}',
        ),
        AppFilterChips(
          labels: [for (final s in statuses) attendanceStatusLabels[s]!],
          selected: statuses.indexOf(_status),
          onSelected: (i) => setState(() => _status = statuses[i]),
        ),
        const SizedBox(height: AppSpacing.md),
        shiftsAsync.maybeWhen(
          data: (shifts) => _ShiftDropdown(
            shifts: shifts,
            value: _shiftId,
            onChanged: (v) => setState(() => _shiftId = v),
          ),
          orElse: () => const SizedBox(),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
                child: _TimeBox(
                    label: 'Check-in',
                    value: _checkIn,
                    onTap: () => _pick(true))),
            const SizedBox(width: AppSpacing.md),
            Expanded(
                child: _TimeBox(
                    label: 'Check-out',
                    value: _checkOut,
                    onTap: () => _pick(false))),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
            controller: _otCtrl,
            label: 'Overtime (hours)',
            prefixIcon: LucideIcons.clock,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true)),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
            controller: _notesCtrl,
            label: _isEdit ? 'Reason (required)' : 'Notes (optional)',
            prefixIcon: LucideIcons.pencil),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppInlineBanner(message: _error!, type: BannerType.error),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
            label: 'Save',
            fullWidth: true,
            loading: _saving,
            onPressed: _saving ? null : _save),
      ],
    );
  }
}

class _ShiftDropdown extends StatelessWidget {
  const _ShiftDropdown(
      {required this.shifts, required this.value, required this.onChanged});
  final List<Shift> shifts;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppDropdown<String?>(
      value: value,
      placeholder: 'Shift (optional)',
      options: [
        const AppDropdownOption<String?>(value: null, label: 'No shift'),
        for (final s in shifts)
          AppDropdownOption<String?>(value: s.id, label: s.name),
      ],
      onSelected: onChanged,
    );
  }
}

class _TimeBox extends StatelessWidget {
  const _TimeBox(
      {required this.label, required this.value, required this.onTap});
  final String label;
  final TimeOfDay? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(label,
              style: AppTypography.caption
                  .copyWith(color: lum.textSecondary)),
        ),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: lum.surface2,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(children: [
              Icon(LucideIcons.clock, color: lum.g500, size: 18),
              const SizedBox(width: 10),
              Text(value == null ? '—' : value!.format(context),
                  style: AppTypography.body.copyWith(color: lum.textPrimary)),
            ]),
          ),
        ),
      ],
    );
  }
}
