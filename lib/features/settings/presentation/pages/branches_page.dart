import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_dropdown.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_sheet.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toggle.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../../auth/presentation/controllers/permission_controller.dart';
import '../../domain/entities/branch_config.dart';
import '../../domain/failures/settings_failure.dart';
import '../controllers/branches_controller.dart';

/// Option lists carried by the design export. A branch already stored on a
/// value outside these lists still displays it — [AppDropdown] keeps an
/// unmatched value as its own option rather than dropping it.
const _countries = [
  AppDropdownOption(value: 'Pakistan', label: 'Pakistan'),
  AppDropdownOption(value: 'UAE', label: 'United Arab Emirates'),
  AppDropdownOption(value: 'Saudi Arabia', label: 'Saudi Arabia'),
];
const _currencies = [
  AppDropdownOption(value: 'PKR', label: 'PKR — Pakistani rupee'),
  AppDropdownOption(value: 'AED', label: 'AED — UAE dirham'),
  AppDropdownOption(value: 'USD', label: 'USD — US dollar'),
];
const _timezones = [
  AppDropdownOption(value: 'Asia/Karachi', label: 'Asia/Karachi (PKT)'),
  AppDropdownOption(value: 'Asia/Dubai', label: 'Asia/Dubai (GST)'),
  AppDropdownOption(value: 'Asia/Riyadh', label: 'Asia/Riyadh (AST)'),
];

class BranchesPage extends ConsumerWidget {
  const BranchesPage({super.key});

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    BranchConfig branch,
  ) async {
    final name = TextEditingController(text: branch.name);
    final city = TextEditingController(text: branch.city ?? '');
    var country = branch.country ?? 'Pakistan';
    var currency = branch.currency;
    var timezone = branch.timezone;
    var isActive = branch.isActive;
    var saving = false;
    var nameTouched = false;

    await showAppSheet<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (builderContext, setSheetState) {
          final nameEmpty = name.text.trim().isEmpty;
          return _BranchForm(
            title: 'Edit branch',
            subtitle: "Update this location's details.",
            name: name,
            city: city,
            country: country,
            currency: currency,
            timezone: timezone,
            isActive: isActive,
            saving: saving,
            nameError: nameTouched && nameEmpty,
            saveLabel: 'Save',
            onNameChanged: (_) => setSheetState(() => nameTouched = true),
            onCountry: (v) => setSheetState(() => country = v),
            onCurrency: (v) => setSheetState(() => currency = v),
            onTimezone: (v) => setSheetState(() => timezone = v),
            onActive: (v) => setSheetState(() => isActive = v),
            onCancel: () => Navigator.of(builderContext).pop(),
            onSave: saving || nameEmpty
                ? null
                : () async {
                    setSheetState(() => saving = true);
                    final failure = await ref
                        .read(branchesProvider.notifier)
                        .saveBranch(
                          branchId: branch.id,
                          name: name.text.trim(),
                          city: city.text.trim(),
                          country: country,
                          currency: currency,
                          timezone: timezone,
                          isActive: isActive,
                        );
                    if (!builderContext.mounted) return;
                    setSheetState(() => saving = false);
                    if (failure == null) {
                      Navigator.of(builderContext).pop();
                    }
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content:
                          Text(failure == null ? 'Saved' : failure.message),
                    ));
                  },
          );
        },
      ),
    );

    name.dispose();
    city.dispose();
  }

  Future<void> _openCreate(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final city = TextEditingController();
    var country = 'Pakistan';
    var currency = 'PKR';
    var timezone = 'Asia/Karachi';
    var isActive = true;
    var saving = false;
    var nameTouched = false;
    String? error;

    await showAppSheet<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (builderContext, setSheetState) {
          final nameEmpty = name.text.trim().isEmpty;
          return _BranchForm(
            title: 'New branch',
            subtitle: 'Add a location to your business.',
            name: name,
            city: city,
            country: country,
            currency: currency,
            timezone: timezone,
            isActive: isActive,
            saving: saving,
            nameError: nameTouched && nameEmpty,
            error: error,
            saveLabel: 'Create branch',
            onNameChanged: (_) => setSheetState(() => nameTouched = true),
            onCountry: (v) => setSheetState(() => country = v),
            onCurrency: (v) => setSheetState(() => currency = v),
            onTimezone: (v) => setSheetState(() => timezone = v),
            onActive: (v) => setSheetState(() => isActive = v),
            onCancel: () => Navigator.of(builderContext).pop(),
            onSave: saving || nameEmpty
                ? null
                : () async {
                    setSheetState(() {
                      saving = true;
                      error = null;
                    });
                    final failure = await ref
                        .read(branchesProvider.notifier)
                        .createBranch(
                          name: name.text.trim(),
                          city: city.text.trim(),
                          country: country,
                          currency: currency,
                          timezone: timezone,
                        );
                    if (!builderContext.mounted) return;
                    setSheetState(() => saving = false);
                    if (failure == null) {
                      Navigator.of(builderContext).pop();
                    } else {
                      setSheetState(() => error = failure.message);
                    }
                  },
          );
        },
      ),
    );

    name.dispose();
    city.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(branchesProvider);
    final matrix = ref.watch(permissionMatrixProvider).value;
    final canEdit = matrix?.contains('settings:update') ?? false;
    final canCreate = matrix?.contains('settings:create') ?? false;
    final branchCount = ref.watch(userBranchesProvider).value?.length ?? 0;

    return AppDetailScaffold(
      eyebrow: 'Settings',
      title: 'Branches',
      description: 'The locations your business operates.',
      actions: [
        // Manual entry to the branch selector (only meaningful with >1 branch;
        // re-arms the router's needsSelection redirect to /branch-select).
        if (branchCount > 1)
          AppButton(
            label: 'Switch',
            variant: AppButtonVariant.tinted,
            size: AppButtonSize.sm,
            icon: LucideIcons.repeat,
            onPressed: () => BranchRouterState.instance.reopenSelection(),
          ),
        if (canCreate)
          AppButton(
            label: 'New branch',
            size: AppButtonSize.sm,
            icon: LucideIcons.plus,
            onPressed: () => _openCreate(context, ref),
          ),
      ],
      child: state.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => AppInlineBanner(
          message: e is SettingsFailure ? e.message : e.toString(),
        ),
        data: (branches) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < branches.length; i++) ...[
              if (i > 0) const SizedBox(height: 14),
              _BranchCard(
                branch: branches[i],
                canEdit: canEdit,
                onTap: canEdit
                    ? () => _openEditor(context, ref, branches[i])
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BranchCard extends StatelessWidget {
  const _BranchCard({
    required this.branch,
    required this.canEdit,
    required this.onTap,
  });

  final BranchConfig branch;
  final bool canEdit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final location = [branch.city, branch.country]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: lum.accentSoft,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(LucideIcons.mapPin, size: 22, color: lum.accent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        branch.name,
                        style: AppTypography.headline.copyWith(
                          fontSize: 16,
                          color: lum.textPrimary,
                        ),
                      ),
                    ),
                    if (branch.isMain) ...[
                      const SizedBox(width: 8),
                      const AppPill(
                        label: 'Default',
                        tone: AppPillTone.warning,
                        showDot: false,
                      ),
                    ],
                  ],
                ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    location,
                    style: AppTypography.footnote.copyWith(color: lum.g500),
                  ),
                ],
                const SizedBox(height: 3),
                Text(
                  '${branch.code}  ·  ${branch.currency}  ·  ${branch.timezone}',
                  style: AppTypography.monoValue.copyWith(
                    fontSize: 12,
                    color: lum.g400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppPill(
                label: branch.isActive ? 'Active' : 'Inactive',
                tone: branch.isActive
                    ? AppPillTone.success
                    : AppPillTone.neutral,
              ),
              if (canEdit) ...[
                const SizedBox(height: 8),
                Icon(LucideIcons.chevronRight, size: 20, color: lum.g300),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// The branch create/edit form shared by both sheets.
class _BranchForm extends StatelessWidget {
  const _BranchForm({
    required this.title,
    required this.subtitle,
    required this.name,
    required this.city,
    required this.country,
    required this.currency,
    required this.timezone,
    required this.isActive,
    required this.saving,
    required this.nameError,
    required this.saveLabel,
    required this.onNameChanged,
    required this.onCountry,
    required this.onCurrency,
    required this.onTimezone,
    required this.onActive,
    required this.onCancel,
    required this.onSave,
    this.error,
  });

  final String title;
  final String subtitle;
  final TextEditingController name;
  final TextEditingController city;
  final String country;
  final String currency;
  final String timezone;
  final bool isActive;
  final bool saving;
  final bool nameError;
  final String? error;
  final String saveLabel;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onCountry;
  final ValueChanged<String> onCurrency;
  final ValueChanged<String> onTimezone;
  final ValueChanged<bool> onActive;
  final VoidCallback onCancel;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSheetHeader(title: title, subtitle: subtitle),
        AppTextField(
          controller: name,
          label: 'Branch name',
          prefixIcon: LucideIcons.store,
          onChanged: onNameChanged,
          errorText: nameError ? 'A branch name is required.' : null,
        ),
        const SizedBox(height: AppSpacing.base),
        AppTextField(
          controller: city,
          label: 'City',
          prefixIcon: LucideIcons.building2,
        ),
        const SizedBox(height: AppSpacing.base),
        LayoutBuilder(
          builder: (context, constraints) {
            final countryField = _LabelledDropdown(
              label: 'Country',
              value: country,
              options: _countries,
              onSelected: onCountry,
            );
            final currencyField = _LabelledDropdown(
              label: 'Currency',
              value: currency,
              options: _currencies,
              onSelected: onCurrency,
            );
            if (constraints.maxWidth < 420) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  countryField,
                  const SizedBox(height: AppSpacing.base),
                  currencyField,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: countryField),
                const SizedBox(width: AppSpacing.base),
                Expanded(child: currencyField),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.base),
        _LabelledDropdown(
          label: 'Timezone',
          value: timezone,
          options: _timezones,
          onSelected: onTimezone,
        ),
        const SizedBox(height: AppSpacing.base),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: lum.surface2,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Active',
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: lum.textPrimary,
                      ),
                    ),
                    Text(
                      'Inactive branches are hidden from the POS.',
                      style: AppTypography.caption.copyWith(color: lum.g500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AppToggle(
                value: isActive,
                enabled: !saving,
                semanticLabel: 'Active',
                onChanged: onActive,
              ),
            ],
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.base),
          AppInlineBanner(message: error!, type: BannerType.error),
        ],
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Cancel',
                variant: AppButtonVariant.tinted,
                fullWidth: true,
                onPressed: saving ? null : onCancel,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton(
                label: saveLabel,
                loading: saving,
                fullWidth: true,
                onPressed: onSave,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LabelledDropdown extends StatelessWidget {
  const _LabelledDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final String value;
  final List<AppDropdownOption<String>> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            label,
            style: AppTypography.fieldLabel.copyWith(color: lum.g700),
          ),
        ),
        AppDropdown<String>(
          value: value,
          options: options,
          onSelected: onSelected,
        ),
      ],
    );
  }
}
