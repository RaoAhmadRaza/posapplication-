import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/entities/customer.dart';
import '../controllers/customers_controller.dart';
import '../controllers/pos_cart_controller.dart';

Future<Customer?> showCustomerPicker(BuildContext context) {
  return showModalBottomSheet<Customer?>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => const _CustomerPickerSheet(),
  );
}

class _CustomerPickerSheet extends ConsumerStatefulWidget {
  const _CustomerPickerSheet();

  @override
  ConsumerState<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends ConsumerState<_CustomerPickerSheet> {
  final _searchCtrl = TextEditingController();
  bool _showCreate = false;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _creating = false;
  String? _error;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _search(String q) {
    ref.read(customersProvider.notifier).search(q);
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }
    setState(() {
      _creating = true;
      _error = null;
    });
    final failure = await ref.read(customersProvider.notifier).create({
      'name': name,
      if (_phoneCtrl.text.trim().isNotEmpty) 'phone': _phoneCtrl.text.trim(),
    });
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _creating = false;
        _error = failure.message;
      });
    } else {
      final customers = ref.read(customersProvider).value ?? [];
      final created = customers.isNotEmpty ? customers.last : null;
      if (created != null && mounted) {
        ref.read(posCartProvider.notifier).setCustomer(created);
        Navigator.of(context).pop(created);
      }
    }
  }

  void _selectWalkIn() {
    ref.read(posCartProvider.notifier).setCustomer(null);
    Navigator.of(context).pop(null);
  }

  void _selectCustomer(Customer c) {
    ref.read(posCartProvider.notifier).setCustomer(c);
    Navigator.of(context).pop(c);
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider).value ?? [];
    final selectedId = ref.watch(posCartProvider).customer?.id;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.md, AppSpacing.screenPadding, AppSpacing.md),
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
            _CustomerTile(
              label: 'Walk-in',
              subtitle: 'No customer assigned',
              selected: selectedId == null,
              onTap: _selectWalkIn,
            ),
            if (!_showCreate) ...[
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _searchCtrl,
                label: 'Search',
                prefixIcon: Icons.search,
                hint: 'Name or phone',
                onSubmitted: _search,
              ),
              const SizedBox(height: AppSpacing.md),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: customers.length,
                  itemBuilder: (_, i) {
                    final c = customers[i];
                    return _CustomerTile(
                      label: c.name,
                      subtitle: c.phone ?? '',
                      selected: c.id == selectedId,
                      onTap: () => _selectCustomer(c),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: '+ New Customer',
                onPressed: () => setState(() => _showCreate = true),
                variant: AppButtonVariant.plain,
                fullWidth: true,
                icon: Icons.add,
              ),
            ] else ...[
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _nameCtrl,
                label: 'Name',
                prefixIcon: Icons.person,
                hint: 'Required',
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _phoneCtrl,
                label: 'Phone',
                prefixIcon: Icons.phone,
                hint: 'Optional',
                keyboardType: TextInputType.phone,
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                AppInlineBanner(message: _error!, type: BannerType.error),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Cancel',
                      onPressed: () => setState(() {
                        _showCreate = false;
                        _error = null;
                      }),
                      variant: AppButtonVariant.plain,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton(
                      label: 'Save',
                      onPressed: _creating ? null : _create,
                      loading: _creating,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withValues(alpha: 0.08) : AppColors.fieldFill,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: selected ? Border.all(color: AppColors.accent, width: 1) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected ? AppColors.accent.withValues(alpha: 0.15) : AppColors.separator,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  selected ? Icons.check : Icons.person_outline,
                  size: 18,
                  color: selected ? AppColors.accent : AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTypography.headline.copyWith(color: selected ? AppColors.accent : AppColors.textPrimary)),
                  if (subtitle.isNotEmpty)
                    Text(subtitle, style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, size: 20, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}
