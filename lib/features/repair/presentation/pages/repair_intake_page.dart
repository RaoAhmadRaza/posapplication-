import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../domain/entities/repair_job.dart';
import '../../data/models/repair_job_model.dart';
import '../controllers/repair_jobs_controller.dart';
import '../widgets/repair_customer_picker.dart';
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
        title: Text('New Repair Job', style: AppTypography.headline),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            _label('Customer'),
            const SizedBox(height: AppSpacing.xs),
            InkWell(
              onTap: _pickCustomer,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.base),
                decoration: BoxDecoration(
                  color: AppColors.fieldFill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.separator, width: 0.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline,
                        color: AppColors.textMuted),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        _customer?.name ?? 'Select customer',
                        style: AppTypography.body.copyWith(
                          color: _customer == null
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
                controller: _deviceTypeCtrl,
                label: 'Device Type',
                prefixIcon: Icons.devices_other,
                hint: 'e.g. Smartphone, Laptop'),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
                controller: _brandCtrl,
                label: 'Brand (optional)',
                prefixIcon: Icons.branding_watermark_outlined),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
                controller: _modelCtrl,
                label: 'Model (optional)',
                prefixIcon: Icons.phone_iphone),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
                controller: _serialCtrl,
                label: 'Serial No. (optional)',
                prefixIcon: Icons.tag),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
                controller: _imeiCtrl,
                label: 'IMEI (optional)',
                prefixIcon: Icons.qr_code),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
                controller: _issueCtrl,
                label: 'Reported Issue',
                prefixIcon: Icons.report_problem_outlined),
            const SizedBox(height: AppSpacing.md),
            _label('Priority'),
            const SizedBox(height: AppSpacing.xs),
            _PrioritySelector(
              value: _priority,
              onChanged: (p) => setState(() => _priority = p),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
                controller: _estimateCtrl,
                label: 'Estimated Cost (optional)',
                prefixIcon: Icons.attach_money,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: AppSpacing.md),
            // ponytail: signature captured as a URL only; on-device capture pad
            // deferred until a repair signature widget is requested.
            AppTextField(
                controller: _signatureCtrl,
                label: 'Signature URL (optional)',
                prefixIcon: Icons.draw_outlined),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
                controller: _notesCtrl,
                label: 'Notes (optional)',
                prefixIcon: Icons.notes),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppInlineBanner(message: _error!, type: BannerType.error),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Create Job',
              onPressed: _saving ? null : _submit,
              loading: _saving,
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: AppTypography.footnote.copyWith(
          color: AppColors.textMuted, fontWeight: FontWeight.w600));
}

class _PrioritySelector extends StatelessWidget {
  const _PrioritySelector({required this.value, required this.onChanged});
  final RepairPriority value;
  final ValueChanged<RepairPriority> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        for (final p in RepairPriority.values)
          GestureDetector(
            onTap: () => onChanged(p),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.base, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: value == p
                    ? repairPriorityColor(p)
                    : repairPriorityColor(p).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                repairPriorityLabels[p]!,
                style: AppTypography.footnote.copyWith(
                  color: value == p ? Colors.white : repairPriorityColor(p),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
