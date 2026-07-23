import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_search_field.dart';
import '../../../../core/design/widgets/app_sheet.dart';
import '../../../suppliers/domain/entities/supplier.dart';
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
