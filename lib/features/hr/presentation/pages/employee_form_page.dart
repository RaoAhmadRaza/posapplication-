import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_filter_chips.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_section_card.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/employee.dart';
import '../../data/models/employee_model.dart';
import '../controllers/employees_controller.dart';
import '../widgets/hr_ui.dart';

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
      showAppToast(context, 'Employee created', type: BannerType.success);
      context.go('/hr/employees/$id');
    } else {
      _done('Employee created');
    }
  }

  void _done(String msg) {
    showAppToast(context, msg, type: BannerType.success);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AppDetailScaffold(
      eyebrow: 'HR · Employees',
      title: _isEdit ? 'Edit Employee' : 'New Employee',
      description:
          'Fields marked * are required. New employees are added to the '
          'current branch.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isEdit) ...[
            AppSectionCard(
              eyebrow: 'Status',
              child: _StatusSelector(
                value: _status,
                onChanged: (s) => setState(() => _status = s),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (!_isEdit) ...[
            AppSectionCard(
              eyebrow: 'Identity',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _grid([
                    AppTextField(
                      controller: _codeCtrl,
                      label: 'Employee code',
                      prefixIcon: LucideIcons.hash,
                    ),
                    AppTextField(
                      controller: _cnicCtrl,
                      label: 'CNIC',
                      prefixIcon: LucideIcons.fingerprint,
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _LabelledField(
                    label: 'Joining date',
                    child: _DateWell(
                      date: _joiningDate,
                      onTap: _pickJoiningDate,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          AppSectionCard(
            eyebrow: 'Personal & contact',
            child: _grid([
              AppTextField(
                controller: _nameCtrl,
                label: 'Full name *',
                prefixIcon: LucideIcons.user,
              ),
              AppTextField(
                controller: _phoneCtrl,
                label: 'Phone',
                prefixIcon: LucideIcons.phone,
                keyboardType: TextInputType.phone,
              ),
              AppTextField(
                controller: _emailCtrl,
                label: 'Email',
                prefixIcon: LucideIcons.mail,
                keyboardType: TextInputType.emailAddress,
              ),
              AppTextField(
                controller: _addressCtrl,
                label: 'Address',
                prefixIcon: LucideIcons.mapPin,
              ),
            ]),
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            eyebrow: 'Role & pay',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _grid([
                  AppTextField(
                    controller: _designationCtrl,
                    label: 'Designation',
                    prefixIcon: LucideIcons.briefcase,
                  ),
                  AppTextField(
                    controller: _departmentCtrl,
                    label: 'Department',
                    prefixIcon: LucideIcons.building2,
                  ),
                ]),
                const SizedBox(height: 14),
                _LabelledField(
                  label: 'Salary type',
                  child: _SalaryTypeSelector(
                    value: _salaryType,
                    onChanged: (t) => setState(() => _salaryType = t),
                  ),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _salaryCtrl,
                  label: 'Base salary *',
                  prefixIcon: LucideIcons.wallet,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            eyebrow: 'Bank & notes',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _grid([
                  AppTextField(
                    controller: _bankNameCtrl,
                    label: 'Bank name',
                    prefixIcon: LucideIcons.landmark,
                  ),
                  AppTextField(
                    controller: _bankAcctCtrl,
                    label: 'Account number',
                    prefixIcon: LucideIcons.creditCard,
                  ),
                ]),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _notesCtrl,
                  label: 'Notes',
                  prefixIcon: LucideIcons.stickyNote,
                  maxLines: 4,
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            AppInlineBanner(message: _error!, type: BannerType.error),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppButton(
                label: 'Cancel',
                variant: AppButtonVariant.plain,
                onPressed:
                    _saving ? null : () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 10),
              AppButton(
                label: _isEdit ? 'Save Changes' : 'Create Employee',
                onPressed: _saving ? null : _submit,
                loading: _saving,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Responsive two-up field grid: side-by-side when wide enough, else stacked.
  Widget _grid(List<Widget> fields) => LayoutBuilder(
        builder: (context, constraints) {
          const gap = 14.0;
          final twoCol = constraints.maxWidth >= 440;
          final width =
              twoCol ? (constraints.maxWidth - gap) / 2 : constraints.maxWidth;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final f in fields) SizedBox(width: width, child: f),
            ],
          );
        },
      );
}

/// Field label above a non-[AppTextField] control (date well, pill row).
class _LabelledField extends StatelessWidget {
  const _LabelledField({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            label,
            style: AppTypography.fieldLabel.copyWith(color: lum.g700),
          ),
        ),
        child,
      ],
    );
  }
}

/// Clay-inset date tile opening the platform picker; mirrors [AppTextField]'s
/// well so the joining date reads as another field.
class _DateWell extends StatelessWidget {
  const _DateWell({required this.date, required this.onTap});
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final text = date.toIso8601String().substring(0, 10);
    return Semantics(
      button: true,
      label: 'Joining date $text',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ClayContainer(
          variant: ClayVariant.inset,
          color: lum.surface2,
          borderRadius: AppRadius.md,
          isDark: lum.isDark,
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(LucideIcons.calendar, size: 18, color: lum.g400),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style:
                      AppTypography.fieldText.copyWith(color: lum.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
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
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final t in SalaryType.values)
          SizedBox(
            height: 36,
            child: AppFilterChip(
              label: salaryTypeLabels[t]!,
              active: value == t,
              onTap: () => onChanged(t),
            ),
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
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in EmployeeStatus.values)
          SizedBox(
            height: 36,
            child: AppFilterChip(
              label: employeeStatusLabels[s]!,
              active: value == s,
              onTap: () => onChanged(s),
            ),
          ),
      ],
    );
  }
}
