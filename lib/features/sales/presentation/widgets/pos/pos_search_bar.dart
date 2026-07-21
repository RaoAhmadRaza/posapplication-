import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../../core/design/app_colors.dart';
import '../../../../../core/design/app_radius.dart';
import '../../../../../core/design/app_typography.dart';
import '../../../../../core/design/clay.dart';
import '../../../../../core/services/scanner_support.dart';

/// Catalogue search well plus the scan button, as one row.
///
/// Deliberately not [AppTextField]: the design's POS field carries no label and
/// sits in an inset well beside a square scan action.
class PosSearchBar extends StatelessWidget {
  const PosSearchBar({
    super.key,
    required this.controller,
    required this.onScan,
  });

  final TextEditingController controller;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;

    return Row(
      children: [
        Expanded(
          child: ClayContainer(
            variant: ClayVariant.inset,
            color: lum.surface2,
            borderRadius: AppRadius.md,
            isDark: lum.isDark,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(LucideIcons.search, size: 18, color: lum.g400),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: AppTypography.fieldText.copyWith(
                      color: lum.textPrimary,
                    ),
                    cursorColor: lum.accent,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      // The theme fills inputs; without this a second grey pill
                      // paints inside the well.
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: 'Search part or scan SKU…',
                      hintStyle: AppTypography.fieldHint.copyWith(
                        color: lum.textTertiary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (barcodeScanSupported) ...[
          const SizedBox(width: 10),
          Semantics(
            button: true,
            label: 'Scan barcode',
            child: InkWell(
              onTap: onScan,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: ClayContainer(
                variant: ClayVariant.soft,
                color: lum.surface,
                borderRadius: AppRadius.md,
                isDark: lum.isDark,
                width: 48,
                height: 48,
                child: Icon(
                  LucideIcons.scanLine,
                  size: 22,
                  color: lum.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
