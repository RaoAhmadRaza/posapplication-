import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_dropdown.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_qty_stepper.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/design/widgets/app_toggle.dart';
import '../../domain/entities/approval.dart';
import '../controllers/workflows_controller.dart';
import '../widgets/approvals_ui.dart';

/// A mutable draft of one approval level (level number is positional).
class _LevelDraft {
  String? requiredRole;
  int minApprovers;
  _LevelDraft({this.requiredRole, this.minApprovers = 1});
}

class WorkflowFormPage extends ConsumerStatefulWidget {
  const WorkflowFormPage({super.key, this.workflow});
  final ApprovalWorkflow? workflow;

  @override
  ConsumerState<WorkflowFormPage> createState() => _WorkflowFormPageState();
}

class _WorkflowFormPageState extends ConsumerState<WorkflowFormPage> {
  late ApprovalWorkflowType _type;
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _thresholdCtrl = TextEditingController();
  final _ttlCtrl = TextEditingController(text: '24');
  late bool _active;
  final List<_LevelDraft> _levels = [];
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.workflow != null;

  @override
  void initState() {
    super.initState();
    final w = widget.workflow;
    _type = w?.workflowType ?? ApprovalWorkflowType.purchaseOrder;
    _active = w?.isActive ?? true;
    if (w != null) {
      _nameCtrl.text = w.name;
      _descCtrl.text = w.description ?? '';
      _thresholdCtrl.text =
          w.thresholdAmount == null ? '' : w.thresholdAmount!.toString();
      _ttlCtrl.text = w.escalationTtlHours.toString();
      for (final l in w.levels) {
        _levels.add(_LevelDraft(
            requiredRole: l.requiredRole, minApprovers: l.minApprovers));
      }
    }
    if (_levels.isEmpty) _levels.add(_LevelDraft());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _thresholdCtrl.dispose();
    _ttlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the workflow a name.');
      return;
    }
    if (_levels.isEmpty) {
      setState(() => _error = 'Add at least one approval level.');
      return;
    }
    if (_levels.any((l) => l.requiredRole == null)) {
      setState(() => _error = 'Add a name and a role for every level before saving.');
      return;
    }
    final levels = [
      for (var i = 0; i < _levels.length; i++)
        ApprovalLevel(
          level: i + 1,
          requiredRole: _levels[i].requiredRole!,
          minApprovers:
              _levels[i].minApprovers < 1 ? 1 : _levels[i].minApprovers,
        ),
    ];
    setState(() {
      _saving = true;
      _error = null;
    });
    final threshold = _thresholdCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(_thresholdCtrl.text.trim());
    final ttl = int.tryParse(_ttlCtrl.text.trim()) ?? 24;
    final failure =
        await ref.read(workflowsControllerProvider.notifier).upsert(
              id: widget.workflow?.id,
              type: _type,
              name: name,
              description: _descCtrl.text.trim().isEmpty
                  ? null
                  : _descCtrl.text.trim(),
              thresholdAmount: threshold,
              levels: levels,
              escalationTtlHours: ttl,
              isActive: _active,
            );
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _saving = false;
        _error = failure.message;
      });
      return;
    }
    showAppToast(
      context,
      _isEdit ? 'Workflow saved' : 'Workflow created',
      type: BannerType.success,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;

    return AppDetailScaffold(
      eyebrow: 'Workflows',
      title: _isEdit ? 'Edit workflow' : 'New workflow',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _fieldLabel('Request type', lum),
                const SizedBox(height: 8),
                AppDropdown<ApprovalWorkflowType>(
                  value: _type,
                  enabled: !_isEdit,
                  options: [
                    for (final t in ApprovalWorkflowType.values)
                      AppDropdownOption(
                          value: t, label: approvalTypeLabels[t]!),
                  ],
                  onSelected: (t) => setState(() => _type = t),
                ),
                if (_isEdit) ...[
                  const SizedBox(height: 7),
                  Text(
                    "Type can't change once a workflow is created.",
                    style: AppTypography.caption.copyWith(color: lum.g500),
                  ),
                ],
                const SizedBox(height: 16),
                AppTextField(
                  controller: _nameCtrl,
                  label: 'Name',
                  hint: 'e.g. Standard PO approval',
                  prefixIcon: Icons.label_outline,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _descCtrl,
                  label: 'Description',
                  hint: 'Optional — what this covers',
                  prefixIcon: Icons.notes,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _thresholdCtrl,
                  label: 'Threshold amount',
                  hint: 'Blank = always required',
                  helperText: 'Blank = every request needs approval',
                  prefixIcon: Icons.attach_money,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _ttlCtrl,
                  label: 'Escalation TTL (hours)',
                  prefixIcon: Icons.timer_outlined,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active',
                            style: AppTypography.subhead.copyWith(
                              fontWeight: FontWeight.w600,
                              color: lum.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Route matching requests through this ladder',
                            style:
                                AppTypography.caption.copyWith(color: lum.g500),
                          ),
                        ],
                      ),
                    ),
                    AppToggle(
                      value: _active,
                      semanticLabel: 'Workflow active',
                      onChanged: (v) => setState(() => _active = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Approval levels',
                        style: AppTypography.title3.copyWith(
                          fontSize: 16,
                          color: lum.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${_levels.length} ${_levels.length == 1 ? 'level' : 'levels'}',
                      style: AppTypography.caption.copyWith(color: lum.g500),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < _levels.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _LevelEditor(
                      index: i,
                      draft: _levels[i],
                      canMoveUp: i > 0,
                      canMoveDown: i < _levels.length - 1,
                      canRemove: _levels.length > 1,
                      onChanged: () => setState(() {}),
                      onMoveUp: () => setState(() {
                        final l = _levels.removeAt(i);
                        _levels.insert(i - 1, l);
                      }),
                      onMoveDown: () => setState(() {
                        final l = _levels.removeAt(i);
                        _levels.insert(i + 1, l);
                      }),
                      onRemove: () => setState(() => _levels.removeAt(i)),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppButton(
                    label: 'Add level',
                    variant: AppButtonVariant.plain,
                    icon: LucideIcons.plus,
                    onPressed: () => setState(() => _levels.add(_LevelDraft())),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            AppInlineBanner(message: _error!, type: BannerType.error),
          ],
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppButton(
                label: 'Cancel',
                variant: AppButtonVariant.tinted,
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 12),
              AppButton(
                label: _isEdit ? 'Save workflow' : 'Create workflow',
                icon: LucideIcons.check,
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text, LumColors lum) => Text(
        text,
        style: AppTypography.subhead.copyWith(
          fontWeight: FontWeight.w600,
          color: lum.g700,
        ),
      );
}

class _LevelEditor extends ConsumerWidget {
  const _LevelEditor({
    required this.index,
    required this.draft,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.canRemove,
    required this.onChanged,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });
  final int index;
  final _LevelDraft draft;
  final bool canMoveUp;
  final bool canMoveDown;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final rolesAsync = ref.watch(tenantRoleNamesProvider);
    final roles = rolesAsync.value ?? const <String>[];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: lum.paper,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: lum.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'LEVEL ${index + 1}',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: lum.g600,
                  ),
                ),
              ),
              _iconBtn(LucideIcons.chevronUp, canMoveUp, onMoveUp, lum,
                  'Move up'),
              _iconBtn(LucideIcons.chevronDown, canMoveDown, onMoveDown, lum,
                  'Move down'),
              _iconBtn(LucideIcons.trash2, canRemove, onRemove, lum,
                  'Remove level',
                  danger: true),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Required role',
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: lum.g700,
            ),
          ),
          const SizedBox(height: 7),
          rolesAsync.hasError
              ? Text(
                  'Could not load roles.',
                  style:
                      AppTypography.caption.copyWith(color: lum.dangerText),
                )
              : AppDropdown<String>(
                  value: draft.requiredRole,
                  placeholder: 'Select a role…',
                  options: [
                    for (final r in roles)
                      AppDropdownOption(value: r, label: r),
                  ],
                  onSelected: (v) {
                    draft.requiredRole = v;
                    onChanged();
                  },
                ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Min. approvers',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: lum.g700,
                  ),
                ),
              ),
              AppQtyStepper(
                value: draft.minApprovers,
                onChanged: (v) {
                  draft.minApprovers = v;
                  onChanged();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(
    IconData icon,
    bool enabled,
    VoidCallback onTap,
    LumColors lum,
    String tooltip, {
    bool danger = false,
  }) {
    final color = !enabled
        ? lum.g300
        : danger
            ? lum.danger
            : lum.g600;
    return IconButton(
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, size: 18, color: color),
      tooltip: tooltip,
      onPressed: enabled ? onTap : null,
    );
  }
}
