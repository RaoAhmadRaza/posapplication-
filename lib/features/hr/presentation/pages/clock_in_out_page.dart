import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../domain/entities/attendance.dart';
import '../../domain/entities/employee.dart';
import '../../data/models/attendance_model.dart';
import '../controllers/attendance_controller.dart';
import '../controllers/leaves_controller.dart';
import '../widgets/hr_ui.dart';

/// Simple self-service clock in/out for the signed-in user's linked employee.
/// GPS / biometric deferred; source stamped MANUAL.
class ClockInOutPage extends ConsumerWidget {
  const ClockInOutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meAsync = ref.watch(myEmployeeProvider);
    return AppDetailScaffold(
      eyebrow: 'HR',
      title: 'Clock in / out',
      maxContentWidth: 460,
      child: meAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => const AppInlineBanner(
          message: 'Unable to load your record.',
          type: BannerType.error,
        ),
        data: (me) {
          if (me == null) {
            return const AppEmptyState(
              icon: LucideIcons.userRoundX,
              title: 'No linked employee',
              body: 'No employee is linked to your account.',
            );
          }
          return _ClockBody(employee: me);
        },
      ),
    );
  }
}

class _ClockBody extends ConsumerStatefulWidget {
  const _ClockBody({required this.employee});
  final Employee employee;

  @override
  ConsumerState<_ClockBody> createState() => _ClockBodyState();
}

class _ClockBodyState extends ConsumerState<_ClockBody> {
  bool _saving = false;
  String? _error;

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  AttendanceQuery get _query =>
      (year: _today.year, month: _today.month, employeeId: widget.employee.id);

  Attendance? _todayRow(List<Attendance> rows) {
    for (final a in rows) {
      if (a.date.year == _today.year &&
          a.date.month == _today.month &&
          a.date.day == _today.day) {
        return a;
      }
    }
    return null;
  }

  Future<void> _punch({required bool clockOut, Attendance? existing}) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final now = DateTime.now();
    final failure = await ref.read(attendanceActionsProvider).mark({
      'p_employee_id': widget.employee.id,
      'p_date': _today.toIso8601String().substring(0, 10),
      'p_shift_id': existing?.shiftId,
      'p_check_in': (existing?.checkIn ?? now).toIso8601String(),
      'p_check_out': clockOut ? now.toIso8601String() : null,
      'p_status': AttendanceModel.statusToDb(
          existing?.status ?? AttendanceStatus.present),
      'p_overtime_hours': existing?.overtimeHours ?? 0,
      'p_source': 'MANUAL',
      // clock-out edits today's row → audit rule needs a reason
      'p_notes': clockOut ? 'Clock out' : null,
    }, _query);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (failure != null) _error = failure.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final async = ref.watch(attendanceMonthProvider(_query));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => const AppInlineBanner(
        message: 'Unable to load today.',
        type: BannerType.error,
      ),
      data: (rows) {
        final today = _todayRow(rows);
        final checkedIn = today?.checkIn != null;
        final checkedOut = today?.checkOut != null;
        return Column(
          children: [
            // ClayVariant.lumen paints no fill of its own — the accent wash
            // has to be passed explicitly (trap #1).
            ClayContainer(
              variant: ClayVariant.lumen,
              color: lum.accent,
              borderRadius: AppRadius.lg,
              isDark: lum.isDark,
              width: 72,
              height: 72,
              child: Center(
                child: Text(
                  hrInitials(widget.employee.name),
                  style: AppTypography.title1.copyWith(
                    fontSize: 24,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.employee.name,
              textAlign: TextAlign.center,
              style: AppTypography.title2.copyWith(color: lum.textPrimary),
            ),
            if (widget.employee.designation != null) ...[
              const SizedBox(height: 2),
              Text(
                widget.employee.designation!,
                textAlign: TextAlign.center,
                style: AppTypography.subhead.copyWith(color: lum.g500),
              ),
            ],
            const SizedBox(height: 24),
            ClayContainer(
              variant: ClayVariant.raised,
              color: lum.surface,
              borderRadius: AppRadius.xl,
              isDark: lum.isDark,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _PunchRow(label: 'Check-in', value: _fmt(today?.checkIn)),
                  Divider(height: 21, thickness: 1, color: lum.hairline),
                  _PunchRow(label: 'Check-out', value: _fmt(today?.checkOut)),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.base),
                    AppInlineBanner(message: _error!, type: BannerType.error),
                  ],
                  const SizedBox(height: 18),
                  if (checkedIn && checkedOut)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.checkCircle2,
                              size: 20, color: lum.successText),
                          const SizedBox(width: 9),
                          Text(
                            'Done for today.',
                            style: AppTypography.headline.copyWith(
                              fontSize: 15,
                              color: lum.successText,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (checkedIn)
                    AppButton(
                      label: 'Clock out',
                      icon: LucideIcons.logOut,
                      variant: AppButtonVariant.destructive,
                      fullWidth: true,
                      loading: _saving,
                      onPressed: _saving
                          ? null
                          : () => _punch(clockOut: true, existing: today),
                    )
                  else
                    AppButton(
                      label: 'Clock in',
                      icon: LucideIcons.logIn,
                      fullWidth: true,
                      loading: _saving,
                      onPressed:
                          _saving ? null : () => _punch(clockOut: false),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Self-service punch for your own linked employee record. '
              'Times are recorded to the second.',
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(color: lum.g500),
            ),
          ],
        );
      },
    );
  }

  static String _fmt(DateTime? t) {
    if (t == null) return '—';
    final l = t.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }
}

class _PunchRow extends StatelessWidget {
  const _PunchRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.body.copyWith(color: lum.g500)),
        Text(
          value,
          style: AppTypography.monoValue.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: lum.textPrimary,
          ),
        ),
      ],
    );
  }
}
