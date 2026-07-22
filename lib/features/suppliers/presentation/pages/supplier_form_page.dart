import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_dropdown.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/widgets/module_scaffold.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/usecases/load_supplier.dart';
import '../../data/models/supplier_model.dart';
import '../controllers/suppliers_controller.dart';

const _statusLabels = {
  SupplierStatus.active: 'Active',
  SupplierStatus.inactive: 'Inactive',
  SupplierStatus.blacklisted: 'Blacklisted',
};

class SupplierFormPage extends ConsumerStatefulWidget {
  const SupplierFormPage({super.key, this.supplierId});

  final String? supplierId;

  @override
  ConsumerState<SupplierFormPage> createState() => _SupplierFormPageState();
}

class _SupplierFormPageState extends ConsumerState<SupplierFormPage> {
  final _name = TextEditingController();
  final _contactPerson = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address1 = TextEditingController();
  final _address2 = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _postalCode = TextEditingController();
  final _country = TextEditingController(text: 'Pakistan');
  final _taxNumber = TextEditingController();
  final _paymentTerms = TextEditingController(text: '30');
  final _currency = TextEditingController(text: 'PKR');
  final _bankName = TextEditingController();
  final _bankAccount = TextEditingController();
  final _openingBalance = TextEditingController(text: '0');
  final _tags = TextEditingController();
  final _notes = TextEditingController();
  SupplierStatus _status = SupplierStatus.active;

  String? _error;
  bool _saving = false;
  bool _loadingExisting = false;

  /// Per-field messages, so the design's inline errors can sit on the field
  /// that is actually wrong rather than only in the banner.
  final _fieldErrors = <String, String>{};

  bool get _isEditing => widget.supplierId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadExisting();
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _contactPerson,
      _phone,
      _email,
      _address1,
      _address2,
      _city,
      _state,
      _postalCode,
      _country,
      _taxNumber,
      _paymentTerms,
      _currency,
      _bankName,
      _bankAccount,
      _openingBalance,
      _tags,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExisting() async {
    setState(() => _loadingExisting = true);
    final (supplier, failure) = await ref
        .read(loadSupplierUseCaseProvider)
        .call(widget.supplierId!);
    if (!mounted) return;
    if (supplier != null) _seed(supplier);
    setState(() {
      _loadingExisting = false;
      if (failure != null) _error = failure.message;
    });
  }

  void _seed(Supplier s) {
    _name.text = s.name;
    _contactPerson.text = s.contactPerson ?? '';
    _phone.text = s.phone ?? '';
    _email.text = s.email ?? '';
    _address1.text = s.addressLine1 ?? '';
    _address2.text = s.addressLine2 ?? '';
    _city.text = s.city ?? '';
    _state.text = s.state ?? '';
    _postalCode.text = s.postalCode ?? '';
    _country.text = s.country ?? '';
    _taxNumber.text = s.taxNumber ?? '';
    _paymentTerms.text = s.paymentTerms.toString();
    _currency.text = s.currency;
    _bankName.text = s.bankName ?? '';
    _bankAccount.text = s.bankAccountNumber ?? '';
    _openingBalance.text = s.openingBalance.toString();
    _tags.text = (s.tags ?? []).join(', ');
    _notes.text = s.notes ?? '';
    _status = s.status;
  }

  String? _clean(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _save() async {
    final errors = <String, String>{};
    final name = _name.text.trim();
    if (name.isEmpty) errors['name'] = 'Enter a supplier name.';

    final terms = int.tryParse(_paymentTerms.text.trim());
    if (terms == null || terms < 0) {
      errors['terms'] = 'Whole number of days, 0 or more.';
    }
    final opening = double.tryParse(_openingBalance.text.trim());
    if (opening == null) errors['opening'] = 'Enter a number.';

    final currency = _currency.text.trim();
    if (currency.isEmpty) errors['currency'] = 'Currency is required.';

    if (errors.isNotEmpty) {
      setState(() {
        _fieldErrors
          ..clear()
          ..addAll(errors);
        _error = 'Please fix the highlighted fields before saving.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors.clear();
    });

    final tags = _tags.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final data = <String, dynamic>{
      'name': name,
      'contact_person': _clean(_contactPerson),
      'phone': _clean(_phone),
      'email': _clean(_email),
      'address_line1': _clean(_address1),
      'address_line2': _clean(_address2),
      'city': _clean(_city),
      'state': _clean(_state),
      'postal_code': _clean(_postalCode),
      'country': _clean(_country),
      'tax_number': _clean(_taxNumber),
      'payment_terms': terms,
      'currency': currency,
      'bank_name': _clean(_bankName),
      'bank_account_number': _clean(_bankAccount),
      'opening_balance': opening,
      'status': SupplierModel.statusToDb(_status),
      'tags': tags.isEmpty ? null : tags,
      'notes': _clean(_notes),
    };

    final notifier = ref.read(suppliersProvider.notifier);
    final failure = _isEditing
        ? await notifier.edit(widget.supplierId!, data)
        : await notifier.create(data);

    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _saving = false;
        _error = failure.message;
      });
      return;
    }
    showAppToast(
      context,
      _isEditing ? 'Changes saved.' : 'Supplier created.',
      type: BannerType.success,
    );
    Navigator.of(context).pop();
  }

  /// Clears a field's error as soon as it is edited, per the design.
  void _clearFieldError(String key) {
    if (_fieldErrors.remove(key) != null) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isWide = ModuleScaffold.isWideOf(context);

    return ModuleScaffold(
      title: _isEditing ? 'Edit supplier' : 'New supplier',
      maxContentWidth: 860,
      leading: _FormBackButton(),
      child: _loadingExisting
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(
                  isWide ? 32 : 16, 12, isWide ? 32 : 16, 40),
              children: [
                if (_error != null) ...[
                  AppInlineBanner(message: _error!, type: BannerType.error),
                  const SizedBox(height: 16),
                ],
                _Section(
                  title: 'Identity',
                  child: _Grid(columns: isWide ? 2 : 1, children: [
                    _Span(_field(_name, 'Name', LucideIcons.building2,
                        key: 'name')),
                    _field(_contactPerson, 'Contact person', LucideIcons.user,
                        hint: 'Full name'),
                    _field(_taxNumber, 'Tax number', LucideIcons.receipt,
                        hint: 'NTN / STRN'),
                  ]),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'Contact',
                  child: _Grid(columns: isWide ? 2 : 1, children: [
                    _field(_phone, 'Phone', LucideIcons.phone,
                        hint: '+92 …', keyboardType: TextInputType.phone),
                    _field(_email, 'Email', LucideIcons.mail,
                        hint: 'name@company.pk',
                        keyboardType: TextInputType.emailAddress),
                  ]),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'Address',
                  child: _Grid(columns: isWide ? 2 : 1, children: [
                    _Span(_field(_address1, 'Address line 1',
                        LucideIcons.mapPin,
                        hint: 'Street, plot')),
                    _Span(_field(_address2, 'Address line 2',
                        LucideIcons.mapPin,
                        hint: 'Area, landmark (optional)')),
                    _field(_city, 'City', LucideIcons.building),
                    _field(_state, 'State / province', LucideIcons.map),
                    _field(_postalCode, 'Postal code', LucideIcons.mailbox),
                    _field(_country, 'Country', LucideIcons.globe),
                  ]),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'Financial',
                  child: _Grid(columns: isWide ? 2 : 1, children: [
                    _field(_paymentTerms, 'Payment terms (days)',
                        LucideIcons.clock,
                        key: 'terms',
                        keyboardType: TextInputType.number,
                        helper: 'Net days, defaults to 30'),
                    _field(_currency, 'Currency', LucideIcons.coins,
                        key: 'currency'),
                    _field(_openingBalance, 'Opening balance',
                        LucideIcons.wallet,
                        key: 'opening',
                        helper: 'Amount you owe them today',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true)),
                    const SizedBox.shrink(),
                    _field(_bankName, 'Bank name', LucideIcons.landmark),
                    _field(_bankAccount, 'Bank account', LucideIcons.hash),
                  ]),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'Classification',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Label('Status'),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                            maxWidth: isWide ? 280 : double.infinity),
                        child: AppDropdown<SupplierStatus>(
                          value: _status,
                          options: [
                            for (final s in SupplierStatus.values)
                              AppDropdownOption(
                                  value: s, label: _statusLabels[s]!),
                          ],
                          onSelected: (v) => setState(() => _status = v),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _field(_tags, 'Tags', LucideIcons.tag,
                          hint: 'comma, separated'),
                      const SizedBox(height: 16),
                      _field(_notes, 'Notes', LucideIcons.notebookPen,
                          hint: 'Anything the team should know…', maxLines: 3),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _Footer(
                  isWide: isWide,
                  saving: _saving,
                  primaryLabel:
                      _isEditing ? 'Save changes' : 'Create supplier',
                  onSave: _save,
                ),
              ],
            ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    String? key,
    String? hint,
    String? helper,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    final error = key == null ? null : _fieldErrors[key];
    return AppTextField(
      controller: controller,
      label: label,
      prefixIcon: icon,
      hint: hint,
      helperText: error == null ? helper : null,
      errorText: error,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: key == null ? null : (_) => _clearFieldError(key),
    );
  }
}

/// Marks a field that spans the full grid width on wide layouts.
class _Span extends StatelessWidget {
  const _Span(this.child);
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// Two-column form grid. Column count comes from the caller's width check;
/// [_Span] children always take a whole row.
class _Grid extends StatelessWidget {
  const _Grid({required this.columns, required this.children});
  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    var buffer = <Widget>[];

    void flush() {
      if (buffer.isEmpty) return;
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var c = 0; c < columns; c++) ...[
            if (c > 0) const SizedBox(width: 16),
            Expanded(
              child: c < buffer.length ? buffer[c] : const SizedBox.shrink(),
            ),
          ],
        ],
      ));
      buffer = <Widget>[];
    }

    for (final child in children) {
      if (child is _Span || columns == 1) {
        flush();
        rows.add(child);
        continue;
      }
      buffer.add(child);
      if (buffer.length == columns) flush();
    }
    flush();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          rows[i],
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: AppTypography.title2
                .copyWith(fontSize: 16, color: lum.textPrimary),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Text(
      text,
      style: AppTypography.fieldLabel.copyWith(fontSize: 13, color: lum.g700),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.isWide,
    required this.saving,
    required this.primaryLabel,
    required this.onSave,
  });

  final bool isWide;
  final bool saving;
  final String primaryLabel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final primary = AppButton(
      label: primaryLabel,
      icon: LucideIcons.check,
      loading: saving,
      fullWidth: !isWide,
      onPressed: onSave,
    );

    if (!isWide) return primary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.tinted,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 12),
        primary,
      ],
    );
  }
}

class _FormBackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Semantics(
        button: true,
        label: 'Back',
        child: InkWell(
          onTap: () => Navigator.of(context).maybePop(),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          // 44dp target around the design's 40px clay tile.
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: ClayContainer(
                variant: ClayVariant.soft,
                color: lum.surface,
                borderRadius: AppRadius.sm,
                isDark: lum.isDark,
                width: 40,
                height: 40,
                child: Center(
                  child: Icon(LucideIcons.arrowLeft,
                      size: 20, color: lum.textPrimary),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
