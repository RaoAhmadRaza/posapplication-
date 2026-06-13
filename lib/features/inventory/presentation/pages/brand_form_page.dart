import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/failures/inventory_failure.dart';
import '../controllers/brands_controller.dart';

class BrandFormPage extends ConsumerStatefulWidget {
  const BrandFormPage({super.key, this.brandId});

  final String? brandId;

  @override
  ConsumerState<BrandFormPage> createState() => _BrandFormPageState();
}

class _BrandFormPageState extends ConsumerState<BrandFormPage> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _logoUrlController = TextEditingController();
  bool _isActive = true;
  String? _error;
  bool _saving = false;
  bool _loadingExisting = false;

  bool get _isEditing => widget.brandId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadExisting();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _logoUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    setState(() => _loadingExisting = true);
    final state = ref.read(brandsProvider);
    if (state.value != null) {
      final brand = state.value!.where((b) => b.id == widget.brandId).firstOrNull;
      if (brand != null) {
        _nameController.text = brand.name;
        _descriptionController.text = brand.description ?? '';
        _logoUrlController.text = brand.logoUrl ?? '';
        _isActive = brand.isActive;
      }
    }
    setState(() => _loadingExisting = false);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final data = <String, dynamic>{
      'name': name,
      'description': _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      'logo_url': _logoUrlController.text.trim().isEmpty
          ? null
          : _logoUrlController.text.trim(),
      'is_active': _isActive,
    };

    final failure = await ref.read(brandsProvider.notifier).save(
          data: data,
          id: widget.brandId,
        );

    if (!mounted) return;

    if (failure != null) {
      setState(() {
        _saving = false;
        if (failure is DuplicateSkuFailure) {
          _error = 'A brand with this name already exists.';
        } else {
          _error = failure.message;
        }
      });
      return;
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isEditing ? 'Edit Brand' : 'New Brand',
          style: AppTypography.headline,
        ),
      ),
      body: _loadingExisting
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    if (_error != null) ...[
                      AppInlineBanner(message: _error!, type: BannerType.error),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    AppTextField(
                      controller: _nameController,
                      label: 'Name',
                      prefixIcon: Icons.branding_watermark,
                      hint: 'e.g. Samsung',
                    ),
                    const SizedBox(height: AppSpacing.fieldGap),
                    AppTextField(
                      controller: _logoUrlController,
                      label: 'Logo URL',
                      prefixIcon: Icons.link,
                      hint: 'Optional',
                    ),
                    const SizedBox(height: AppSpacing.fieldGap),
                    AppTextField(
                      controller: _descriptionController,
                      label: 'Description',
                      prefixIcon: Icons.description,
                      hint: 'Optional',
                    ),
                    const SizedBox(height: AppSpacing.fieldGap),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Active', style: AppTypography.body),
                      value: _isActive,
                      activeThumbColor: AppColors.accent,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
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
    );
  }
}
