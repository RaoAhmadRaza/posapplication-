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
import '../../domain/entities/employee.dart';
import '../../data/models/employee_model.dart';
import '../controllers/employees_controller.dart';
import '../widgets/hr_status_ui.dart';

/// employee == null → create; otherwise edit. Create and edit differ: employee
/// code, branch, joining date and CNIC are set only at creation (the
/// update_employee RPC does not touch them).
class EmployeeFormPage extends ConsumerStatefulWidget {
  const EmployeeFormPage({super.key, this.employee});
  final Employee? employee;

  @override
  ConsumerState<EmployeeFormPage> createState() => _EmployeeFormPageState();
}

class _EmployeeFormPageState extends ConsumerState<EmployeeFormPage> {
  late final _codeCtrl = TextEditingController(text: _e?.employeeCode);
  late final _nameCtrl = TextEditingController(text: _e?.name);
  late final _cnicCtrl = TextEditingController(text: _e?.cnic);
  late final _phoneCtrl = TextEditingController(text: _e?.phone);
  late final _emailCtrl = TextEditingController(text: _e?.email);
  late final _addressCtrl = TextEditingController(text: _e?.address);
  late final _designationCtrl =
      TextEditingController(text: _e?.designation);
  late final _departmentCtrl = TextEditingController(text: _e?.department);
  late final _salaryCtrl =
      TextEditingController(text: _e == null ? '' : _e!.baseSalary.toString());
  late final _bankNameCtrl = TextEditingController(text: _e?.bankName);
  late final _bankAcctCtrl =
      TextEditingController(text: _e?.bankAccountNumber);
  late final _notesCtrl = TextEditingController(text: _e?.notes);

  late SalaryType _salaryType = _e?.salaryType ?? SalaryType.monthly;
  late EmployeeStatus _status = _e?.status ?? EmployeeStatus.active;
  late DateTime _joiningDate = _e?.joiningDate ?? DateTime.now();

  bool _saving = false;
  String? _error;

  Employee? get _e => widget.employee;
  bool get _isEdit => _e != null;

  @override
  void dispose() {
    for (final c in [
      _codeCtrl,
      _nameCtrl,
      _cnicCtrl,
      _phoneCtrl,
      _emailCtrl,
      _addressCtrl,
      _designationCtrl,
      _departmentCtrl,
      _salaryCtrl,
      _bankNameCtrl,
      _bankAcctCtrl,
      _notesCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  static String? _emptyToNull(String s) => s.trim().isEmpty ? null : s.trim();

  Future<void> _pickJoiningDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _joiningDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _joiningDate = picked);
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }
    final salary = double.tryParse(_salaryCtrl.text.trim());
    if (salary == null || salary < 0) {
      setState(() => _error = 'Enter a valid base salary.');
      return;
    }
    if (!_isEdit && _codeCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Employee code is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final controller = ref.read(employeesProvider.notifier);
    if (_isEdit) {
      final failure = await controller.updateEmployee(_e!.id, {
        'p_employee_id': _e!.id,
        'p_name': _nameCtrl.text.trim(),
        'p_phone': _emptyToNull(_phoneCtrl.text),
        'p_email': _emptyToNull(_emailCtrl.text),
        'p_address': _emptyToNull(_addressCtrl.text),
        'p_designation': _emptyToNull(_designationCtrl.text),
        'p_department': _emptyToNull(_departmentCtrl.text),
        'p_salary_type': EmployeeModel.salaryTypeToDb(_salaryType),
        'p_base_salary': salary,
        'p_bank_name': _emptyToNull(_bankNameCtrl.text),
        'p_bank_account_number': _emptyToNull(_bankAcctCtrl.text),
        'p_status': EmployeeModel.statusToDb(_status),
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
      _done('Employee updated');
      return;
    }

    final branch = ref.read(currentBranchProvider);
    if (branch == null) {
      setState(() {
        _saving = false;
        _error = 'No branch selected.';
      });
      return;
    }
    final (id, failure) = await controller.create({
      'p_branch_id': branch.id,
      'p_employee_code': _codeCtrl.text.trim(),
      'p_name': _nameCtrl.text.trim(),
      'p_cnic': _emptyToNull(_cnicCtrl.text),
      'p_phone': _emptyToNull(_phoneCtrl.text),
      'p_email': _emptyToNull(_emailCtrl.text),
      'p_address': _emptyToNull(_addressCtrl.text),
      'p_designation': _emptyToNull(_designationCtrl.text),
      'p_department': _emptyToNull(_departmentCtrl.text),
      'p_joining_date': _joiningDate.toIso8601String().substring(0, 10),
      'p_salary_type': EmployeeModel.salaryTypeToDb(_salaryType),
      'p_base_salary': salary,
      'p_bank_name': _emptyToNull(_bankNameCtrl.text),
      'p_bank_account_number': _emptyToNull(_bankAcctCtrl.text),
      'p_user_id': null,
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
    if (id != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Employee created')));
      context.go('/hr/employees/$id');
    } else {
      _done('Employee created');
    }
  }

  void _done(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
    context.pop();
  }

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
        title: Text(_isEdit ? 'Edit Employee' : 'New Employee',
            style: AppTypography.headline),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            _group('Personal'),
            if (!_isEdit) ...[
              AppTextField(
                  controller: _codeCtrl,
                  label: 'Employee Code',
                  prefixIcon: Icons.badge_outlined),
              const SizedBox(height: AppSpacing.md),
            ],
            AppTextField(
                controller: _nameCtrl,
                label: 'Name',
                prefixIcon: Icons.person_outline),
            if (!_isEdit) ...[
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                  controller: _cnicCtrl,
                  label: 'CNIC (optional)',
                  prefixIcon: Icons.credit_card),
            ],
            const SizedBox(height: AppSpacing.lg),
            _group('Contact'),
            AppTextField(
                controller: _phoneCtrl,
                label: 'Phone (optional)',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
                controller: _emailCtrl,
                label: 'Email (optional)',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
                controller: _addressCtrl,
                label: 'Address (optional)',
                prefixIcon: Icons.home_outlined),
            const SizedBox(height: AppSpacing.lg),
            _group('Employment'),
            AppTextField(
                controller: _designationCtrl,
                label: 'Designation (optional)',
                prefixIcon: Icons.work_outline),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
                controller: _departmentCtrl,
                label: 'Department (optional)',
                prefixIcon: Icons.apartment_outlined),
            if (!_isEdit) ...[
              const SizedBox(height: AppSpacing.md),
              _DateField(
                  label: 'Joining Date',
                  date: _joiningDate,
                  onTap: _pickJoiningDate),
            ],
            if (_isEdit) ...[
              const SizedBox(height: AppSpacing.md),
              _fieldLabel('Status'),
              const SizedBox(height: AppSpacing.xs),
              _StatusSelector(
                value: _status,
                onChanged: (s) => setState(() => _status = s),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            _group('Salary'),
            _fieldLabel('Salary Type'),
            const SizedBox(height: AppSpacing.xs),
            _SalaryTypeSelector(
              value: _salaryType,
              onChanged: (t) => setState(() => _salaryType = t),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
                controller: _salaryCtrl,
                label: 'Base Salary',
                prefixIcon: Icons.payments_outlined,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: AppSpacing.lg),
            _group('Bank'),
            AppTextField(
                controller: _bankNameCtrl,
                label: 'Bank Name (optional)',
                prefixIcon: Icons.account_balance_outlined),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
                controller: _bankAcctCtrl,
                label: 'Account Number (optional)',
                prefixIcon: Icons.tag),
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
              label: _isEdit ? 'Save Changes' : 'Create Employee',
              onPressed: _saving ? null : _submit,
              loading: _saving,
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _group(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(text.toUpperCase(),
            style: AppTypography.footnote.copyWith(
                color: AppColors.textMuted, fontWeight: FontWeight.w700)),
      );

  Widget _fieldLabel(String text) => Text(text,
      style: AppTypography.fieldLabel);
}

class _DateField extends StatelessWidget {
  const _DateField(
      {required this.label, required this.date, required this.onTap});
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = date.toIso8601String().substring(0, 10);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(label, style: AppTypography.fieldLabel),
        ),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.fieldFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    color: AppColors.textMuted, size: 20),
                const SizedBox(width: 10),
                Text(text, style: AppTypography.fieldText),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SalaryTypeSelector extends StatelessWidget {
  const _SalaryTypeSelector({required this.value, required this.onChanged});
  final SalaryType value;
  final ValueChanged<SalaryType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        for (final t in SalaryType.values)
          _Pill(
            label: salaryTypeLabels[t]!,
            selected: value == t,
            onTap: () => onChanged(t),
          ),
      ],
    );
  }
}

class _StatusSelector extends StatelessWidget {
  const _StatusSelector({required this.value, required this.onChanged});
  final EmployeeStatus value;
  final ValueChanged<EmployeeStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        for (final s in EmployeeStatus.values)
          _Pill(
            label: employeeStatusLabels[s]!,
            selected: value == s,
            onTap: () => onChanged(s),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent
              : AppColors.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: AppTypography.footnote.copyWith(
            color: selected ? Colors.white : AppColors.accent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
