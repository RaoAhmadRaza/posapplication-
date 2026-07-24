import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_section_card.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toggle.dart';
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
    return AppDetailScaffold(
      eyebrow: 'Inventory',
      title: _isEditing ? 'Edit brand' : 'New brand',
      onBack: () => Navigator.of(context).pop(),
      child: _loadingExisting
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  AppInlineBanner(message: _error!, type: BannerType.error),
                  const SizedBox(height: 16),
                ],
                AppSectionCard(
                  eyebrow: 'Details',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        controller: _nameController,
                        label: 'Name',
                        prefixIcon: Icons.branding_watermark,
                        hint: 'e.g. Samsung',
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _logoUrlController,
                        label: 'Logo URL',
                        prefixIcon: Icons.link,
                        hint: 'Optional',
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _descriptionController,
                        label: 'Description',
                        prefixIcon: Icons.description,
                        hint: 'Optional',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text('Active', style: AppTypography.body),
                          ),
                          AppToggle(
                            value: _isActive,
                            semanticLabel: 'Active',
                            onChanged: (v) => setState(() => _isActive = v),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Save',
                  loading: _saving,
                  onPressed: _save,
                  fullWidth: true,
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Cancel',
                  variant: AppButtonVariant.plain,
                  fullWidth: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 8),
              ],
            ),
    );
  }
}
