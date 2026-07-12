import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';

/// Branch filter shared by the report pages. null value = all branches.
class ReportBranchDropdown extends ConsumerWidget {
  const ReportBranchDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branches = ref.watch(userBranchesProvider).asData?.value ?? const [];
    return _FieldShell(
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down,
              size: 18, color: AppColors.textMuted),
          style: AppTypography.subhead,
          onChanged: onChanged,
          items: [
            const DropdownMenuItem<String?>(
                value: null, child: Text('All branches')),
            for (final b in branches)
              DropdownMenuItem<String?>(value: b.id, child: Text(b.name)),
          ],
        ),
      ),
    );
  }
}

/// Tappable date chip that opens a date picker.
class ReportDateChip extends StatelessWidget {
  const ReportDateChip({
    super.key,
    required this.label,
    required this.value,
    required this.onPick,
  });
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onPick;

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) onPick(picked);
  }

  @override
  Widget build(BuildContext context) {
    final text = '${value.year}-${value.month.toString().padLeft(2, '0')}'
        '-${value.day.toString().padLeft(2, '0')}';
    return _FieldShell(
      onTap: () => _pick(context),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 15, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text('$label: $text', style: AppTypography.subhead),
          ),
        ],
      ),
    );
  }
}

class _FieldShell extends StatelessWidget {
  const _FieldShell({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.field),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.field),
          border: Border.all(color: AppColors.separator),
        ),
        child: Align(alignment: Alignment.centerLeft, child: child),
      ),
    );
  }
}
