import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_sheet.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/journal_entry.dart';
import '../../domain/entities/journal_line.dart';
import '../controllers/chart_of_accounts_controller.dart';
import '../controllers/journal_controller.dart';
import '../widgets/acct_date_field.dart';
import '../widgets/accounting_ui.dart';

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
      showAppToast(context, failure.message, type: BannerType.error);
      return;
    }
    showAppToast(context, 'Entry reversed', type: BannerType.success);
    ref.invalidate(journalEntryDetailProvider(entryId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(journalEntryDetailProvider(entryId));
    final accounts = ref.watch(chartOfAccountsProvider);

    return AppDetailScaffold(
      eyebrow: 'Accounting',
      title: 'Journal entry',
      child: state.when(
        loading: () => const Padding(
          padding: EdgeInsets.only(top: 60),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.only(top: 30),
          child: AppErrorState(
            title: 'Unable to load entry',
            body: 'Check your connection and try again.',
            onRetry: () => ref.invalidate(journalEntryDetailProvider(entryId)),
          ),
        ),
        data: (record) {
          final (entry, lines) = record;
          if (entry == null) {
            return const Padding(
              padding: EdgeInsets.only(top: 20),
              child: AppEmptyState(
                icon: LucideIcons.fileQuestion,
                title: 'Entry not found',
                body: 'This journal entry is no longer available.',
              ),
            );
          }
          final byId = <String, Account>{
            for (final a in accounts.value ?? const <Account>[]) a.id: a,
          };
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DetailCard(entry: entry, lines: lines, accounts: byId),
              const SizedBox(height: 16),
              PermissionGate(
                module: 'accounting',
                action: 'approve',
                child: AppButton(
                  label: 'Reverse entry',
                  variant: AppButtonVariant.destructive,
                  fullWidth: true,
                  icon: LucideIcons.undo2,
                  onPressed: () => _reverse(context, ref),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Future<String?> _promptReason(BuildContext context) {
  final controller = TextEditingController();
  return showAppSheet<String>(
    context: context,
    builder: (ctx) {
      final lum = ctx.lum;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Reverse entry',
              style: AppTypography.title3.copyWith(color: lum.textPrimary)),
          const SizedBox(height: 8),
          Text(
            'This posts an equal and opposite entry. The original stays on '
            'record. Tell us why.',
            style: AppTypography.body.copyWith(color: lum.g600, height: 1.5),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: controller,
            label: 'Reason',
            prefixIcon: LucideIcons.pencil,
            hint: 'e.g. Duplicate posting',
            maxLines: 2,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Cancel',
                  variant: AppButtonVariant.tinted,
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Reverse',
                  variant: AppButtonVariant.destructive,
                  icon: LucideIcons.undo2,
                  onPressed: () =>
                      Navigator.of(ctx).pop(controller.text.trim()),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.entry,
    required this.lines,
    required this.accounts,
  });

  final JournalEntry entry;
  final List<JournalLine> lines;
  final Map<String, Account> accounts;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final totalDebit = lines.fold<double>(0, (s, l) => s + l.debit);
    final totalCredit = lines.fold<double>(0, (s, l) => s + l.credit);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.entryNumber,
                        style: TextStyle(
                          fontFamily: AppTypography.mono,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: lum.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${acctFormatDate(entry.createdAt)} · '
                        '${acctRefLabel(entry.referenceType)}',
                        style: AppTypography.subhead.copyWith(color: lum.g500),
                      ),
                    ],
                  ),
                ),
                AppPill(
                  label: entry.isReversing ? 'Reversing' : 'Posted',
                  tone:
                      entry.isReversing ? AppPillTone.warning : AppPillTone.success,
                ),
              ],
            ),
          ),
          if (entry.description != null && entry.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
              child: Text(
                entry.description!,
                style: AppTypography.body.copyWith(
                  fontSize: 14.5,
                  color: lum.textPrimary,
                ),
              ),
            ),
          Container(
            decoration: acctHeaderRowDecoration(context),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            child: Row(
              children: [
                Expanded(child: Text('ACCOUNT', style: acctHeaderColStyle(context))),
                SizedBox(
                  width: 90,
                  child: Text('DEBIT',
                      style: acctHeaderColStyle(context),
                      textAlign: TextAlign.right),
                ),
                SizedBox(
                  width: 90,
                  child: Text('CREDIT',
                      style: acctHeaderColStyle(context),
                      textAlign: TextAlign.right),
                ),
              ],
            ),
          ),
          for (final l in lines) _LineRow(line: l, account: accounts[l.accountId]),
          Container(
            color: lum.surface2,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text('Total',
                      style: AppTypography.subhead.copyWith(
                          fontWeight: FontWeight.w700, color: lum.textPrimary)),
                ),
                SizedBox(
                  width: 90,
                  child: AcctMono(formatAmount(totalDebit, decimals: 0),
                      weight: FontWeight.w700, size: 13),
                ),
                SizedBox(
                  width: 90,
                  child: AcctMono(formatAmount(totalCredit, decimals: 0),
                      weight: FontWeight.w700, size: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line, required this.account});
  final JournalLine line;
  final Account? account;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final debitStr = line.debit == 0 ? '—' : formatAmount(line.debit, decimals: 0);
    final creditStr =
        line.credit == 0 ? '—' : formatAmount(line.credit, decimals: 0);
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: lum.hairline)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  account?.name ?? 'Account',
                  style: AppTypography.subhead
                      .copyWith(fontSize: 14, color: lum.textPrimary),
                ),
                if (account != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: AcctMono(account!.code,
                        align: TextAlign.left, size: 11.5, color: lum.g500),
                  ),
              ],
            ),
          ),
          SizedBox(width: 90, child: AcctMono(debitStr)),
          SizedBox(width: 90, child: AcctMono(creditStr)),
        ],
      ),
    );
  }
}
