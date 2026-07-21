import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_motion.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_money_field.dart';
import '../../../../core/design/widgets/app_section_card.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/widgets/module_scaffold.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../domain/entities/repair_job.dart';
import '../../data/models/repair_job_model.dart';
import '../controllers/repair_jobs_controller.dart';
import '../widgets/repair_customer_picker.dart';
import '../widgets/repair_job_card.dart';
import '../widgets/repair_status_ui.dart';

class RepairIntakePage extends ConsumerStatefulWidget {
  const RepairIntakePage({super.key});

  @override
  ConsumerState<RepairIntakePage> createState() => _RepairIntakePageState();
}

class _RepairIntakePageState extends ConsumerState<RepairIntakePage> {
  final _deviceTypeCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _serialCtrl = TextEditingController();
  final _imeiCtrl = TextEditingController();
  final _issueCtrl = TextEditingController();
  final _estimateCtrl = TextEditingController();
  final _signatureCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  Customer? _customer;
  RepairPriority _priority = RepairPriority.normal;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _deviceTypeCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _serialCtrl.dispose();
    _imeiCtrl.dispose();
    _issueCtrl.dispose();
    _estimateCtrl.dispose();
    _signatureCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCustomer() async {
    final c = await showRepairCustomerPicker(context);
    if (c != null) setState(() => _customer = c);
  }

  /// The three inputs the submit path insists on; gates the primary button so
  /// the failure is visible before the tap rather than after it.
  bool get _canSubmit =>
      _customer != null &&
      _deviceTypeCtrl.text.trim().isNotEmpty &&
      _issueCtrl.text.trim().isNotEmpty;

  Future<void> _submit() async {
    final branch = ref.read(currentBranchProvider);
    if (branch == null) {
      setState(() => _error = 'No branch selected.');
      return;
    }
    if (_customer == null) {
      setState(() => _error = 'Select a customer.');
      return;
    }
    if (_deviceTypeCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Device type is required.');
      return;
    }
    if (_issueCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Reported issue is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final (result, failure) =
        await ref.read(repairJobsProvider.notifier).create({
      'p_branch_id': branch.id,
      'p_customer_id': _customer!.id,
      'p_device_type': _deviceTypeCtrl.text.trim(),
      'p_device_brand': _emptyToNull(_brandCtrl.text),
      'p_device_model': _emptyToNull(_modelCtrl.text),
      'p_serial_no': _emptyToNull(_serialCtrl.text),
      'p_imei': _emptyToNull(_imeiCtrl.text),
      'p_reported_issue': _issueCtrl.text.trim(),
      'p_priority': RepairJobModel.priorityToDb(_priority),
      'p_estimated_cost': double.tryParse(_estimateCtrl.text.trim()),
      'p_signature_url': _emptyToNull(_signatureCtrl.text),
      'p_notes': _emptyToNull(_notesCtrl.text),
    });
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _saving = false;
        _error = failure.message;
      });
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Job ${result!.jobNumber} created')),
    );
    context.go('/repair/${result.repairId}');
  }

  static String? _emptyToNull(String s) => s.trim().isEmpty ? null : s.trim();

  @override
  Widget build(BuildContext context) {
    final isWide = ModuleScaffold.isWideOf(context);

    return ModuleScaffold(
      title: 'New Repair Job',
      leading: _BackButton(onTap: () => Navigator.of(context).maybePop()),
      maxContentWidth: 620,
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 28 : 16,
        vertical: isWide ? 24 : 16,
      ),
      child: ListView(
        children: [
          _FieldLabel(text: 'Customer'),
          _CustomerControl(customer: _customer, onPick: _pickCustomer),
          const SizedBox(height: 16),
          AppSectionCard(
            eyebrow: 'Device',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: _deviceTypeCtrl,
                  label: 'Device type',
                  prefixIcon: LucideIcons.smartphone,
                  hint: 'e.g. Smartphone, Laptop',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _brandCtrl,
                  label: 'Brand (optional)',
                  prefixIcon: LucideIcons.tag,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _modelCtrl,
                  label: 'Model (optional)',
                  prefixIcon: LucideIcons.cpu,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _serialCtrl,
                  label: 'Serial no. (optional)',
                  prefixIcon: LucideIcons.hash,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _imeiCtrl,
                  label: 'IMEI (optional)',
                  prefixIcon: LucideIcons.barcode,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            eyebrow: 'Issue',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MultilineField(
                  controller: _issueCtrl,
                  label: 'Reported issue',
                  hint: 'What the customer reports',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                _FieldLabel(text: 'Priority'),
                _PrioritySelector(
                  value: _priority,
                  onChanged: (p) => setState(() => _priority = p),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            eyebrow: 'Estimate & notes',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppMoneyField(
                  controller: _estimateCtrl,
                  label: 'Estimated cost (optional)',
                ),
                const SizedBox(height: 16),
                // ponytail: signature captured as a URL only; on-device capture
                // pad deferred until a repair signature widget is requested.
                AppTextField(
                  controller: _signatureCtrl,
                  label: 'Signature URL (optional)',
                  prefixIcon: LucideIcons.penLine,
                ),
                const SizedBox(height: 16),
                _MultilineField(
                  controller: _notesCtrl,
                  label: 'Notes (optional)',
                  hint: 'Anything the technician should know',
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            AppInlineBanner(message: _error!, type: BannerType.error),
          ],
          const SizedBox(height: 20),
          _Footer(
            isWide: isWide,
            saving: _saving,
            canSubmit: _canSubmit,
            onCancel: () => Navigator.of(context).maybePop(),
            onSubmit: _submit,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Cancel + Create job: side by side on wide, primary stacked on top of the
/// secondary (column-reverse) on narrow.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.isWide,
    required this.saving,
    required this.canSubmit,
    required this.onCancel,
    required this.onSubmit,
  });

  final bool isWide;
  final bool saving;
  final bool canSubmit;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final cancel = AppButton(
      label: 'Cancel',
      variant: AppButtonVariant.tinted,
      fullWidth: !isWide,
      onPressed: saving ? null : onCancel,
    );
    final create = AppButton(
      label: 'Create job',
      icon: LucideIcons.check,
      loading: saving,
      fullWidth: !isWide,
      onPressed: canSubmit && !saving ? onSubmit : null,
    );

    if (isWide) {
      return Row(
        children: [
          Expanded(child: cancel),
          const SizedBox(width: 12),
          Expanded(child: create),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [create, const SizedBox(height: 12), cancel],
    );
  }
}

/// The design's field label: 13/w600, g700, 8px above its control.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 8),
        child: Text(
          text,
          style: AppTypography.fieldLabel.copyWith(color: context.lum.g700),
        ),
      );
}

/// Empty → a full-width inset "Select a customer" well. Picked → a soft clay
/// tile with the customer's initials, name and a ghost Change button.
class _CustomerControl extends StatelessWidget {
  const _CustomerControl({required this.customer, required this.onPick});

  final Customer? customer;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final picked = customer;

    if (picked == null) {
      return Semantics(
        button: true,
        label: 'Select a customer',
        child: InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: ClayContainer(
            variant: ClayVariant.inset,
            color: lum.surface2,
            borderRadius: AppRadius.md,
            isDark: lum.isDark,
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(LucideIcons.userPlus, size: 18, color: lum.g400),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Select a customer',
                    style: AppTypography.fieldText.copyWith(color: lum.g500),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ClayContainer(
      variant: ClayVariant.soft,
      color: lum.surface,
      borderRadius: AppRadius.md,
      isDark: lum.isDark,
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          RepairTechAvatar(name: picked.name, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              picked.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label.copyWith(
                fontSize: 15,
                color: lum.textPrimary,
              ),
            ),
          ),
          AppButton(
            label: 'Change',
            variant: AppButtonVariant.plain,
            size: AppButtonSize.sm,
            onPressed: onPick,
          ),
        ],
      ),
    );
  }
}

/// Four equal 44-high priority chips. Selected reads as an accent-soft pill
/// inside an accent ring; the rest sit in inset wells.
class _PrioritySelector extends StatelessWidget {
  const _PrioritySelector({required this.value, required this.onChanged});

  final RepairPriority value;
  final ValueChanged<RepairPriority> onChanged;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Row(
      children: [
        for (final p in RepairPriority.values) ...[
          if (p != RepairPriority.values.first) const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              button: true,
              selected: value == p,
              label: '${repairPriorityLabels[p]!} priority',
              child: InkWell(
                onTap: () => onChanged(p),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: value == p
                    ? Container(
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: lum.accentSoft,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(color: lum.accent, width: 1.5),
                        ),
                        child: _chipLabel(p, lum.accentPress),
                      )
                    : ClayContainer(
                        variant: ClayVariant.inset,
                        color: lum.surface2,
                        borderRadius: AppRadius.sm,
                        isDark: lum.isDark,
                        height: 44,
                        child: Center(child: _chipLabel(p, lum.g600)),
                      ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _chipLabel(RepairPriority p, Color color) => Text(
        repairPriorityLabels[p]!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.label.copyWith(fontSize: 13.5, color: color),
      );
}

/// Multi-line twin of [AppTextField] — same label + well, no leading icon.
/// Local because the shared field is single-line by contract.
class _MultilineField extends StatefulWidget {
  const _MultilineField({
    required this.controller,
    required this.label,
    this.hint,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final ValueChanged<String>? onChanged;

  @override
  State<_MultilineField> createState() => _MultilineFieldState();
}

class _MultilineFieldState extends State<_MultilineField> {
  late final FocusNode _focus = FocusNode()..addListener(() => setState(() {}));

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final focused = _focus.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(text: widget.label),
        AnimatedContainer(
          duration: AppMotion.fast,
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: focused ? lum.surface : lum.surface2,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: focused ? lum.accent : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            minLines: 3,
            maxLines: 6,
            keyboardType: TextInputType.multiline,
            onChanged: widget.onChanged,
            cursorColor: lum.accent,
            style: AppTypography.fieldText.copyWith(color: lum.textPrimary),
            decoration: InputDecoration(
              isCollapsed: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintText: widget.hint,
              hintStyle:
                  AppTypography.fieldHint.copyWith(color: lum.textTertiary),
            ),
          ),
        ),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Semantics(
      button: true,
      label: 'Back',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: SizedBox(
          width: 40,
          height: 44,
          child: Icon(LucideIcons.arrowLeft, size: 20, color: lum.g600),
        ),
      ),
    );
  }
}
