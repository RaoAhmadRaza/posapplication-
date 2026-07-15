import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        title: Text('Business settings', style: AppTypography.headline),
      ),
      body: SafeArea(
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: AppInlineBanner(
              message: e is SettingsFailure ? e.message : e.toString(),
            ),
          ),
          data: (s) {
            _seed(s);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: _address,
                    label: 'Business address',
                    prefixIcon: Icons.location_on_outlined,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _phone,
                    label: 'Phone',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _ntn,
                    label: 'NTN',
                    prefixIcon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _logoUrl,
                    label: 'Logo URL',
                    prefixIcon: Icons.image_outlined,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _receiptFooter,
                    label: 'Receipt footer',
                    prefixIcon: Icons.receipt_long_outlined,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (canEdit)
                    AppButton(
                      label: 'Save',
                      loading: _saving,
                      fullWidth: true,
                      onPressed: _saving ? null : _save,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
