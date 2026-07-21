import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/widgets/module_scaffold.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../../customers/presentation/controllers/customers_controller.dart';
import 'repair_job_card.dart';
import 'repair_sheet.dart';

/// Customer picker returning the chosen [Customer] — the design's PickerList in
/// a repair sheet (modal on wide, bottom sheet on narrow).
/// Reuses [customersProvider] search; does not touch any POS cart state.
Future<Customer?> showRepairCustomerPicker(BuildContext context) {
  return showRepairSheet<Customer>(
    context: context,
    builder: (_) => const _RepairCustomerPicker(),
  );
}

class _RepairCustomerPicker extends ConsumerStatefulWidget {
  const _RepairCustomerPicker();

  @override
  ConsumerState<_RepairCustomerPicker> createState() =>
      _RepairCustomerPickerState();
}

class _RepairCustomerPickerState extends ConsumerState<_RepairCustomerPicker> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider).value ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const RepairPickerTitle(title: 'Select customer'),
        const SizedBox(height: 14),
        RepairPickerSearch(
          controller: _searchCtrl,
          hint: 'Name or phone',
          semanticsLabel: 'Search customers',
          onSubmitted: (q) => ref.read(customersProvider.notifier).search(q),
        ),
        const SizedBox(height: 12),
        if (customers.isEmpty)
          const RepairPickerMessage(text: 'No matches')
        else
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: repairPickerListMaxHeight(context),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: customers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final c = customers[i];
                return RepairPickerRow(
                  leading: RepairTechAvatar(name: c.name, size: 36),
                  title: c.name,
                  subtitle: c.phone,
                  onTap: () => Navigator.of(context).pop(c),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared PickerList parts. Declared here (not a new file) and reused by the
// product picker so both sheets read identically.
// ---------------------------------------------------------------------------

/// Scroll height of a picker's row list: the design's ~320 on wide, a little
/// shorter on narrow where the sheet already caps itself.
double repairPickerListMaxHeight(BuildContext context) =>
    ModuleScaffold.isWideOf(context) ? 320 : 280;

/// The picker's display-face title.
class RepairPickerTitle extends StatelessWidget {
  const RepairPickerTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: AppTypography.title2.copyWith(
          fontSize: 19,
          color: context.lum.textPrimary,
        ),
      );
}

/// Centred muted line — 'No matches', 'Search to add a part', an error.
class RepairPickerMessage extends StatelessWidget {
  const RepairPickerMessage({super.key, required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTypography.footnote.copyWith(
          color: isError ? lum.dangerText : lum.g500,
        ),
      ),
    );
  }
}

/// Inset search well — 48 high with a magnifier, no label.
class RepairPickerSearch extends StatelessWidget {
  const RepairPickerSearch({
    super.key,
    required this.controller,
    required this.hint,
    required this.semanticsLabel,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final String semanticsLabel;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return ClayContainer(
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
            child: Semantics(
              textField: true,
              label: semanticsLabel,
              child: TextField(
                controller: controller,
                onSubmitted: onSubmitted,
                textInputAction: TextInputAction.search,
                cursorColor: lum.accent,
                style: AppTypography.fieldText.copyWith(color: lum.textPrimary),
                decoration: InputDecoration(
                  isCollapsed: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: hint,
                  hintStyle:
                      AppTypography.fieldHint.copyWith(color: lum.textTertiary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One inset clay row: a 36px leading element, primary + secondary text and an
/// optional right-aligned trailing (a price).
class RepairPickerRow extends StatelessWidget {
  const RepairPickerRow({
    super.key,
    required this.leading,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.subtitleMono = false,
    this.trailing,
    this.dimmed = false,
  });

  final Widget leading;
  final String title;
  final String? subtitle;

  /// SKU-style secondary text renders in the mono face.
  final bool subtitleMono;
  final Widget? trailing;

  /// Greys the row out (e.g. a part with no stock on hand).
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final sub = subtitle;

    return Semantics(
      button: true,
      label: sub == null ? title : '$title, $sub',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Opacity(
          opacity: dimmed ? 0.55 : 1,
          child: ClayContainer(
            variant: ClayVariant.inset,
            color: lum.surface2,
            borderRadius: AppRadius.md,
            isDark: lum.isDark,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.label.copyWith(
                          fontSize: 14.5,
                          color: lum.textPrimary,
                        ),
                      ),
                      if (sub != null && sub.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: subtitleMono
                              ? AppTypography.monoValue.copyWith(
                                  fontSize: 12,
                                  color: lum.g500,
                                )
                              : AppTypography.caption.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: lum.g500,
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 10),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
