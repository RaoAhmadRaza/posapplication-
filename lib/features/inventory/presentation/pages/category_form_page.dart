import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_dropdown.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_section_card.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toggle.dart';
import '../../domain/entities/category.dart';
import '../../domain/failures/inventory_failure.dart';
import '../controllers/categories_controller.dart';

class CategoryFormPage extends ConsumerStatefulWidget {
  const CategoryFormPage({super.key, this.categoryId});

  final String? categoryId;

  @override
  ConsumerState<CategoryFormPage> createState() => _CategoryFormPageState();
}

class _CategoryFormPageState extends ConsumerState<CategoryFormPage> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sortOrderController = TextEditingController(text: '0');
  String? _parentId;
  bool _isActive = true;
  String? _error;
  bool _saving = false;
  bool _loadingExisting = false;

  bool get _isEditing => widget.categoryId != null;

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
    _sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    setState(() => _loadingExisting = true);
    final state = ref.read(categoriesProvider);
    if (state.value != null) {
      final cat = state.value!.where((c) => c.id == widget.categoryId).firstOrNull;
      if (cat != null) {
        _nameController.text = cat.name;
        _descriptionController.text = cat.description ?? '';
        _sortOrderController.text = cat.sortOrder.toString();
        _parentId = cat.parentId;
        _isActive = cat.isActive;
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

    final sortOrder = int.tryParse(_sortOrderController.text.trim()) ?? 0;

    setState(() {
      _saving = true;
      _error = null;
    });

    final data = <String, dynamic>{
      'name': name,
      'description': _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      'sort_order': sortOrder,
      'is_active': _isActive,
      if (_parentId != null) 'parent_id': _parentId,
    };

    final failure = await ref.read(categoriesProvider.notifier).save(
          data: data,
          id: widget.categoryId,
        );

    if (!mounted) return;

    if (failure != null) {
      setState(() {
        _saving = false;
        if (failure is DuplicateSkuFailure) {
          _error = 'A category with this name already exists.';
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
    final lum = context.lum;
    final categories = ref.watch(categoriesProvider).value ?? <Category>[];

    final parentOptions =
        categories.where((c) => c.id != widget.categoryId).toList();

    return AppDetailScaffold(
      eyebrow: 'Inventory',
      title: _isEditing ? 'Edit category' : 'New category',
      maxContentWidth: 720,
      child: _loadingExisting
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
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
                        prefixIcon: LucideIcons.tag,
                        hint: 'e.g. Beverages',
                      ),
                      const SizedBox(height: 16),
                      _LabeledField(
                        label: 'Parent category',
                        child: AppDropdown<String?>(
                          value: _parentId,
                          placeholder: 'None (top-level)',
                          options: [
                            const AppDropdownOption<String?>(
                              value: null,
                              label: 'None (top-level)',
                            ),
                            for (final c in parentOptions)
                              AppDropdownOption<String?>(
                                value: c.id,
                                label: c.name,
                              ),
                          ],
                          onSelected: (v) => setState(() => _parentId = v),
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _descriptionController,
                        label: 'Description',
                        prefixIcon: LucideIcons.text,
                        hint: 'Optional',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _sortOrderController,
                        label: 'Sort order',
                        prefixIcon: LucideIcons.arrowUpDown,
                        keyboardType: TextInputType.number,
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
                                      fontSize: 14.5, color: lum.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Show this category in pickers and reports',
                                  style: AppTypography.subhead
                                      .copyWith(color: lum.g500),
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
                const SizedBox(height: 12),
                AppButton(
                  label: 'Cancel',
                  variant: AppButtonVariant.plain,
                  fullWidth: true,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
    );
  }
}

/// A field label rendered in the AppTextField label style, stacked over a
/// non-text control (the parent-category dropdown) so it aligns with the text
/// fields above and below it.
class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(label,
              style: AppTypography.fieldLabel.copyWith(color: lum.g700)),
        ),
        child,
      ],
    );
  }
}
