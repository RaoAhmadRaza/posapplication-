import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_text_field.dart';

/// IMEI / serial capture block shared by the GRN receive and return forms. Both
/// hand-rolled the same control before this existed. The completion colour is
/// the caller's call ([met]) — GRN allows ≥ target, returns require exactly it.
class PurchasingImeiCapture extends StatelessWidget {
  const PurchasingImeiCapture({
    super.key,
    required this.imeis,
    required this.input,
    required this.target,
    required this.met,
    required this.onAdd,
    required this.onRemove,
    this.onScan,
  });

  final List<String> imeis;
  final TextEditingController input;
  final int target;
  final bool met;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  /// Shown as a Scan button when non-null (caller gates on barcodeScanSupported).
  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 26, color: lum.hairline),
        Row(
          children: [
            Icon(LucideIcons.scanLine, size: 16, color: lum.g500),
            const SizedBox(width: 8),
            Expanded(
              child: Text('IMEI / serial capture',
                  style: AppTypography.footnote.copyWith(
                    fontWeight: FontWeight.w600,
                    color: lum.textPrimary,
                  )),
            ),
            Text('${imeis.length} / $target',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: met && target > 0 ? lum.successText : lum.warningText,
                )),
          ],
        ),
        for (final imei in imeis)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(LucideIcons.smartphone, size: 15, color: lum.g500),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(imei,
                      style: AppTypography.footnote.copyWith(
                        fontFamily: AppTypography.mono,
                        color: lum.textPrimary,
                      )),
                ),
                Semantics(
                  button: true,
                  label: 'Remove $imei',
                  child: InkWell(
                    onTap: () => onRemove(imei),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(LucideIcons.trash2,
                          size: 16, color: lum.dangerText),
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: AppTextField(
                controller: input,
                label: 'Enter IMEI',
                prefixIcon: LucideIcons.hash,
                hint: 'Type the number, then tap Add',
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onSubmitted: onAdd,
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 0),
              child: _MiniButton(
                icon: LucideIcons.plus,
                onTap: () => onAdd(input.text),
              ),
            ),
          ],
        ),
        if (onScan != null) ...[
          const SizedBox(height: 8),
          AppButton(
            label: 'Scan',
            variant: AppButtonVariant.tinted,
            icon: LucideIcons.scanLine,
            fullWidth: true,
            onPressed: onScan,
          ),
        ],
      ],
    );
  }
}

/// 50px square clay add button matching the field height beside it.
class _MiniButton extends StatelessWidget {
  const _MiniButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Semantics(
      button: true,
      label: 'Add IMEI',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ClayContainer(
          variant: ClayVariant.lumen,
          color: lum.accent,
          borderRadius: AppRadius.md,
          isDark: lum.isDark,
          width: 50,
          height: 50,
          child: const Center(child: Icon(Icons.add, color: Colors.white)),
        ),
      ),
    );
  }
}
