import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../auth/presentation/controllers/permission_controller.dart';
import '../../domain/entities/tenant_settings.dart';
import '../../domain/failures/settings_failure.dart';
import '../controllers/business_settings_controller.dart';

class BusinessSettingsPage extends ConsumerStatefulWidget {
  const BusinessSettingsPage({super.key});

  @override
  ConsumerState<BusinessSettingsPage> createState() =>
      _BusinessSettingsPageState();
}

class _BusinessSettingsPageState extends ConsumerState<BusinessSettingsPage> {
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _logoUrl = TextEditingController();
  final _receiptFooter = TextEditingController();
  final _ntn = TextEditingController();
  bool _seeded = false;
  bool _saving = false;

  @override
  void dispose() {
    _address.dispose();
    _phone.dispose();
    _logoUrl.dispose();
    _receiptFooter.dispose();
    _ntn.dispose();
    super.dispose();
  }

  void _seed(TenantSettings s) {
    if (_seeded) return;
    _address.text = s.businessAddress;
    _phone.text = s.phone;
    _logoUrl.text = s.logoUrl;
    _receiptFooter.text = s.receiptFooter;
    _ntn.text = s.ntn;
    _seeded = true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final failure = await ref.read(businessSettingsProvider.notifier).save({
      'business_address': _address.text.trim(),
      'phone': _phone.text.trim(),
      'logo_url': _logoUrl.text.trim(),
      'receipt_footer': _receiptFooter.text.trim(),
      'ntn': _ntn.text.trim(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(failure == null ? 'Saved' : failure.message),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(businessSettingsProvider);
    final canEdit =
        ref.watch(permissionMatrixProvider).value?.contains('settings:update') ??
            false;

    return AppDetailScaffold(
      eyebrow: 'Settings',
      title: 'Business settings',
      description: 'Details shown on receipts and invoices.',
      child: state.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => AppInlineBanner(
          message: e is SettingsFailure ? e.message : e.toString(),
        ),
        data: (s) {
          _seed(s);
          return AppCard(
            padding: const EdgeInsets.all(24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Phone and NTN pair up only when the card is wide enough to
                // keep both wells legible.
                final twoUp = constraints.maxWidth >= 520;
                final phone = AppTextField(
                  controller: _phone,
                  label: 'Phone',
                  prefixIcon: LucideIcons.phone,
                  keyboardType: TextInputType.phone,
                );
                final ntn = AppTextField(
                  controller: _ntn,
                  label: 'NTN (tax number)',
                  prefixIcon: LucideIcons.receipt,
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      controller: _address,
                      label: 'Registered address',
                      prefixIcon: LucideIcons.mapPin,
                    ),
                    const SizedBox(height: AppSpacing.fieldGap),
                    if (twoUp)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: phone),
                          const SizedBox(width: AppSpacing.base),
                          Expanded(child: ntn),
                        ],
                      )
                    else ...[
                      phone,
                      const SizedBox(height: AppSpacing.fieldGap),
                      ntn,
                    ],
                    const SizedBox(height: AppSpacing.fieldGap),
                    AppTextField(
                      controller: _logoUrl,
                      label: 'Logo URL',
                      prefixIcon: LucideIcons.image,
                      helperText: 'Shown on receipts and invoices.',
                    ),
                    const SizedBox(height: AppSpacing.fieldGap),
                    AppTextField(
                      controller: _receiptFooter,
                      label: 'Receipt footer',
                      prefixIcon: LucideIcons.fileText,
                      maxLines: 3,
                      helperText: 'Printed at the bottom of every receipt.',
                    ),
                    if (canEdit) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Align(
                        alignment: Alignment.centerRight,
                        child: AppButton(
                          label: 'Save changes',
                          loading: _saving,
                          onPressed: _saving ? null : _save,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
