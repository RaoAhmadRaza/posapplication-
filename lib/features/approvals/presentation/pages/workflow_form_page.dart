import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/entities/approval.dart';
import '../controllers/workflows_controller.dart';
import '../widgets/approval_status_ui.dart';

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
      setState(() => _error = 'Name is required.');
      return;
    }
    if (_levels.isEmpty) {
      setState(() => _error = 'Add at least one approval level.');
      return;
    }
    if (_levels.any((l) => l.requiredRole == null)) {
      setState(() => _error = 'Every level needs a required role.');
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
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_isEdit ? 'Edit Workflow' : 'New Workflow',
            style: AppTypography.headline),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            _label('Type'),
            _TypeDropdown(
              value: _type,
              // type is immutable once created (identity of the config).
              enabled: !_isEdit,
              onChanged: (t) => setState(() => _type = t),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
                controller: _nameCtrl, label: 'Name', prefixIcon: Icons.label),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
                controller: _descCtrl,
                label: 'Description (optional)',
                prefixIcon: Icons.notes),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _thresholdCtrl,
              label: 'Threshold amount (blank = always)',
              prefixIcon: Icons.attach_money,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _ttlCtrl,
              label: 'Escalation TTL (hours)',
              prefixIcon: Icons.timer_outlined,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text('Active',
                      style: AppTypography.subhead
                          .copyWith(fontWeight: FontWeight.w600)),
                ),
                Switch(
                  value: _active,
                  activeThumbColor: AppColors.accent,
                  onChanged: (v) => setState(() => _active = v),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(child: _label('Levels')),
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _levels.add(_LevelDraft())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add level'),
                ),
              ],
            ),
            for (var i = 0; i < _levels.length; i++)
              _LevelEditor(
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
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppInlineBanner(message: _error!, type: BannerType.error),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
                label: 'Save',
                fullWidth: true,
                loading: _saving,
                onPressed: _saving ? null : _save),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text(text, style: AppTypography.fieldLabel),
      );
}

class _TypeDropdown extends StatelessWidget {
  const _TypeDropdown(
      {required this.value, required this.enabled, required this.onChanged});
  final ApprovalWorkflowType value;
  final bool enabled;
  final ValueChanged<ApprovalWorkflowType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ApprovalWorkflowType>(
          isExpanded: true,
          value: value,
          items: [
            for (final t in ApprovalWorkflowType.values)
              DropdownMenuItem(value: t, child: Text(approvalTypeLabels[t]!)),
          ],
          onChanged: enabled ? (t) => t == null ? null : onChanged(t) : null,
        ),
      ),
    );
  }
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
    final rolesAsync = ref.watch(tenantRoleNamesProvider);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Level ${index + 1}',
                  style: AppTypography.subhead
                      .copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.arrow_upward, size: 18),
                color: canMoveUp ? AppColors.accent : AppColors.textMuted,
                onPressed: canMoveUp ? onMoveUp : null,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.arrow_downward, size: 18),
                color: canMoveDown ? AppColors.accent : AppColors.textMuted,
                onPressed: canMoveDown ? onMoveDown : null,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, size: 18),
                color:
                    canRemove ? AppColors.destructive : AppColors.textMuted,
                onPressed: canRemove ? onRemove : null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          rolesAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => Text('Could not load roles.',
                style: AppTypography.caption
                    .copyWith(color: AppColors.destructive)),
            data: (roles) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: draft.requiredRole,
                  hint: Text('Required role',
                      style: AppTypography.fieldHint),
                  items: [
                    for (final r in roles)
                      DropdownMenuItem(value: r, child: Text(r)),
                  ],
                  onChanged: (v) {
                    draft.requiredRole = v;
                    onChanged();
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text('Min approvers',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textMuted)),
              const Spacer(),
              _Stepper(
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
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove_circle_outline, size: 20),
          color: value > 1 ? AppColors.accent : AppColors.textMuted,
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
        ),
        Text('$value',
            style:
                AppTypography.subhead.copyWith(fontWeight: FontWeight.w600)),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add_circle_outline, size: 20),
          color: AppColors.accent,
          onPressed: () => onChanged(value + 1),
        ),
      ],
    );
  }
}
