import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_section_card.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toggle.dart';
import '../controllers/warehouses_controller.dart';

class WarehouseFormPage extends ConsumerStatefulWidget {
  const WarehouseFormPage({super.key, this.warehouseId});

  final String? warehouseId;

  @override
  ConsumerState<WarehouseFormPage> createState() => _WarehouseFormPageState();
}

class _WarehouseFormPageState extends ConsumerState<WarehouseFormPage> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _addressController = TextEditingController();
  final _capacityNotesController = TextEditingController();
  bool _isActive = true;
  String? _error;
  bool _saving = false;
  bool _loadingExisting = false;

  bool get _isEditing => widget.warehouseId != null;

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
    _codeController.dispose();
    _addressController.dispose();
    _capacityNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    setState(() => _loadingExisting = true);
    final state = ref.read(warehousesProvider);
    if (state.value != null) {
      final wh = state.value!.where((w) => w.id == widget.warehouseId).firstOrNull;
      if (wh != null) {
        _nameController.text = wh.name;
        _codeController.text = wh.code;
        _addressController.text = wh.address ?? '';
        _capacityNotesController.text = wh.capacityNotes ?? '';
        _isActive = wh.isActive;
      }
    }
    setState(() => _loadingExisting = false);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }
    if (code.isEmpty) {
      setState(() => _error = 'Code is required.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final data = <String, dynamic>{
      'name': name,
      'code': code,
      'address': _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      'capacity_notes': _capacityNotesController.text.trim().isEmpty
          ? null
          : _capacityNotesController.text.trim(),
      'is_active': _isActive,
    };

    final failure = await ref.read(warehousesProvider.notifier).save(
          data: data,
          id: widget.warehouseId,
        );

    if (!mounted) return;

    if (failure != null) {
      setState(() {
        _saving = false;
        _error = failure.message;
      });
      return;
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;

    if (_loadingExisting) {
      return AppDetailScaffold(
        eyebrow: 'Inventory',
        title: _isEditing ? 'Edit warehouse' : 'New warehouse',
        maxContentWidth: 720,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return AppDetailScaffold(
      eyebrow: 'Inventory',
      title: _isEditing ? 'Edit warehouse' : 'New warehouse',
      maxContentWidth: 720,
      child: Column(
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
                  prefixIcon: LucideIcons.warehouse,
                  hint: 'e.g. Main Warehouse',
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _codeController,
                  label: 'Code',
                  prefixIcon: LucideIcons.hash,
                  hint: 'e.g. WH01',
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _addressController,
                  label: 'Address',
                  prefixIcon: LucideIcons.mapPin,
                  hint: 'Optional',
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _capacityNotesController,
                  label: 'Capacity notes',
                  prefixIcon: LucideIcons.notebookPen,
                  hint: 'Optional',
                  maxLines: 3,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active',
                            style: AppTypography.headline.copyWith(
                              fontSize: 14.5,
                              color: lum.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Show this warehouse in pickers and reports',
                            style:
                                AppTypography.subhead.copyWith(color: lum.g500),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
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
          const SizedBox(height: 20),
          AppButton(
            label: 'Save',
            icon: LucideIcons.check,
            loading: _saving,
            fullWidth: true,
            onPressed: _save,
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Cancel',
            variant: AppButtonVariant.plain,
            fullWidth: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
