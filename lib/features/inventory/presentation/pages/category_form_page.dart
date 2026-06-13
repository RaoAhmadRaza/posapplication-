import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
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
    final categories = ref.watch(categoriesProvider).value ?? <Category>[];

    final parentOptions = categories
        .where((c) => c.id != widget.categoryId)
        .toList();

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
          _isEditing ? 'Edit Category' : 'New Category',
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
                      prefixIcon: Icons.category,
                      hint: 'e.g. Beverages',
                    ),
                    const SizedBox(height: AppSpacing.fieldGap),
                    _ParentPicker(
                      parentId: _parentId,
                      categories: parentOptions,
                      onChanged: (v) => setState(() => _parentId = v),
                    ),
                    const SizedBox(height: AppSpacing.fieldGap),
                    AppTextField(
                      controller: _descriptionController,
                      label: 'Description',
                      prefixIcon: Icons.description,
                      hint: 'Optional',
                    ),
                    const SizedBox(height: AppSpacing.fieldGap),
                    AppTextField(
                      controller: _sortOrderController,
                      label: 'Sort Order',
                      prefixIcon: Icons.sort,
                      keyboardType: TextInputType.number,
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

class _ParentPicker extends StatelessWidget {
  const _ParentPicker({
    required this.parentId,
    required this.categories,
    required this.onChanged,
  });

  final String? parentId;
  final List<Category> categories;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Parent Category', style: AppTypography.fieldLabel),
        ),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.fieldFill,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: parentId,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
              hint: Text(
                'None (top-level)',
                style: AppTypography.fieldHint,
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('None (top-level)'),
                ),
                ...categories.map((c) => DropdownMenuItem<String?>(
                      value: c.id,
                      child: Text(c.name),
                    )),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
