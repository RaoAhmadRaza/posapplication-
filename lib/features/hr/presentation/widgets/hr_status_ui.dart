import 'package:flutter/material.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../domain/entities/employee.dart';

const employeeStatusLabels = {
  EmployeeStatus.active: 'Active',
  EmployeeStatus.onLeave: 'On Leave',
  EmployeeStatus.suspended: 'Suspended',
  EmployeeStatus.terminated: 'Terminated',
  EmployeeStatus.resigned: 'Resigned',
};

const salaryTypeLabels = {
  SalaryType.monthly: 'Monthly',
  SalaryType.daily: 'Daily',
  SalaryType.hourly: 'Hourly',
};

Color employeeStatusColor(EmployeeStatus s) => switch (s) {
      EmployeeStatus.active => AppColors.success,
      EmployeeStatus.onLeave => AppColors.warning,
      EmployeeStatus.suspended => AppColors.warning,
      EmployeeStatus.terminated => AppColors.destructive,
      EmployeeStatus.resigned => AppColors.textMuted,
    };

class EmployeeStatusBadge extends StatelessWidget {
  const EmployeeStatusBadge({super.key, required this.status});
  final EmployeeStatus status;

  @override
  Widget build(BuildContext context) {
    final color = employeeStatusColor(status);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        employeeStatusLabels[status]!,
        style: AppTypography.caption
            .copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
