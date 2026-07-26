import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_filter_chips.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../suppliers/domain/entities/supplier.dart';
import '../../../suppliers/presentation/controllers/suppliers_controller.dart';
import '../../domain/entities/purchase_return.dart';
import '../controllers/purchase_returns_controller.dart';
import '../widgets/purchasing_ui.dart';

class PurchaseReturnsPage extends ConsumerWidget {
  const PurchaseReturnsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(purchaseReturnsProvider);
    final active = ref.watch(purchaseReturnsProvider.notifier).statusFilter;
    final suppliers = ref.watch(suppliersProvider).value ?? const <Supplier>[];

    const statuses = PurchaseReturnStatus.values;
    final labels = ['All', for (final s in statuses) returnStatusPill(s).$2];
    final selected = active == null ? 0 : statuses.indexOf(active) + 1;
    void onSelected(int i) => ref
        .read(purchaseReturnsProvider.notifier)
        .setStatus(i == 0 ? null : statuses[i - 1]);

    return AppDetailScaffold(
      eyebrow: 'Purchasing',
      title: 'Purchase returns',
      description: 'Reached from a PO or a bill — debit notes to suppliers.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppFilterChips(
            labels: labels,
            selected: selected,
            onSelected: onSelected,
          ),
          const SizedBox(height: 18),
          switch (state) {
            AsyncError() => AppErrorState(
                title: 'Unable to load purchase returns',
                body: 'Unable to load suggestions. Check your connection and try again.',
                onRetry: () =>
                    ref.read(purchaseReturnsProvider.notifier).refresh(),
              ),
            AsyncData(:final value) when value.isEmpty => const AppEmptyState(
                icon: LucideIcons.undo2,
                title: 'No returns',
                body: 'Open a received PO or a bill and tap Return to send '
                    'goods back to a supplier.',
              ),
            AsyncData(:final value) => Column(
                children: [
                  for (final r in value) ...[
                    _ReturnCard(
                      ret: r,
                      supplierName: _supplierName(suppliers, r.supplierId),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            _ => const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              ),
          },
        ],
      ),
    );
  }

  static String _supplierName(List<Supplier> suppliers, String id) =>
      suppliers.where((s) => s.id == id).map((s) => s.name).firstOrNull ??
      'Supplier ${id.substring(0, 6)}';
}

class _ReturnCard extends StatelessWidget {
  const _ReturnCard({required this.ret, required this.supplierName});
  final PurchaseReturn ret;
  final String supplierName;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final (tone, label) = returnStatusPill(ret.status);
    final reason = ret.reason?.trim();

    return AppCard(
      onTap: () => context.push('/purchasing/returns/${ret.id}'),
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ret.returnNumber,
                        style: AppTypography.monoValue.copyWith(
                          fontSize: 15,
                          color: lum.textPrimary,
                        ),
                      ),
                    ),
                    AppPill(label: label, tone: tone),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  supplierName,
                  style: AppTypography.subhead.copyWith(color: lum.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  '${ymd(ret.returnDate)} · '
                  '${reason == null || reason.isEmpty ? 'No reason' : reason}',
                  style: AppTypography.footnote.copyWith(color: lum.g500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          AppMoneyText(ret.totalAmount, size: 18, color: lum.dangerText),
        ],
      ),
    );
  }
}
