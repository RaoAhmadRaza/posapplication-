import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_dropdown.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/design/widgets/app_toggle.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/tax_rule.dart';
import '../controllers/tax_rules_controller.dart';
import '../widgets/acct_date_field.dart';

class TaxRuleFormPage extends ConsumerStatefulWidget {
  const TaxRuleFormPage({super.key, this.taxRuleId});

  final String? taxRuleId;

  @override
  ConsumerState<TaxRuleFormPage> createState() => _TaxRuleFormPageState();
}

class _TaxRuleFormPageState extends ConsumerState<TaxRuleFormPage> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _rate = TextEditingController(text: '0');
  final _appliesTo = TextEditingController(text: 'ALL');
  final _description = TextEditingController();
  TaxMode _mode = TaxMode.exclusive;
  bool _isDefault = false;
  bool _isActive = true;
  DateTime? _effectiveFrom;
  DateTime? _effectiveUntil;

  bool _saving = false;
  bool _seeded = false;

  bool get _isEditing => widget.taxRuleId != null;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _rate.dispose();
    _appliesTo.dispose();
    _description.dispose();
    super.dispose();
  }

  void _seed(TaxRule r) {
    _name.text = r.name;
    _code.text = r.code ?? '';
    _rate.text = r.rate.toString();
    _appliesTo.text = r.appliesTo ?? 'ALL';
    _description.text = r.description ?? '';
    _mode = r.mode;
    _isDefault = r.isDefault;
    _isActive = r.isActive;
    _effectiveFrom = r.effectiveFrom;
    _effectiveUntil = r.effectiveUntil;
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showAppToast(context, 'Name is required.', type: BannerType.error);
      return;
    }
    final code = _code.text.trim();
    if (code.isEmpty) {
      showAppToast(context, 'Code is required.', type: BannerType.error);
      return;
    }
    final rate = double.tryParse(_rate.text.trim());
    if (rate == null || rate < 0) {
      showAppToast(context, 'Rate must be a non-negative number.',
          type: BannerType.error);
      return;
    }
    final appliesTo = _appliesTo.text.trim();

    setState(() => _saving = true);

    final notifier = ref.read(taxRulesProvider.notifier);
    final description = _description.text.trim();
    final failure = _isEditing
        ? await notifier.edit(
            widget.taxRuleId!,
            name: name,
            code: code,
            rate: rate,
            mode: _mode,
            isDefault: _isDefault,
            appliesTo: appliesTo.isEmpty ? 'ALL' : appliesTo,
            description: description.isEmpty ? null : description,
            isActive: _isActive,
            effectiveFrom: _effectiveFrom,
            effectiveUntil: _effectiveUntil,
          )
        : await notifier.create(
            name: name,
            code: code,
            rate: rate,
            mode: _mode,
            isDefault: _isDefault,
            appliesTo: appliesTo.isEmpty ? 'ALL' : appliesTo,
            description: description.isEmpty ? null : description,
            isActive: _isActive,
            effectiveFrom: _effectiveFrom,
            effectiveUntil: _effectiveUntil,
          );

    if (!mounted) return;
    if (failure != null) {
      setState(() => _saving = false);
      showAppToast(context, failure.message, type: BannerType.error);
      return;
    }
    showAppToast(context, _isEditing ? 'Tax rule updated' : 'Tax rule added',
        type: BannerType.success);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;

    if (_isEditing && !_seeded) {
      final existing = (ref.watch(taxRulesProvider).value ?? const [])
          .where((r) => r.id == widget.taxRuleId)
          .firstOrNull;
      if (existing != null) {
        _seed(existing);
        _seeded = true;
      }
    }

    return AppDetailScaffold(
      eyebrow: 'Accounting',
      title: _isEditing ? 'Edit tax rule' : 'New tax rule',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 520;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _row(
                      wide,
                      AppTextField(
                        controller: _name,
                        label: 'Name',
                        prefixIcon: LucideIcons.tag,
                      ),
                      AppTextField(
                        controller: _code,
                        label: 'Code',
                        prefixIcon: LucideIcons.hash,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _row(
                      wide,
                      AppTextField(
                        controller: _rate,
                        label: 'Rate (%)',
                        prefixIcon: LucideIcons.percent,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                      _labeled(
                        lum,
                        'Mode',
                        AppDropdown<TaxMode>(
                          value: _mode,
                          options: const [
                            AppDropdownOption(
                                value: TaxMode.exclusive, label: 'Exclusive'),
                            AppDropdownOption(
                                value: TaxMode.inclusive, label: 'Inclusive'),
                          ],
                          onSelected: (m) => setState(() => _mode = m),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _row(
                      wide,
                      AppTextField(
                        controller: _appliesTo,
                        label: 'Applies to',
                        prefixIcon: LucideIcons.filter,
                      ),
                      _labeled(
                        lum,
                        'Effective from',
                        AcctDateField(
                          value: _effectiveFrom,
                          onChanged: (v) =>
                              setState(() => _effectiveFrom = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _row(
                      wide,
                      _labeled(
                        lum,
                        'Effective until',
                        AcctDateField(
                          value: _effectiveUntil,
                          onChanged: (v) =>
                              setState(() => _effectiveUntil = v),
                          clearable: true,
                        ),
                      ),
                      AppTextField(
                        controller: _description,
                        label: 'Description',
                        prefixIcon: LucideIcons.pencil,
                        hint: 'Optional',
                      ),
                    ),
                    const SizedBox(height: 22),
                    _toggleRow(
                      lum,
                      'Default rule',
                      'Apply automatically to new items',
                      _isDefault,
                      (v) => setState(() => _isDefault = v),
                    ),
                    const SizedBox(height: 16),
                    _toggleRow(
                      lum,
                      'Active',
                      'Available for selection',
                      _isActive,
                      (v) => setState(() => _isActive = v),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          PermissionGate(
            module: 'accounting',
            action: _isEditing ? 'update' : 'create',
            child: AppButton(
              label: _isEditing ? 'Update rule' : 'Create rule',
              icon: LucideIcons.check,
              loading: _saving,
              fullWidth: true,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(bool wide, Widget a, Widget b) => wide
      ? Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: a),
            const SizedBox(width: 14),
            Expanded(child: b),
          ],
        )
      : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [a, const SizedBox(height: 16), b],
        );

  Widget _labeled(LumColors lum, String label, Widget control) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(label,
                style: AppTypography.fieldLabel.copyWith(color: lum.g700)),
          ),
          control,
        ],
      );

  Widget _toggleRow(
    LumColors lum,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) =>
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTypography.headline
                        .copyWith(fontSize: 14.5, color: lum.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: AppTypography.subhead.copyWith(color: lum.g500)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          AppToggle(
            value: value,
            onChanged: onChanged,
            semanticLabel: title,
          ),
        ],
      );
}
