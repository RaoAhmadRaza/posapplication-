import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/usecases/load_supplier.dart';
import '../../data/models/supplier_model.dart';
import '../controllers/suppliers_controller.dart';

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
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }
    final terms = int.tryParse(_paymentTerms.text.trim());
    if (terms == null || terms < 0) {
      setState(() => _error = 'Payment terms must be a non-negative number.');
      return;
    }
    final opening = double.tryParse(_openingBalance.text.trim());
    if (opening == null) {
      setState(() => _error = 'Opening balance must be a number.');
      return;
    }
    final currency = _currency.text.trim();
    if (currency.isEmpty) {
      setState(() => _error = 'Currency is required.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
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
    Navigator.of(context).pop();
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
        title: Text(_isEditing ? 'Edit Supplier' : 'New Supplier',
            style: AppTypography.headline),
      ),
      body: _loadingExisting
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
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
                          _group('Identity'),
                          AppTextField(
                              controller: _name,
                              label: 'Name',
                              prefixIcon: Icons.business),
                          _gap(),
                          AppTextField(
                              controller: _contactPerson,
                              label: 'Contact Person',
                              prefixIcon: Icons.person,
                              hint: 'Optional'),
                          _gap(),
                          AppTextField(
                              controller: _taxNumber,
                              label: 'Tax Number',
                              prefixIcon: Icons.receipt_long,
                              hint: 'Optional'),
                          _sectionGap(),
                          _group('Contact'),
                          AppTextField(
                              controller: _phone,
                              label: 'Phone',
                              prefixIcon: Icons.phone,
                              keyboardType: TextInputType.phone,
                              hint: 'Optional'),
                          _gap(),
                          AppTextField(
                              controller: _email,
                              label: 'Email',
                              prefixIcon: Icons.email,
                              keyboardType: TextInputType.emailAddress,
                              hint: 'Optional'),
                          _sectionGap(),
                          _group('Address'),
                          AppTextField(
                              controller: _address1,
                              label: 'Address Line 1',
                              prefixIcon: Icons.location_on,
                              hint: 'Optional'),
                          _gap(),
                          AppTextField(
                              controller: _address2,
                              label: 'Address Line 2',
                              prefixIcon: Icons.location_on_outlined,
                              hint: 'Optional'),
                          _gap(),
                          AppTextField(
                              controller: _city,
                              label: 'City',
                              prefixIcon: Icons.location_city,
                              hint: 'Optional'),
                          _gap(),
                          AppTextField(
                              controller: _state,
                              label: 'State / Province',
                              prefixIcon: Icons.map,
                              hint: 'Optional'),
                          _gap(),
                          AppTextField(
                              controller: _postalCode,
                              label: 'Postal Code',
                              prefixIcon: Icons.local_post_office,
                              hint: 'Optional'),
                          _gap(),
                          AppTextField(
                              controller: _country,
                              label: 'Country',
                              prefixIcon: Icons.public),
                          _sectionGap(),
                          _group('Financial'),
                          AppTextField(
                              controller: _paymentTerms,
                              label: 'Payment Terms (days)',
                              prefixIcon: Icons.schedule,
                              keyboardType: TextInputType.number),
                          _gap(),
                          AppTextField(
                              controller: _currency,
                              label: 'Currency',
                              prefixIcon: Icons.attach_money),
                          _gap(),
                          AppTextField(
                              controller: _openingBalance,
                              label: 'Opening Balance',
                              prefixIcon: Icons.account_balance_wallet,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true, signed: true)),
                          _gap(),
                          AppTextField(
                              controller: _bankName,
                              label: 'Bank Name',
                              prefixIcon: Icons.account_balance,
                              hint: 'Optional'),
                          _gap(),
                          AppTextField(
                              controller: _bankAccount,
                              label: 'Bank Account Number',
                              prefixIcon: Icons.numbers,
                              hint: 'Optional'),
                          _sectionGap(),
                          _group('Status'),
                          DropdownButtonFormField<SupplierStatus>(
                            initialValue: _status,
                            decoration: const InputDecoration(
                                border: OutlineInputBorder()),
                            items: SupplierStatus.values
                                .map((s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(switch (s) {
                                        SupplierStatus.active => 'Active',
                                        SupplierStatus.inactive => 'Inactive',
                                        SupplierStatus.blacklisted =>
                                          'Blacklisted',
                                      }),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(
                                () => _status = v ?? SupplierStatus.active),
                          ),
                          _sectionGap(),
                          _group('Other'),
                          AppTextField(
                              controller: _tags,
                              label: 'Tags',
                              prefixIcon: Icons.label,
                              hint: 'Comma-separated, optional'),
                          _gap(),
                          AppTextField(
                              controller: _notes,
                              label: 'Notes',
                              prefixIcon: Icons.notes,
                              hint: 'Optional'),
                          const SizedBox(height: AppSpacing.xxl),
                          AppButton(
                            label: _isEditing ? 'Update' : 'Create',
                            loading: _saving,
                            onPressed: _save,
                            fullWidth: true,
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

  Widget _gap() => const SizedBox(height: AppSpacing.fieldGap);
  Widget _sectionGap() => const SizedBox(height: AppSpacing.xl);

  Widget _group(String label) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(label.toUpperCase(),
            style: AppTypography.footnote.copyWith(
                color: AppColors.textMuted, fontWeight: FontWeight.w600)),
      );
}
