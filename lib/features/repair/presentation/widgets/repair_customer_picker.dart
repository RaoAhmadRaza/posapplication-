import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../../customers/presentation/controllers/customers_controller.dart';

/// Bottom-sheet customer picker returning the chosen [Customer].
/// Reuses [customersProvider] search; does not touch any POS cart state.
Future<Customer?> showRepairCustomerPicker(BuildContext context) {
  return showModalBottomSheet<Customer?>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _RepairCustomerPicker(),
  );
}

class _RepairCustomerPicker extends ConsumerStatefulWidget {
  const _RepairCustomerPicker();

  @override
  ConsumerState<_RepairCustomerPicker> createState() =>
      _RepairCustomerPickerState();
}

class _RepairCustomerPickerState extends ConsumerState<_RepairCustomerPicker> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider).value ?? [];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding,
            AppSpacing.md, AppSpacing.screenPadding, AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.separator,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Select Customer', style: AppTypography.title2),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _searchCtrl,
              label: 'Search',
              prefixIcon: Icons.search,
              hint: 'Name or phone',
              onSubmitted: (q) =>
                  ref.read(customersProvider.notifier).search(q),
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: customers.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text('No customers found.',
                          style: AppTypography.footnote
                              .copyWith(color: AppColors.textMuted)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: customers.length,
                      itemBuilder: (_, i) {
                        final c = customers[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.person_outline,
                              color: AppColors.textMuted),
                          title: Text(c.name, style: AppTypography.headline),
                          subtitle: c.phone == null
                              ? null
                              : Text(c.phone!,
                                  style: AppTypography.caption
                                      .copyWith(color: AppColors.textMuted)),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.card)),
                          onTap: () => Navigator.of(context).pop(c),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
