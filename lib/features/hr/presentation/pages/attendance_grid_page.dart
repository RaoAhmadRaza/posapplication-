import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/attendance.dart';
import '../../domain/entities/employee.dart';
import '../../domain/entities/shift.dart';
import '../../data/models/attendance_model.dart';
import '../controllers/attendance_controller.dart';
import '../controllers/shifts_controller.dart';
import '../widgets/hr_status_ui.dart';

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
        title: Text('Attendance', style: AppTypography.headline),
        actions: [
          IconButton(
            icon: const Icon(Icons.punch_clock_outlined,
                color: AppColors.accent),
            tooltip: 'Clock In/Out',
            onPressed: () => context.push('/hr/clock'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _MonthBar(
              month: _month,
              onPrev: () => setState(() =>
                  _month = DateTime(_month.year, _month.month - 1)),
              onNext: () => setState(() =>
                  _month = DateTime(_month.year, _month.month + 1)),
            ),
            if (branchId == null)
              const Expanded(
                child: Center(child: Text('Select a branch first.')),
              )
            else
              Expanded(child: _grid(branchId, days)),
          ],
        ),
      ),
    );
  }

  Widget _grid(String branchId, int days) {
    final employeesAsync = ref.watch(branchEmployeesProvider(branchId));
    final query =
        (year: _month.year, month: _month.month, employeeId: null);
    final attendanceAsync = ref.watch(attendanceMonthProvider(query));

    return employeesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: AppInlineBanner(
              message: 'Could not load employees.', type: BannerType.error),
        ),
      ),
      data: (employees) => attendanceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: AppInlineBanner(
                message: 'Could not load attendance.',
                type: BannerType.error),
          ),
        ),
        data: (rows) {
          if (employees.isEmpty) {
            return Center(
              child: Text('No employees in this branch.',
                  style: AppTypography.footnote
                      .copyWith(color: AppColors.textMuted)),
            );
          }
          // pivot: employeeId → day → attendance
          final byEmp = <String, Map<int, Attendance>>{};
          for (final a in rows) {
            byEmp.putIfAbsent(a.employeeId, () => {})[a.date.day] = a;
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _headerRow(days),
                  for (final e in employees)
                    _employeeRow(e, byEmp[e.id] ?? const {}, days),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static const _nameW = 140.0;
  static const _cellW = 30.0;

  Widget _headerRow(int days) {
    return Row(
      children: [
        _cell(width: _nameW, child: const SizedBox()),
        for (var d = 1; d <= days; d++)
          _cell(
            child: Text('$d',
                style: AppTypography.caption
                    .copyWith(color: AppColors.textMuted)),
          ),
      ],
    );
  }

  Widget _employeeRow(Employee e, Map<int, Attendance> byDay, int days) {
    return Row(
      children: [
        _cell(
          width: _nameW,
          align: Alignment.centerLeft,
          child: Text(e.name,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption),
        ),
        for (var d = 1; d <= days; d++)
          GestureDetector(
            onTap: () => _openSheet(e, d, byDay[d]),
            child: _AttendanceCell(attendance: byDay[d], width: _cellW),
          ),
      ],
    );
  }

  Widget _cell(
      {required Widget child, double width = _cellW, Alignment? align}) {
    return Container(
      width: width,
      height: 34,
      alignment: align ?? Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: AppColors.separator, width: 0.5),
          bottom: BorderSide(color: AppColors.separator, width: 0.5),
        ),
      ),
      child: child,
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

class _AttendanceCell extends StatelessWidget {
  const _AttendanceCell({required this.attendance, required this.width});
  final Attendance? attendance;
  final double width;

  @override
  Widget build(BuildContext context) {
    final a = attendance;
    final color = a == null ? null : attendanceStatusColor(a.status);
    return Container(
      width: width,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 0.16),
        border: const Border(
          right: BorderSide(color: AppColors.separator, width: 0.5),
          bottom: BorderSide(color: AppColors.separator, width: 0.5),
        ),
      ),
      child: a == null
          ? const SizedBox()
          : Text(attendanceStatusShort[a.status]!,
              style: AppTypography.caption
                  .copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _MonthBar extends StatelessWidget {
  const _MonthBar(
      {required this.month, required this.onPrev, required this.onNext});
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  static const _names = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding, vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
              icon: const Icon(Icons.chevron_left, color: AppColors.accent),
              onPressed: onPrev),
          Text('${_names[month.month - 1]} ${month.year}',
              style: AppTypography.subhead
                  .copyWith(fontWeight: FontWeight.w600)),
          IconButton(
              icon: const Icon(Icons.chevron_right, color: AppColors.accent),
              onPressed: onNext),
        ],
      ),
    );
  }
}

/// Shared mark-attendance bottom sheet (grid cell + profile tab). Performs the
/// mutation itself so it can surface EditReasonRequired inline. Returns true on
/// success.
Future<bool> showMarkAttendanceSheet({
  required BuildContext context,
  required Employee employee,
  required DateTime date,
  Attendance? existing,
  required AttendanceQuery invalidateQuery,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
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
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.screenPadding,
        right: AppSpacing.screenPadding,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.employee.name} · '
                '${widget.date.toIso8601String().substring(0, 10)}',
                style: AppTypography.headline),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final s in AttendanceStatus.values)
                  ChoiceChip(
                    label: Text(attendanceStatusLabels[s]!),
                    selected: _status == s,
                    onSelected: (_) => setState(() => _status = s),
                  ),
              ],
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
                prefixIcon: Icons.more_time,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
                controller: _notesCtrl,
                label: _isEdit ? 'Reason (required)' : 'Notes (optional)',
                prefixIcon: Icons.notes),
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
        ),
      ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: value,
          hint: Text('Shift (optional)',
              style: AppTypography.fieldHint),
          items: [
            const DropdownMenuItem(value: null, child: Text('No shift')),
            for (final s in shifts)
              DropdownMenuItem(value: s.id, child: Text(s.name)),
          ],
          onChanged: onChanged,
        ),
      ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(label, style: AppTypography.fieldLabel),
        ),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.fieldFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.access_time,
                  color: AppColors.textMuted, size: 20),
              const SizedBox(width: 10),
              Text(value == null ? '—' : value!.format(context),
                  style: AppTypography.fieldText),
            ]),
          ),
        ),
      ],
    );
  }
}
