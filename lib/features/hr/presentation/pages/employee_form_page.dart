import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_checkbox.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_field.dart';
import '../../../../core/design/widgets/app_filter_chips.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_section_card.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/widgets/permission_gate.dart';
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
  bool _createLogin = false;
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

  /// The fields the form marks with a red asterisk — checked in one place so
  /// the labels and the guards cannot drift apart. Keeps the numeric parse: an
  /// unparseable salary would otherwise reach coalesce(p_base_salary, 0) and
  /// create the employee on zero pay with a success toast.
  String? _requiredFieldError() {
    if (_nameCtrl.text.trim().isEmpty) return 'Name is required.';
    final salary = double.tryParse(_salaryCtrl.text.trim());
    if (salary == null || salary < 0) return 'Enter a valid base salary.';
    if (!_isEdit && _codeCtrl.text.trim().isEmpty) {
      return 'Employee code is required.';
    }
    return null;
  }

  Future<void> _submit() async {
    final invalid = _requiredFieldError();
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    // Guaranteed to parse by _requiredFieldError above.
    final salary = double.parse(_salaryCtrl.text.trim());

    // Resolved before the saving flip so a missing branch surfaces the error
    // without flashing the button's spinner.
    final branchId = _isEdit ? null : ref.read(currentBranchProvider)?.id;
    if (!_isEdit && branchId == null) {
      setState(() => _error = 'No branch selected.');
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

    final (id, failure) = await controller.create({
      'p_branch_id': branchId,
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
      // Router captured first: go() can dispose this widget's context before
      // the push runs. go-then-push (not pushReplacement) so backing out of the
      // invite lands on the new employee's profile — where "Create login" still
      // waits — rather than on a spent form that could create a second record.
      final router = GoRouter.of(context);
      showAppToast(context, 'Employee created', type: BannerType.success);
      router.go('/hr/employees/$id');
      if (_createLogin) {
        router.push('/staff/invite', extra: {
          'employeeId': id,
          'name': _nameCtrl.text.trim(),
          'email': _emptyToNull(_emailCtrl.text),
          'branchId': branchId,
        });
      }
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
      description: _isEdit
          ? 'Fields marked * are required.'
          : 'Fields marked * are required. New employees are added to the '
              'current branch.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Employee code, CNIC and joining date stay create-only: the
          // update_employee RPC has no parameter for any of them, so an
          // editable field here would discard the edit and still toast success.
          AppSectionCard(
            eyebrow: 'Basic info',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isEdit) ...[
                  _labeled(
                    'Status',
                    _StatusSelector(
                      value: _status,
                      onChanged: (s) => setState(() => _status = s),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.fieldGap),
                ],
                AppFieldRow(children: [
                  AppTextField(
                    controller: _nameCtrl,
                    label: 'Full name',
                    isRequired: true,
                    prefixIcon: LucideIcons.user,
                  ),
                  if (!_isEdit)
                    AppTextField(
                      controller: _codeCtrl,
                      label: 'Employee code',
                      isRequired: true,
                      prefixIcon: LucideIcons.hash,
                    ),
                ]),
                const SizedBox(height: AppSpacing.fieldGap),
                AppFieldRow(children: [
                  AppTextField(
                    controller: _phoneCtrl,
                    label: 'Phone',
                    hint: 'Optional',
                    prefixIcon: LucideIcons.phone,
                    keyboardType: TextInputType.phone,
                  ),
                  AppTextField(
                    controller: _emailCtrl,
                    label: 'Email',
                    hint: 'Optional',
                    prefixIcon: LucideIcons.mail,
                    keyboardType: TextInputType.emailAddress,
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            eyebrow: 'Role & pay',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppFieldRow(children: [
                  AppTextField(
                    controller: _designationCtrl,
                    label: 'Designation',
                    hint: 'Optional',
                    prefixIcon: LucideIcons.briefcase,
                  ),
                  AppTextField(
                    controller: _departmentCtrl,
                    label: 'Department',
                    hint: 'Optional',
                    prefixIcon: LucideIcons.building2,
                  ),
                ]),
                const SizedBox(height: AppSpacing.fieldGap),
                if (!_isEdit) ...[
                  _labeled(
                    'Joining date',
                    _DateWell(date: _joiningDate, onTap: _pickJoiningDate),
                  ),
                  const SizedBox(height: AppSpacing.fieldGap),
                ],
                _labeled(
                  'Salary type',
                  _SalaryTypeSelector(
                    value: _salaryType,
                    onChanged: (t) => setState(() => _salaryType = t),
                  ),
                ),
                const SizedBox(height: AppSpacing.fieldGap),
                AppTextField(
                  controller: _salaryCtrl,
                  label: 'Base salary',
                  isRequired: true,
                  prefixIcon: LucideIcons.wallet,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            eyebrow: 'Additional details',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppFieldRow(children: [
                  if (!_isEdit)
                    AppTextField(
                      controller: _cnicCtrl,
                      label: 'CNIC',
                      hint: 'Optional',
                      prefixIcon: LucideIcons.fingerprint,
                    ),
                  AppTextField(
                    controller: _addressCtrl,
                    label: 'Address',
                    hint: 'Optional',
                    prefixIcon: LucideIcons.mapPin,
                  ),
                ]),
                const SizedBox(height: AppSpacing.fieldGap),
                AppFieldRow(children: [
                  AppTextField(
                    controller: _bankNameCtrl,
                    label: 'Bank name',
                    hint: 'Optional',
                    prefixIcon: LucideIcons.landmark,
                  ),
                  AppTextField(
                    controller: _bankAcctCtrl,
                    label: 'Account number',
                    hint: 'Optional',
                    prefixIcon: LucideIcons.creditCard,
                  ),
                ]),
                const SizedBox(height: AppSpacing.fieldGap),
                AppTextField(
                  controller: _notesCtrl,
                  label: 'Notes',
                  hint: 'Optional',
                  prefixIcon: LucideIcons.stickyNote,
                  maxLines: 4,
                ),
              ],
            ),
          ),
          // Outside the section cards: this changes what Save *does*, it is not
          // part of the employee record. Gated on users:create (the Staff
          // module's key, as on the profile's "Create login"), with the spacing
          // inside the gate so hiding it leaves no orphan gap.
          if (!_isEdit)
            PermissionGate(
              module: 'users',
              action: 'create',
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppCheckbox(
                      value: _createLogin,
                      onChanged: (v) => setState(() => _createLogin = v),
                      label: 'Also create an app login for this employee',
                    ),
                    if (_createLogin && _emailCtrl.text.trim().isEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'No email yet — you’ll get a QR code to share instead.',
                        style: AppTypography.footnote
                            .copyWith(color: context.lum.g500),
                      ),
                    ],
                  ],
                ),
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

  /// Label above a non-[AppTextField] control (date well, chip row) — the same
  /// shape the product and purchase-order forms use.
  Widget _labeled(String label, Widget child, {bool isRequired = false}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [AppFieldLabel(label, isRequired: isRequired), child],
      );
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
