import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Formats a date as the design's "7 Jul 2026".
String acctFormatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// Compact "2 Jul" for dense table rows.
String acctFormatDateShort(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// The design's date tile: a clay-inset well with a calendar glyph and the
/// selected date, opening the platform date picker on tap. Optionally clearable.
class AcctDateField extends StatelessWidget {
  const AcctDateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint = 'Select date',
    this.firstDate,
    this.lastDate,
    this.clearable = false,
  });

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String hint;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool clearable;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? now,
      firstDate: firstDate ?? DateTime(now.year - 5),
      lastDate: lastDate ?? DateTime(now.year + 5),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final hasValue = value != null;
    return Semantics(
      button: true,
      label: hasValue ? acctFormatDate(value!) : hint,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _pick(context),
        child: ClayContainer(
          variant: ClayVariant.inset,
          color: lum.surface2,
          borderRadius: AppRadius.md,
          isDark: lum.isDark,
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: Row(
            children: [
              Icon(LucideIcons.calendar, size: 17, color: lum.g500),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  hasValue ? acctFormatDate(value!) : hint,
                  style: AppTypography.fieldText.copyWith(
                    color: hasValue ? lum.textPrimary : lum.g400,
                  ),
                ),
              ),
              if (clearable && hasValue)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(null),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(LucideIcons.x, size: 15, color: lum.g400),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
