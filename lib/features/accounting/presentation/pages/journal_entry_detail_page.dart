import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/journal_entry.dart';
import '../../domain/entities/journal_line.dart';
import '../controllers/chart_of_accounts_controller.dart';
import '../controllers/journal_controller.dart';

class JournalEntryDetailPage extends ConsumerWidget {
  const JournalEntryDetailPage({super.key, required this.entryId});

  final String entryId;

  Future<void> _reverse(BuildContext context, WidgetRef ref) async {
    final reason = await _promptReason(context);
    if (reason == null || reason.isEmpty) return;
    final failure = await ref
        .read(journalControllerProvider.notifier)
        .reverseJournal(entryId: entryId, reason: reason);
    if (!context.mounted) return;
    if (failure != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message)));
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Entry reversed')));
    ref.invalidate(journalEntryDetailProvider(entryId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(journalEntryDetailProvider(entryId));
    final accounts = ref.watch(chartOfAccountsProvider);

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
        title: Text('Journal Entry', style: AppTypography.headline),
      ),
      body: SafeArea(
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPadding),
              child: AppInlineBanner(
                  message: 'Could not load entry.',
                  type: BannerType.error),
            ),
          ),
          data: (record) {
            final (entry, lines) = record;
            if (entry == null) {
              return Center(
                child: Text('Entry not found',
                    style: AppTypography.subhead
                        .copyWith(color: AppColors.textMuted)),
              );
            }
            final names = <String, String>{
              for (final a in accounts.value ?? const <Account>[])
                a.id: '${a.code}  ${a.name}',
            };
            return ListView(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPadding,
                  vertical: AppSpacing.md),
              children: [
                _Header(entry: entry),
                const SizedBox(height: AppSpacing.lg),
                _LinesCard(lines: lines, names: names),
                const SizedBox(height: AppSpacing.xl),
                PermissionGate(
                  module: 'accounting',
                  action: 'approve',
                  child: AppButton(
                    label: 'Reverse Entry',
                    variant: AppButtonVariant.destructive,
                    fullWidth: true,
                    icon: Icons.undo,
                    onPressed: () => _reverse(context, ref),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            );
          },
        ),
      ),
    );
  }
}

Future<String?> _promptReason(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.background,
      title: Text('Reverse Entry', style: AppTypography.headline),
      content: AppTextField(
        controller: controller,
        label: 'Reason',
        prefixIcon: Icons.notes,
        hint: 'Why is this being reversed?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          child: const Text('Reverse'),
        ),
      ],
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.entry});
  final JournalEntry entry;

  String _date(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.entryNumber, style: AppTypography.title2),
          const SizedBox(height: AppSpacing.xs),
          Text(_date(entry.createdAt),
              style: AppTypography.footnote
                  .copyWith(color: AppColors.textMuted)),
          if (entry.description != null &&
              entry.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(entry.description!, style: AppTypography.subhead),
          ],
        ],
      ),
    );
  }
}

class _LinesCard extends StatelessWidget {
  const _LinesCard({required this.lines, required this.names});
  final List<JournalLine> lines;
  final Map<String, String> names;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        children: [
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0)
              const Divider(height: AppSpacing.lg, color: AppColors.separator),
            _LineRow(line: lines[i], names: names),
          ],
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line, required this.names});
  final JournalLine line;
  final Map<String, String> names;

  @override
  Widget build(BuildContext context) {
    final label = names[line.accountId] ??
        line.accountId.substring(0, line.accountId.length.clamp(0, 8));
    final isDebit = line.debit > 0;
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: AppTypography.subhead,
              overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          formatPkr(isDebit ? line.debit : line.credit),
          style: AppTypography.subhead.copyWith(
            fontWeight: FontWeight.w600,
            color: isDebit ? AppColors.success : AppColors.destructive,
          ),
        ),
      ],
    );
  }
}
