import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import 'acct_date_field.dart';

/// Branch filter shared by the report pages. null value = all branches. Rendered
/// as the design's compact clay filter chip.
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
    final lum = context.lum;
    final branches = ref.watch(userBranchesProvider).asData?.value ?? const [];
    return _Chip(
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isDense: true,
          borderRadius: BorderRadius.circular(AppRadius.md),
          dropdownColor: lum.surface,
          icon: Icon(LucideIcons.chevronDown, size: 15, color: lum.g500),
          style: AppTypography.subhead.copyWith(color: lum.textPrimary),
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
    final lum = context.lum;
    return _Chip(
      onTap: () => _pick(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.calendar, size: 15, color: lum.g500),
          const SizedBox(width: 7),
          Text('$label ${acctFormatDate(value)}',
              style: AppTypography.subhead.copyWith(color: lum.textPrimary)),
        ],
      ),
    );
  }
}

/// The design's clay filter chip shell.
class _Chip extends StatelessWidget {
  const _Chip({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final chip = ClayContainer(
      variant: ClayVariant.soft,
      color: lum.surface,
      borderRadius: AppRadius.pill,
      isDark: lum.isDark,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      child: Align(alignment: Alignment.centerLeft, child: child),
    );
    if (onTap == null) return chip;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: chip,
      ),
    );
  }
}
