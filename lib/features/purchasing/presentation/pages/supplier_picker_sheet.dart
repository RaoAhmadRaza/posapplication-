import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_search_field.dart';
import '../../../../core/design/widgets/app_sheet.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../suppliers/data/models/supplier_model.dart';
import '../../../suppliers/domain/entities/supplier.dart';
import '../../../suppliers/domain/usecases/create_supplier.dart';
import '../../../suppliers/presentation/controllers/suppliers_controller.dart';

/// Searchable supplier picker. Returns the chosen [Supplier], or null on dismiss.
Future<Supplier?> showSupplierPicker(BuildContext context) {
  return showAppSheet<Supplier>(
    context: context,
    builder: (sheetContext) => const _SupplierPickerBody(),
  );
}

class _SupplierPickerBody extends ConsumerStatefulWidget {
  const _SupplierPickerBody();

  @override
  ConsumerState<_SupplierPickerBody> createState() => _SupplierPickerBodyState();
}

class _SupplierPickerBodyState extends ConsumerState<_SupplierPickerBody> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_listener);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _listener() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(suppliersProvider.notifier).search(_searchCtrl.text);
    });
  }

  /// Quick-create without leaving the PO: on success the new supplier is
  /// returned straight to the caller, already selected.
  Future<void> _createNew() async {
    final created = await showAppSheet<Supplier>(
      context: context,
      builder: (_) => const _QuickSupplierForm(),
    );
    if (created != null && mounted) Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final suppliers = ref.watch(suppliersProvider).value ?? const <Supplier>[];
    final aging = ref.watch(payablesAgingProvider).value;
    final query = _searchCtrl.text.trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSheetHeader(title: 'Select supplier'),
        AppSearchField(
          controller: _searchCtrl,
          hint: 'Search suppliers…',
          onSubmitted: (q) => ref.read(suppliersProvider.notifier).search(q),
          onClear: () => ref.read(suppliersProvider.notifier).search(''),
        ),
        const SizedBox(height: 12),
        _CreateSupplierTile(onTap: _createNew),
        const SizedBox(height: 8),
        if (suppliers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Text(
              query.isEmpty
                  ? 'No suppliers found.'
                  : 'No suppliers match "$query".',
              textAlign: TextAlign.center,
              style: AppTypography.footnote.copyWith(color: lum.g500),
            ),
          )
        else
          for (final s in suppliers) ...[
            _SupplierTile(
              supplier: s,
              payable: aging?.balanceFor(s.id),
              onTap: () => Navigator.of(context).pop(s),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

/// Entry point to the inline quick-create form, sitting above the results.
class _CreateSupplierTile extends StatelessWidget {
  const _CreateSupplierTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Semantics(
      button: true,
      label: 'Create new supplier',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: ClayContainer(
            variant: ClayVariant.soft,
            color: lum.accentSoft,
            borderRadius: AppRadius.md,
            isDark: lum.isDark,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                ClayContainer(
                  variant: ClayVariant.soft,
                  color: lum.surface,
                  borderRadius: AppRadius.sm,
                  isDark: lum.isDark,
                  width: 38,
                  height: 38,
                  child: Center(
                    child: Icon(LucideIcons.plus,
                        size: 18, color: lum.accentPress),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Create new supplier',
                    style: AppTypography.headline
                        .copyWith(color: lum.accentPress),
                  ),
                ),
                Icon(LucideIcons.chevronRight, size: 18, color: lum.accentPress),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Required-fields-only supplier form. Everything else the full form offers
/// (address, tax, bank, tags, notes) is left to the Suppliers page.
class _QuickSupplierForm extends ConsumerStatefulWidget {
  const _QuickSupplierForm();

  @override
  ConsumerState<_QuickSupplierForm> createState() => _QuickSupplierFormState();
}

class _QuickSupplierFormState extends ConsumerState<_QuickSupplierForm> {
  final _name = TextEditingController();
  final _paymentTerms = TextEditingController(text: '30');
  final _currency = TextEditingController(text: 'PKR');
  final _openingBalance = TextEditingController(text: '0');

  final _fieldErrors = <String, String>{};
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _paymentTerms, _currency, _openingBalance]) {
      c.dispose();
    }
    super.dispose();
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

    final (supplier, failure) =
        await ref.read(createSupplierUseCaseProvider).call({
      'name': name,
      'payment_terms': terms,
      'currency': currency,
      'opening_balance': opening,
      'status': SupplierModel.statusToDb(SupplierStatus.active),
    });

    if (!mounted) return;
    if (failure != null || supplier == null) {
      setState(() {
        _saving = false;
        _error = failure?.message ?? 'Unable to create the supplier.';
      });
      return;
    }
    // Keep the suppliers list (and the picker behind us) in sync.
    ref.read(suppliersProvider.notifier).refresh();
    Navigator.of(context).pop(supplier);
  }

  void _clearFieldError(String key) {
    if (_fieldErrors.remove(key) != null) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSheetHeader(title: 'New supplier'),
        if (_error != null) ...[
          AppInlineBanner(message: _error!, type: BannerType.error),
          const SizedBox(height: 14),
        ],
        _field(_name, 'Name', LucideIcons.building2, key: 'name'),
        const SizedBox(height: 14),
        _field(_paymentTerms, 'Payment terms (days)', LucideIcons.clock,
            key: 'terms', keyboardType: TextInputType.number),
        const SizedBox(height: 14),
        _field(_currency, 'Currency', LucideIcons.coins, key: 'currency'),
        const SizedBox(height: 14),
        _field(_openingBalance, 'Opening balance', LucideIcons.wallet,
            key: 'opening',
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: true)),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.tinted,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 12),
            AppButton(
              label: 'Create supplier',
              icon: LucideIcons.check,
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Additional information (contact, address, tax, bank, notes) can be '
          'added later from the Suppliers page.',
          style: AppTypography.caption.copyWith(color: lum.g500),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    required String key,
    TextInputType? keyboardType,
  }) =>
      AppTextField(
        controller: controller,
        label: label,
        prefixIcon: icon,
        isRequired: true,
        errorText: _fieldErrors[key],
        keyboardType: keyboardType,
        onChanged: (_) => _clearFieldError(key),
      );
}

class _SupplierTile extends StatelessWidget {
  const _SupplierTile({
    required this.supplier,
    required this.payable,
    required this.onTap,
  });
  final Supplier supplier;
  final double? payable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final city = supplier.city?.trim();

    return Semantics(
      button: true,
      label: supplier.name,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: ClayContainer(
            variant: ClayVariant.inset,
            color: lum.surface2,
            borderRadius: AppRadius.md,
            isDark: lum.isDark,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                ClayContainer(
                  variant: ClayVariant.soft,
                  color: lum.accentSoft,
                  borderRadius: AppRadius.sm,
                  isDark: lum.isDark,
                  width: 38,
                  height: 38,
                  child: Center(
                    child: Icon(LucideIcons.truck,
                        size: 18, color: lum.accentPress),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        supplier.name,
                        style: AppTypography.headline
                            .copyWith(color: lum.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (city != null && city.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          city,
                          style:
                              AppTypography.caption.copyWith(color: lum.g500),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    payable == null
                        ? Text('—',
                            style: AppTypography.monoValue
                                .copyWith(fontSize: 15, color: lum.g400))
                        : AppMoneyText(payable!, size: 15),
                    Text(
                      'payable',
                      style: AppTypography.caption.copyWith(color: lum.g400),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
