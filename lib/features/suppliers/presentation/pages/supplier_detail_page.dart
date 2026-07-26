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
import '../../../../core/design/widgets/app_confirm_dialog.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/widgets/module_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/usecases/load_supplier.dart';
import '../controllers/suppliers_controller.dart';
import '../widgets/supplier_card.dart';
import '../widgets/supplier_ledger_card.dart';

final _supplierProvider =
    FutureProvider.autoDispose.family<Supplier, String>((ref, id) async {
  final (supplier, failure) =
      await ref.read(loadSupplierUseCaseProvider).call(id);
  if (failure != null) throw failure;
  return supplier!;
});

class SupplierDetailPage extends ConsumerWidget {
  const SupplierDetailPage({super.key, required this.supplierId});
  final String supplierId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplierAsync = ref.watch(_supplierProvider(supplierId));

    return ModuleScaffold(
      title: supplierAsync.value?.name ?? 'Supplier',
      maxContentWidth: 900,
      leading: _BackButton(),
      actions: [
        PermissionGate(
          module: 'purchase',
          action: 'update',
          child: _IconAction(
            icon: LucideIcons.pencil,
            tooltip: 'Edit',
            onTap: () => context.push('/suppliers/$supplierId/edit'),
          ),
        ),
        PermissionGate(
          module: 'purchase',
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
      child: supplierAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorState(
          icon: LucideIcons.cloudOff,
          title: "Unable to load this supplier",
          body: 'Unable to reach the server. Try again in a moment.',
          retryLabel: 'Retry',
          onRetry: () => ref.invalidate(_supplierProvider(supplierId)),
        ),
        data: (supplier) => _Body(supplier: supplier),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppConfirm(
      context,
      title: 'Delete supplier',
      message: 'Soft-delete this supplier? It will be hidden from lists. You '
          'can restore it later — nothing is permanently removed.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    final failure = await ref.read(suppliersProvider.notifier).remove(supplierId);
    if (!context.mounted) return;
    if (failure != null) {
      showAppToast(context, failure.message, type: BannerType.error);
      return;
    }
    showAppToast(context, 'Supplier hidden from lists.',
        type: BannerType.success);
    Navigator.of(context).pop();
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.supplier});
  final Supplier supplier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerAsync = ref.watch(supplierLedgerProvider(supplier.id));
    final isWide = ModuleScaffold.isWideOf(context);

    return ListView(
      padding: EdgeInsets.fromLTRB(
          isWide ? 32 : 16, 12, isWide ? 32 : 16, isWide ? 32 : 24),
      children: [
        _IdentityCard(supplier: supplier, isWide: isWide),
        const SizedBox(height: 16),
        _DetailsCard(supplier: supplier, isWide: isWide),
        const SizedBox(height: 16),
        ledgerAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => AppInlineBanner(
              message: 'Unable to load supplier ledger.',
              type: BannerType.error),
          data: (ledger) => SupplierLedgerCard(
            ledger: ledger,
            isWide: isWide,
            footer: PermissionGate(
              module: 'purchase',
              action: 'create',
              child: AppButton(
                label: 'Record payment',
                icon: LucideIcons.banknote,
                variant: AppButtonVariant.tinted,
                fullWidth: !isWide,
                onPressed: () => context.push(
                  '/purchasing/payments/create',
                  extra: {'supplierId': supplier.id},
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Identity card — the four fields the design puts up front.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.supplier, required this.isWide});
  final Supplier supplier;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final (statusLabel, tone) = supplierStatusUi(supplier.status);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                supplier.name,
                style: AppTypography.title1
                    .copyWith(fontSize: 20, color: lum.textPrimary),
              ),
              AppPill(label: statusLabel, tone: tone),
            ],
          ),
          const SizedBox(height: 18),
          _FieldGrid(
            columns: isWide ? 4 : 2,
            fields: [
              _Field('Contact person', supplier.contactPerson),
              _Field('Phone', supplier.phone, mono: true),
              _Field('Email', supplier.email),
              _Field('Payment terms', '${supplier.paymentTerms} days'),
            ],
          ),
        ],
      ),
    );
  }
}

/// The rest of what the form captures. Not in the mock, but the record is
/// otherwise write-only — every value here is a real stored field.
class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.supplier, required this.isWide});
  final Supplier supplier;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final address = [
      supplier.addressLine1,
      supplier.addressLine2,
      supplier.city,
      supplier.state,
      supplier.postalCode,
      supplier.country,
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
            columns: isWide ? 4 : 2,
            fields: [
              _Field('Tax number', supplier.taxNumber, mono: true),
              _Field('Currency', supplier.currency, mono: true),
              _Field('Bank', supplier.bankName),
              _Field('Bank account', supplier.bankAccountNumber, mono: true),
            ],
          ),
          const SizedBox(height: 20),
          _FieldGrid(
            columns: isWide ? 2 : 1,
            fields: [
              _Field('Address', address.isEmpty ? null : address),
              _Field('Tags', (supplier.tags ?? []).isEmpty
                  ? null
                  : supplier.tags!.join(', ')),
            ],
          ),
          const SizedBox(height: 20),
          _FieldGrid(
            columns: 1,
            fields: [_Field('Notes', supplier.notes)],
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
    this.trailingGap = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool destructive;
  final double trailingGap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
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
                  color: lum.surface,
                  borderRadius: AppRadius.sm,
                  isDark: lum.isDark,
                  width: 40,
                  height: 40,
                  child: Center(
                    child: Icon(
                      icon,
                      size: 19,
                      color: destructive ? lum.dangerText : lum.g700,
                    ),
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
