import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/customer.dart';
import '../../domain/usecases/load_customer.dart';
import '../../data/models/customer_model.dart';
import '../controllers/customers_controller.dart';

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
    final (customer, failure) = await ref
        .read(loadCustomerUseCaseProvider)
        .call(widget.customerId!);
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
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }
    final limit = double.tryParse(_creditLimit.text.trim());
    if (limit == null || limit < 0) {
      setState(() => _error = 'Credit limit must be a non-negative number.');
      return;
    }
    final terms = int.tryParse(_creditTerms.text.trim());
    if (terms == null || terms < 0) {
      setState(() => _error = 'Credit terms must be a non-negative number.');
      return;
    }
    final opening = double.tryParse(_openingBalance.text.trim());
    if (opening == null) {
      setState(() => _error = 'Opening balance must be a number.');
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
        title: Text(_isEditing ? 'Edit Customer' : 'New Customer',
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
                              prefixIcon: Icons.person),
                          _gap(),
                          AppTextField(
                              controller: _phone,
                              label: 'Phone',
                              prefixIcon: Icons.phone,
                              keyboardType: TextInputType.phone,
                              hint: 'Optional'),
                          _gap(),
                          AppTextField(
                              controller: _phoneSecondary,
                              label: 'Secondary Phone',
                              prefixIcon: Icons.phone_android,
                              keyboardType: TextInputType.phone,
                              hint: 'Optional'),
                          _gap(),
                          AppTextField(
                              controller: _email,
                              label: 'Email',
                              prefixIcon: Icons.email,
                              keyboardType: TextInputType.emailAddress,
                              hint: 'Optional'),
                          _gap(),
                          AppTextField(
                              controller: _taxNumber,
                              label: 'Tax Number',
                              prefixIcon: Icons.receipt_long,
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
                              controller: _creditLimit,
                              label: 'Credit Limit',
                              prefixIcon: Icons.credit_card,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true)),
                          _gap(),
                          AppTextField(
                              controller: _creditTerms,
                              label: 'Credit Terms (days)',
                              prefixIcon: Icons.schedule,
                              keyboardType: TextInputType.number),
                          _gap(),
                          AppTextField(
                              controller: _openingBalance,
                              label: 'Opening Balance',
                              prefixIcon: Icons.account_balance_wallet,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true, signed: true)),
                          _sectionGap(),
                          _group('Status'),
                          DropdownButtonFormField<CustomerStatus>(
                            initialValue: _status,
                            decoration: const InputDecoration(
                                border: OutlineInputBorder()),
                            items: CustomerStatus.values
                                .map((s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(switch (s) {
                                        CustomerStatus.active => 'Active',
                                        CustomerStatus.inactive => 'Inactive',
                                        CustomerStatus.blacklisted =>
                                          'Blacklisted',
                                      }),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(
                                () => _status = v ?? CustomerStatus.active),
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
                          PermissionGate(
                            module: 'customers',
                            action: _isEditing ? 'update' : 'create',
                            fallback: AppInlineBanner(
                                message: _isEditing
                                    ? 'You do not have permission to edit customers.'
                                    : 'You do not have permission to add customers.',
                                type: BannerType.info),
                            child: AppButton(
                              label: _isEditing ? 'Update' : 'Create',
                              loading: _saving,
                              onPressed: _save,
                              fullWidth: true,
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

  Widget _gap() => const SizedBox(height: AppSpacing.fieldGap);
  Widget _sectionGap() => const SizedBox(height: AppSpacing.xl);

  Widget _group(String label) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(label.toUpperCase(),
            style: AppTypography.footnote.copyWith(
                color: AppColors.textMuted, fontWeight: FontWeight.w600)),
      );
}
