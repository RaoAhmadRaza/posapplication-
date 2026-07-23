import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_filter_chips.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/widgets/module_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/customer.dart';
import '../../domain/usecases/load_customer.dart';
import '../../data/models/customer_model.dart';
import '../controllers/customers_controller.dart';

/// Segmented status order — matches [CustomerStatus.values].
const _statusLabels = ['Active', 'Inactive', 'Blacklisted'];

class CustomerFormPage extends ConsumerStatefulWidget {
  const CustomerFormPage({super.key, this.customerId});

  final String? customerId;

  @override
  ConsumerState<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends ConsumerState<CustomerFormPage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _phoneSecondary = TextEditingController();
  final _email = TextEditingController();
  final _address1 = TextEditingController();
  final _address2 = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _postalCode = TextEditingController();
  final _country = TextEditingController(text: 'Pakistan');
  final _taxNumber = TextEditingController();
  final _creditLimit = TextEditingController(text: '0');
  final _creditTerms = TextEditingController(text: '0');
  final _openingBalance = TextEditingController(text: '0');
  final _tags = TextEditingController();
  final _notes = TextEditingController();
  CustomerStatus _status = CustomerStatus.active;

  String? _error;
  bool _saving = false;
  bool _loadingExisting = false;

  /// Per-field messages so the design's inline errors sit on the field that is
  /// actually wrong, not only in the banner.
  final _fieldErrors = <String, String>{};

  bool get _isEditing => widget.customerId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadExisting();
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _phone,
      _phoneSecondary,
      _email,
      _address1,
      _address2,
      _city,
      _state,
      _postalCode,
      _country,
      _taxNumber,
      _creditLimit,
      _creditTerms,
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
    final (customer, failure) =
        await ref.read(loadCustomerUseCaseProvider).call(widget.customerId!);
    if (!mounted) return;
    if (customer != null) _seed(customer);
    setState(() {
      _loadingExisting = false;
      if (failure != null) _error = failure.message;
    });
  }

  void _seed(Customer c) {
    _name.text = c.name;
    _phone.text = c.phone ?? '';
    _phoneSecondary.text = c.phoneSecondary ?? '';
    _email.text = c.email ?? '';
    _address1.text = c.addressLine1 ?? '';
    _address2.text = c.addressLine2 ?? '';
    _city.text = c.city ?? '';
    _state.text = c.state ?? '';
    _postalCode.text = c.postalCode ?? '';
    _country.text = c.country ?? '';
    _taxNumber.text = c.taxNumber ?? '';
    _creditLimit.text = c.creditLimit.toString();
    _creditTerms.text = c.creditTerms.toString();
    _openingBalance.text = c.openingBalance.toString();
    _tags.text = (c.tags ?? []).join(', ');
    _notes.text = c.notes ?? '';
    _status = c.status;
  }

  String? _clean(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _save() async {
    final errors = <String, String>{};
    final name = _name.text.trim();
    if (name.isEmpty) errors['name'] = 'Enter a customer name.';

    final limit = double.tryParse(_creditLimit.text.trim());
    if (limit == null || limit < 0) {
      errors['creditLimit'] = 'Enter a number, 0 or more.';
    }
    final terms = int.tryParse(_creditTerms.text.trim());
    if (terms == null || terms < 0) {
      errors['creditTerms'] = 'Whole number of days, 0 or more.';
    }
    final opening = double.tryParse(_openingBalance.text.trim());
    if (opening == null) errors['opening'] = 'Enter a number.';

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
      'phone': _clean(_phone),
      'phone_secondary': _clean(_phoneSecondary),
      'email': _clean(_email),
      'address_line1': _clean(_address1),
      'address_line2': _clean(_address2),
      'city': _clean(_city),
      'state': _clean(_state),
      'postal_code': _clean(_postalCode),
      'country': _clean(_country),
      'tax_number': _clean(_taxNumber),
      'credit_limit': limit,
      'credit_terms': terms,
      'opening_balance': opening,
      'status': CustomerModel.statusToDb(_status),
      'tags': tags.isEmpty ? null : tags,
      'notes': _clean(_notes),
    };

    final notifier = ref.read(customersProvider.notifier);
    final failure = _isEditing
        ? await notifier.edit(widget.customerId!, data)
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
      _isEditing ? 'Changes saved.' : 'Customer created.',
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
      title: _isEditing ? 'Edit customer' : 'New customer',
      maxContentWidth: 760,
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
                    _Span(_field(_name, 'Name', LucideIcons.user,
                        key: 'name', hint: 'Full name or business')),
                    _field(_phone, 'Phone', LucideIcons.phone,
                        hint: '(555) 000-0000',
                        keyboardType: TextInputType.phone),
                    _field(_phoneSecondary, 'Secondary phone',
                        LucideIcons.smartphone,
                        hint: 'Optional', keyboardType: TextInputType.phone),
                    _field(_email, 'Email', LucideIcons.mail,
                        hint: 'name@email.com',
                        keyboardType: TextInputType.emailAddress),
                    _field(_taxNumber, 'Tax number', LucideIcons.receipt,
                        hint: 'Optional'),
                  ]),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'Address',
                  child: _Grid(columns: isWide ? 2 : 1, children: [
                    _Span(_field(_address1, 'Address line 1', LucideIcons.mapPin,
                        hint: 'Street address')),
                    _Span(_field(_address2, 'Address line 2', LucideIcons.mapPin,
                        hint: 'Apt, suite, unit (optional)')),
                    _field(_city, 'City', LucideIcons.building),
                    _field(_state, 'State / province', LucideIcons.map),
                    _field(_postalCode, 'Postal code', LucideIcons.mailbox),
                    _field(_country, 'Country', LucideIcons.globe),
                  ]),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'Credit & terms',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Grid(columns: isWide ? 3 : 1, children: [
                        _field(_creditLimit, 'Credit limit',
                            LucideIcons.creditCard,
                            key: 'creditLimit',
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true)),
                        _field(_creditTerms, 'Credit terms (days)',
                            LucideIcons.clock,
                            key: 'creditTerms',
                            keyboardType: TextInputType.number),
                        _field(_openingBalance, 'Opening balance',
                            LucideIcons.wallet,
                            key: 'opening',
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true, signed: true)),
                      ]),
                      const SizedBox(height: 16),
                      _Label('Status'),
                      const SizedBox(height: 8),
                      AppFilterChips(
                        labels: _statusLabels,
                        selected: CustomerStatus.values.indexOf(_status),
                        onSelected: (i) => setState(
                            () => _status = CustomerStatus.values[i]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'Tags & notes',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _field(_tags, 'Tags', LucideIcons.tag,
                          hint: 'Comma-separated, e.g. wholesale, net-30'),
                      const SizedBox(height: 16),
                      _field(_notes, 'Notes', LucideIcons.notebookPen,
                          hint: 'Internal notes about this customer',
                          maxLines: 3),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                PermissionGate(
                  module: 'customers',
                  action: _isEditing ? 'update' : 'create',
                  fallback: AppInlineBanner(
                      message: _isEditing
                          ? 'You do not have permission to edit customers.'
                          : 'You do not have permission to add customers.',
                      type: BannerType.info),
                  child: _Footer(
                    isWide: isWide,
                    saving: _saving,
                    primaryLabel:
                        _isEditing ? 'Save changes' : 'Create customer',
                    onSave: _save,
                  ),
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
