import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/design/widgets/app_confirm_dialog.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/widgets/module_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_ledger.dart';
import '../../domain/usecases/load_customer.dart';
import '../controllers/customers_controller.dart';
import '../widgets/customer_card.dart';
import '../widgets/customer_ledger_card.dart';

final _customerProvider =
    FutureProvider.autoDispose.family<Customer, String>((ref, id) async {
  final (customer, failure) =
      await ref.read(loadCustomerUseCaseProvider).call(id);
  if (failure != null) throw failure;
  return customer!;
});

class CustomerDetailPage extends ConsumerWidget {
  const CustomerDetailPage({super.key, required this.customerId});
  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(_customerProvider(customerId));

    return ModuleScaffold(
      title: customerAsync.value?.name ?? 'Customer',
      maxContentWidth: 900,
      leading: _BackButton(),
      actions: [
        PermissionGate(
          module: 'sales',
          action: 'create',
          child: _IconAction(
            icon: LucideIcons.handCoins,
            tooltip: 'Collect payment',
            accent: true,
            onTap: () => customerAsync.whenData((c) {
              context.push('/customers/$customerId/collect',
                  extra: {'customerName': c.name});
            }),
          ),
        ),
        PermissionGate(
          module: 'customers',
          action: 'update',
          child: _IconAction(
            icon: LucideIcons.squarePen,
            tooltip: 'Edit',
            onTap: () => context.push('/customers/$customerId/edit'),
          ),
        ),
        PermissionGate(
          module: 'customers',
          action: 'delete',
          child: _IconAction(
            icon: LucideIcons.trash2,
            tooltip: 'Delete',
            destructive: true,
            onTap: () => _confirmDelete(context, ref),
          ),
        ),
        const SizedBox(width: 4),
      ],
      child: customerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorState(
          icon: LucideIcons.cloudOff,
          title: "We couldn't load this customer",
          body: 'Something went wrong reaching the server. Your data is safe '
              '— try again in a moment.',
          retryLabel: 'Retry',
          onRetry: () => ref.invalidate(_customerProvider(customerId)),
        ),
        data: (customer) => _Body(customer: customer),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppConfirm(
      context,
      title: 'Delete customer',
      message: 'Soft-delete this customer? They\'ll be hidden from lists but '
          'their history is kept — nothing is permanently removed.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    final failure =
        await ref.read(customersProvider.notifier).remove(customerId);
    if (!context.mounted) return;
    if (failure != null) {
      showAppToast(context, failure.message, type: BannerType.error);
      return;
    }
    showAppToast(context, 'Customer hidden from lists.',
        type: BannerType.success);
    Navigator.of(context).pop();
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.customer});
  final Customer customer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerAsync = ref.watch(customerLedgerProvider(customer.id));
    final isWide = ModuleScaffold.isWideOf(context);

    return ListView(
      padding: EdgeInsets.fromLTRB(
          isWide ? 32 : 16, 12, isWide ? 32 : 16, isWide ? 32 : 24),
      children: [
        _IdentityCard(customer: customer, isWide: isWide),
        const SizedBox(height: 16),
        ledgerAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => AppInlineBanner(
              message: 'Could not load customer ledger.',
              type: BannerType.error),
          data: (ledger) => Column(
            children: [
              _CreditSummaryCard(customer: customer, ledger: ledger),
              const SizedBox(height: 16),
              CustomerLedgerCard(ledger: ledger, isWide: isWide),
              const SizedBox(height: 16),
              _DetailsCard(customer: customer, isWide: isWide),
              if (customer.notes != null &&
                  customer.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                _NotesCard(notes: customer.notes!),
              ],
              if (ledger.outstanding > 0) ...[
                const SizedBox(height: 20),
                PermissionGate(
                  module: 'sales',
                  action: 'create',
                  child: AppButton(
                    label: 'Collect payment',
                    icon: LucideIcons.handCoins,
                    fullWidth: true,
                    onPressed: () => context.push(
                      '/customers/${customer.id}/collect',
                      extra: {'customerName': customer.name},
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Identity card — avatar, name + status, and the contact line the design puts
/// up front. The business/individual label has no backing field and is omitted.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.customer, required this.isWide});
  final Customer customer;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final (statusLabel, tone) = customerStatusUi(customer.status);
    final terms = customer.creditTerms > 0
        ? 'Net ${customer.creditTerms} days'
        : 'Due on receipt';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Explicit accent fill — the lumen clay variant paints none.
              ClayContainer(
                variant: ClayVariant.soft,
                color: lum.accent,
                borderRadius: 18,
                isDark: lum.isDark,
                width: 60,
                height: 60,
                child: Center(
                  child: Text(
                    customerInitials(customer.name),
                    style: AppTypography.title1.copyWith(
                      fontSize: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: AppTypography.title1
                          .copyWith(fontSize: 20, color: lum.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    AppPill(label: statusLabel, tone: tone),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _FieldGrid(
            columns: isWide ? 3 : 1,
            fields: [
              _Field('Phone', customer.phone, mono: true),
              _Field('Email', customer.email),
              _Field('Terms', terms),
            ],
          ),
        ],
      ),
    );
  }
}

/// Credit summary — the design's three stat tiles.
class _CreditSummaryCard extends StatelessWidget {
  const _CreditSummaryCard({required this.customer, required this.ledger});
  final Customer customer;
  final CustomerLedger ledger;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final limit = customer.creditLimit;
    final outstanding = ledger.outstanding;
    final remaining = limit - outstanding;
    final remainingLow = limit > 0 && remaining <= 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Credit summary',
            style: AppTypography.title2
                .copyWith(fontSize: 16, color: lum.textPrimary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatTile(label: 'Credit limit', amount: limit),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(label: 'Outstanding', amount: outstanding),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  label: 'Remaining',
                  amount: limit > 0 ? remaining : null,
                  color: remainingLow ? lum.dangerText : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.amount, this.color});
  final String label;

  /// Null renders an em-dash — used when no credit limit is set, so no false
  /// "remaining" figure is invented.
  final double? amount;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lum.surface2,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.55,
              color: lum.g500,
            ),
          ),
          const SizedBox(height: 8),
          amount == null
              ? Text(
                  '—',
                  style: AppTypography.monoValue
                      .copyWith(fontSize: 20, color: color ?? lum.textPrimary),
                )
              : AppMoneyText(
                  amount!,
                  size: 20,
                  decimals: 2,
                  color: color ?? lum.textPrimary,
                ),
        ],
      ),
    );
  }
}

/// Address, tax number and tags — captured by the form but shown on no other
/// screen. Every value here is a real stored field, none invented.
class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.customer, required this.isWide});
  final Customer customer;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final address = [
      customer.addressLine1,
      customer.addressLine2,
      customer.city,
      customer.state,
      customer.postalCode,
      customer.country,
    ].where((p) => p != null && p.trim().isNotEmpty).join(', ');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Details',
            style: AppTypography.title2
                .copyWith(fontSize: 16, color: lum.textPrimary),
          ),
          const SizedBox(height: 16),
          _FieldGrid(
            columns: isWide ? 2 : 1,
            fields: [
              _Field('Tax number', customer.taxNumber, mono: true),
              _Field('Tags', (customer.tags ?? []).isEmpty
                  ? null
                  : customer.tags!.join(', ')),
            ],
          ),
          const SizedBox(height: 20),
          _FieldGrid(
            columns: 1,
            fields: [_Field('Address', address.isEmpty ? null : address)],
          ),
        ],
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.notes});
  final String notes;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NOTES',
            style: AppTypography.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.55,
              color: lum.g500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            notes,
            style: AppTypography.body.copyWith(color: lum.g700, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _Field {
  const _Field(this.label, this.value, {this.mono = false});
  final String label;
  final String? value;
  final bool mono;
}

/// Fixed-column field grid. The column count is passed by the caller from a
/// width check — never a hand-picked aspect ratio.
class _FieldGrid extends StatelessWidget {
  const _FieldGrid({required this.columns, required this.fields});
  final int columns;
  final List<_Field> fields;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < fields.length; i += columns) {
      final slice = fields.skip(i).take(columns).toList();
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var c = 0; c < columns; c++) ...[
            if (c > 0) const SizedBox(width: 20),
            Expanded(
              child: c < slice.length
                  ? _FieldCell(field: slice[c])
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 20),
          rows[i],
        ],
      ],
    );
  }
}

class _FieldCell extends StatelessWidget {
  const _FieldCell({required this.field});
  final _Field field;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final value = (field.value == null || field.value!.trim().isEmpty)
        ? '—'
        : field.value!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.label.toUpperCase(),
          style: AppTypography.caption.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.55,
            color: lum.g400,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: (field.mono ? AppTypography.monoValue : AppTypography.body)
              .copyWith(fontSize: 14.5, color: lum.textPrimary),
        ),
      ],
    );
  }
}

/// Clay back arrow, matching the design's page header.
class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _IconAction(
      icon: LucideIcons.arrowLeft,
      tooltip: 'Back',
      onTap: () => Navigator.of(context).maybePop(),
      trailingGap: 12,
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.destructive = false,
    this.accent = false,
    this.trailingGap = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool destructive;
  final bool accent;
  final double trailingGap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final tileColor = accent ? lum.accentSoft : lum.surface;
    final iconColor = destructive
        ? lum.dangerText
        : accent
            ? lum.accent
            : lum.g700;
    return Padding(
      padding: EdgeInsets.only(right: trailingGap, left: 4),
      child: Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          label: tooltip,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            // 44dp target around the design's 40px tile.
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: ClayContainer(
                  variant: ClayVariant.soft,
                  color: tileColor,
                  borderRadius: AppRadius.sm,
                  isDark: lum.isDark,
                  width: 40,
                  height: 40,
                  child: Center(
                    child: Icon(icon, size: 19, color: iconColor),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
