import 'dart:convert';
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
import '../controllers/barcode_templates_controller.dart';

class BarcodeTemplateFormPage extends ConsumerStatefulWidget {
  const BarcodeTemplateFormPage({super.key, this.templateId});
  final String? templateId;

  @override
  ConsumerState<BarcodeTemplateFormPage> createState() =>
      _BarcodeTemplateFormPageState();
}

class _BarcodeTemplateFormPageState
    extends ConsumerState<BarcodeTemplateFormPage> {
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
      final t =
          state.value!.where((b) => b.id == widget.templateId).firstOrNull;
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
    if (name.isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }

    Map<String, dynamic> layout;
    try {
      layout = jsonDecode(_layoutCtrl.text.trim()) as Map<String, dynamic>;
    } catch (_) {
      setState(() => _error = 'Layout must be valid JSON.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final data = <String, dynamic>{
      'name': name,
      'format': _format,
      'width_mm': int.tryParse(_widthCtrl.text.trim()) ?? 50,
      'height_mm': int.tryParse(_heightCtrl.text.trim()) ?? 25,
      'layout_json': layout,
      'is_default': _isDefault,
    };

    final failure = await ref
        .read(barcodeTemplatesProvider.notifier)
        .save(data: data, id: widget.templateId);
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

    return AppDetailScaffold(
      eyebrow: 'Inventory',
      title: _isEditing ? 'Edit template' : 'New template',
      child: _loadingExisting
          ? const Padding(
              padding: EdgeInsets.only(top: 80),
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
                  eyebrow: 'Template',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        controller: _nameCtrl,
                        label: 'Template name',
                        prefixIcon: LucideIcons.tag,
                        hint: 'e.g. Standard Label',
                      ),
                      const SizedBox(height: 16),
                      _labeled(
                        lum,
                        'Format',
                        AppDropdown<String>(
                          value: _format,
                          options: const [
                            AppDropdownOption(
                                value: 'CODE128', label: 'CODE128'),
                            AppDropdownOption(value: 'EAN13', label: 'EAN13'),
                            AppDropdownOption(value: 'QR', label: 'QR'),
                          ],
                          onSelected: (v) => setState(() => _format = v),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _widthCtrl,
                              label: 'Width (mm)',
                              prefixIcon: LucideIcons.moveHorizontal,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: AppTextField(
                              controller: _heightCtrl,
                              label: 'Height (mm)',
                              prefixIcon: LucideIcons.moveVertical,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _layoutCtrl,
                        label: 'Layout (JSON)',
                        prefixIcon: LucideIcons.braces,
                        hint: '{"showPrice": true}',
                        maxLines: 5,
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Default template',
                                  style: AppTypography.headline.copyWith(
                                      fontSize: 14.5,
                                      color: lum.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Use for new barcode prints',
                                  style: AppTypography.subhead
                                      .copyWith(color: lum.g500),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          AppToggle(
                            value: _isDefault,
                            onChanged: (v) => setState(() => _isDefault = v),
                            semanticLabel: 'Default template',
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
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
    );
  }

  Widget _labeled(LumColors lum, String label, Widget control) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(label,
                style: AppTypography.fieldLabel.copyWith(color: lum.g700)),
          ),
          control,
        ],
      );
}
