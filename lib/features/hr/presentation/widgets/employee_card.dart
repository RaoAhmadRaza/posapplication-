import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../domain/entities/employee.dart';
import 'hr_ui.dart';

/// One employee row in the Employees hub list. Follows the design: a soft
/// accent-tinted initials tile, name + code, designation · department, and a
/// trailing column with the status pill over the base-salary figure.
class EmployeeCard extends StatelessWidget {
  const EmployeeCard({super.key, required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final subtitle = [employee.designation, employee.department]
        .where((e) => e != null && e.isNotEmpty)
        .join(' · ');

    return AppCard(
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
      onTap: () => context.push('/hr/employees/${employee.id}'),
      child: Row(
        children: [
          _InitialsTile(name: employee.name, lum: lum),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        employee.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.subhead
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      employee.employeeCode,
                      style: AppTypography.caption.copyWith(
                        fontFamily: AppTypography.mono,
                        color: lum.g500,
                      ),
                    ),
                  ],
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption
                        .copyWith(color: lum.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppPill(
                label: employeeStatusLabels[employee.status]!,
                tone: employeeStatusTone(employee.status),
              ),
              const SizedBox(height: 7),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppMoneyText(employee.baseSalary, size: 14),
                  const SizedBox(width: 3),
                  Text(
                    salaryUnitLabels[employee.salaryType]!,
                    style: AppTypography.caption.copyWith(color: lum.g400),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 6),
          Icon(LucideIcons.chevronRight, size: 18, color: lum.g400),
        ],
      ),
    );
  }
}

/// Soft accent tile with the employee's initials, matching the design's
/// `--lumen-soft` fill / `--lumen` ink.
class _InitialsTile extends StatelessWidget {
  const _InitialsTile({required this.name, required this.lum});

  final String name;
  final LumColors lum;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: lum.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        hrInitials(name),
        style: AppTypography.subhead.copyWith(
          fontWeight: FontWeight.w700,
          color: lum.accent,
        ),
      ),
    );
  }
}
