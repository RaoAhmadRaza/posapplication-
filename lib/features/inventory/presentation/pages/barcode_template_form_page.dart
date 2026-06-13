import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../controllers/barcode_templates_controller.dart';

class BarcodeTemplateFormPage extends ConsumerStatefulWidget {
  const BarcodeTemplateFormPage({super.key, this.templateId});
  final String? templateId;

  @override
  ConsumerState<BarcodeTemplateFormPage> createState() => _BarcodeTemplateFormPageState();
}

class _BarcodeTemplateFormPageState extends ConsumerState<BarcodeTemplateFormPage> {
  final _nameCtrl = TextEditingController();
  final _widthCtrl = TextEditingController(text: '50');
  final _heightCtrl = TextEditingController(text: '25');
  final _layoutCtrl = TextEditingController(text: '{}');
  String _format = 'CODE128';
  bool _isDefault = false;
  String? _error;
  bool _saving = false;
  bool _loadingExisting = false;

  bool get _isEditing => widget.templateId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadExisting();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    _layoutCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    setState(() => _loadingExisting = true);
    final state = ref.read(barcodeTemplatesProvider);
    if (state.value != null) {
      final t = state.value!.where((b) => b.id == widget.templateId).firstOrNull;
      if (t != null) {
        _nameCtrl.text = t.name;
        _format = t.format;
        _widthCtrl.text = t.widthMm.toString();
        _heightCtrl.text = t.heightMm.toString();
        _layoutCtrl.text = jsonEncode(t.layout);
        _isDefault = t.isDefault;
      }
    }
    setState(() => _loadingExisting = false);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) { setState(() => _error = 'Name is required.'); return; }

    Map<String, dynamic> layout;
    try {
      layout = jsonDecode(_layoutCtrl.text.trim()) as Map<String, dynamic>;
    } catch (_) {
      setState(() => _error = 'Layout must be valid JSON.'); return;
    }

    setState(() { _saving = true; _error = null; });

    final data = <String, dynamic>{
      'name': name,
      'format': _format,
      'width_mm': int.tryParse(_widthCtrl.text.trim()) ?? 50,
      'height_mm': int.tryParse(_heightCtrl.text.trim()) ?? 25,
      'layout_json': layout,
      'is_default': _isDefault,
    };

    final failure = await ref.read(barcodeTemplatesProvider.notifier).save(data: data, id: widget.templateId);
    if (!mounted) return;
    if (failure != null) {
      setState(() { _saving = false; _error = failure.message; });
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
        title: Text(_isEditing ? 'Edit Template' : 'New Template', style: AppTypography.headline),
      ),
      body: _loadingExisting
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const SizedBox(height: AppSpacing.lg),
                  if (_error != null) ...[
                    AppInlineBanner(message: _error!, type: BannerType.error),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  AppTextField(controller: _nameCtrl, label: 'Name', prefixIcon: Icons.label, hint: 'e.g. Standard Label'),
                  const SizedBox(height: AppSpacing.fieldGap),
                  _DropdownField(label: 'Format', value: _format, items: const ['CODE128', 'EAN13', 'QR'], onChanged: (v) => setState(() => _format = v)),
                  const SizedBox(height: AppSpacing.fieldGap),
                  Row(children: [
                    Expanded(child: AppTextField(controller: _widthCtrl, label: 'Width (mm)', prefixIcon: Icons.straighten, keyboardType: TextInputType.number)),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: AppTextField(controller: _heightCtrl, label: 'Height (mm)', prefixIcon: Icons.height, keyboardType: TextInputType.number)),
                  ]),
                  const SizedBox(height: AppSpacing.fieldGap),
                  AppTextField(controller: _layoutCtrl, label: 'Layout (JSON)', prefixIcon: Icons.code, hint: '{"showPrice": true}'),
                  const SizedBox(height: AppSpacing.fieldGap),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero, title: Text('Default', style: AppTypography.body),
                    value: _isDefault, activeThumbColor: AppColors.accent,
                    onChanged: (v) => setState(() => _isDefault = v),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  AppButton(label: _isEditing ? 'Update' : 'Create', loading: _saving, onPressed: _save),
                  const SizedBox(height: AppSpacing.xxl),
                ]),
              ),
            ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({required this.label, required this.value, required this.items, required this.onChanged});
  final String label, value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(label, style: AppTypography.fieldLabel)),
      Container(
        height: 52, padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: AppColors.fieldFill, borderRadius: BorderRadius.circular(12)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value, isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
            items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
            onChanged: (v) { if (v != null) onChanged(v); },
          ),
        ),
      ),
    ]);
  }
}
