import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../domain/entities/journal_entry.dart';
import '../controllers/journal_controller.dart';
import '../widgets/acct_date_field.dart';
import '../widgets/accounting_ui.dart';

class JournalEntriesPage extends ConsumerWidget {
  const JournalEntriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(journalEntriesProvider);

    return AppDetailScaffold(
      eyebrow: 'Accounting',
      title: 'Journal entries',
      actions: [
        AppButton(
          label: 'New voucher',
          icon: LucideIcons.plus,
          size: AppButtonSize.sm,
          onPressed: () => context.push('/accounting/vouchers/create'),
        ),
      ],
      child: state.when(
        loading: () => const Padding(
          padding: EdgeInsets.only(top: 60),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.only(top: 30),
          child: AppErrorState(
            title: 'Unable to load entries',
            body: 'Check your connection and try again.',
            onRetry: () => ref.read(journalEntriesProvider.notifier).refresh(),
          ),
        ),
        data: (entries) => entries.isEmpty
            ? const Padding(
                padding: EdgeInsets.only(top: 20),
                child: AppEmptyState(
                  icon: LucideIcons.notebookPen,
                  title: 'No journal entries yet',
                  body: 'Post your first voucher and it\'ll show up here.',
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final e in entries) ...[
                    _EntryCard(entry: e),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});
  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return AppCard(
      onTap: () => context.push('/accounting/journal/${entry.id}'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                entry.entryNumber,
                style: TextStyle(
                  fontFamily: AppTypography.mono,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: lum.textPrimary,
                ),
              ),
              const SizedBox(width: 9),
              AppPill(
                label: acctRefLabel(entry.referenceType),
                tone: acctRefTone(entry.referenceType),
                showDot: false,
              ),
              if (entry.isReversing) ...[
                const SizedBox(width: 6),
                const AppPill(
                  label: 'Reversing',
                  tone: AppPillTone.warning,
                  showDot: false,
                ),
              ],
              const Spacer(),
              AcctMono(
                acctFormatDate(entry.createdAt),
                align: TextAlign.right,
                size: 12,
                color: lum.g500,
                weight: FontWeight.w500,
              ),
            ],
          ),
          if (entry.description != null && entry.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              entry.description!,
              style: AppTypography.body.copyWith(fontSize: 14, color: lum.g700),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [AppMoneyText(entry.total, size: 14)],
          ),
        ],
      ),
    );
  }
}
