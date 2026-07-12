import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/tax_rule.dart';
import '../controllers/tax_rules_controller.dart';

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
  String? _error;

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

  Future<void> _pickDate(bool from) async {
    final initial =
        (from ? _effectiveFrom : _effectiveUntil) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _effectiveFrom = picked;
      } else {
        _effectiveUntil = picked;
      }
    });
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }
    final code = _code.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Code is required.');
      return;
    }
    final rate = double.tryParse(_rate.text.trim());
    if (rate == null || rate < 0) {
      setState(() => _error = 'Rate must be a non-negative number.');
      return;
    }
    final appliesTo = _appliesTo.text.trim();

    setState(() {
      _saving = true;
      _error = null;
    });

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
      setState(() {
        _saving = false;
        _error = failure.message;
      });
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEditing ? 'Tax rule updated' : 'Tax rule added')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing && !_seeded) {
      final existing = (ref.watch(taxRulesProvider).value ?? const [])
          .where((r) => r.id == widget.taxRuleId)
          .firstOrNull;
      if (existing != null) {
        _seed(existing);
        _seeded = true;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_isEditing ? 'Edit Tax Rule' : 'New Tax Rule',
            style: AppTypography.headline),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    if (_error != null) ...[
                      AppInlineBanner(
                          message: _error!, type: BannerType.error),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    AppTextField(
                      controller: _name,
                      label: 'Name',
                      prefixIcon: Icons.label,
                    ),
                    const SizedBox(height: AppSpacing.fieldGap),
                    AppTextField(
                      controller: _code,
                      label: 'Code',
                      prefixIcon: Icons.tag,
                    ),
                    const SizedBox(height: AppSpacing.fieldGap),
                    AppTextField(
                      controller: _rate,
                      label: 'Rate (%)',
                      prefixIcon: Icons.percent,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                    ),
                    const SizedBox(height: AppSpacing.fieldGap),
                    _group('Mode'),
                    _ModeDropdown(
                      value: _mode,
                      onChanged: (m) => setState(() => _mode = m),
                    ),
                    const SizedBox(height: AppSpacing.fieldGap),
                    AppTextField(
                      controller: _appliesTo,
                      label: 'Applies To',
                      prefixIcon: Icons.category,
                    ),
                    const SizedBox(height: AppSpacing.fieldGap),
                    AppTextField(
                      controller: _description,
                      label: 'Description',
                      prefixIcon: Icons.notes,
                      hint: 'Optional',
                    ),
                    const SizedBox(height: AppSpacing.fieldGap),
                    _group('Effective From'),
                    _DateTile(
                      date: _effectiveFrom,
                      hint: 'Optional',
                      onTap: () => _pickDate(true),
                      onClear: () =>
                          setState(() => _effectiveFrom = null),
                    ),
                    const SizedBox(height: AppSpacing.fieldGap),
                    _group('Effective Until'),
                    _DateTile(
                      date: _effectiveUntil,
                      hint: 'Optional',
                      onTap: () => _pickDate(false),
                      onClear: () =>
                          setState(() => _effectiveUntil = null),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: AppColors.accent,
                      title: Text('Default', style: AppTypography.subhead),
                      value: _isDefault,
                      onChanged: (v) => setState(() => _isDefault = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: AppColors.accent,
                      title: Text('Active', style: AppTypography.subhead),
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PermissionGate(
                      module: 'accounting',
                      action: _isEditing ? 'update' : 'create',
                      child: AppButton(
                        label: _isEditing ? 'Update' : 'Create',
                        loading: _saving,
                        fullWidth: true,
                        onPressed: _submit,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _group(String label) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(label.toUpperCase(),
            style: AppTypography.footnote.copyWith(
                color: AppColors.textMuted, fontWeight: FontWeight.w600)),
      );
}

class _ModeDropdown extends StatelessWidget {
  const _ModeDropdown({required this.value, required this.onChanged});
  final TaxMode value;
  final ValueChanged<TaxMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.separator),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<TaxMode>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down,
              size: 18, color: AppColors.textMuted),
          style: AppTypography.subhead,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          items: const [
            DropdownMenuItem(
                value: TaxMode.exclusive, child: Text('Exclusive')),
            DropdownMenuItem(
                value: TaxMode.inclusive, child: Text('Inclusive')),
          ],
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.date,
    required this.hint,
    required this.onTap,
    required this.onClear,
  });
  final DateTime? date;
  final String hint;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final label = date == null
        ? hint
        : '${date!.year}-${date!.month.toString().padLeft(2, '0')}'
            '-${date!.day.toString().padLeft(2, '0')}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.field),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(AppRadius.field),
          border: Border.all(color: AppColors.separator),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today,
                size: 18, color: AppColors.textMuted),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(label,
                  style: AppTypography.subhead.copyWith(
                      color: date == null
                          ? AppColors.textHint
                          : AppColors.textPrimary)),
            ),
            if (date != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close,
                    size: 18, color: AppColors.textHint),
              ),
          ],
        ),
      ),
    );
  }
}
