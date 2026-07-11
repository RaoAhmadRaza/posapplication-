import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/supplier.dart';
import '../controllers/suppliers_controller.dart';

const _statusLabels = {
  SupplierStatus.active: 'Active',
  SupplierStatus.inactive: 'Inactive',
  SupplierStatus.blacklisted: 'Blacklisted',
};

class SuppliersPage extends ConsumerStatefulWidget {
  const SuppliersPage({super.key});

  @override
  ConsumerState<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends ConsumerState<SuppliersPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController
        .addListener(() => _onSearchChanged(_searchController.text));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(suppliersProvider.notifier).search(q);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(suppliersProvider);
    final activeStatus = ref.watch(suppliersProvider.notifier).statusFilter;

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
        title: Text('Suppliers', style: AppTypography.headline),
      ),
      floatingActionButton: PermissionGate(
        module: 'purchase',
        action: 'create',
        child: FloatingActionButton.extended(
          backgroundColor: AppColors.accent,
          onPressed: () => context.push('/suppliers/create'),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('New Supplier',
              style: TextStyle(color: Colors.white)),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding,
                  AppSpacing.md, AppSpacing.screenPadding, AppSpacing.sm),
              child: AppTextField(
                controller: _searchController,
                label: 'Search',
                prefixIcon: Icons.search,
                hint: 'Name or phone',
                onSubmitted: (q) =>
                    ref.read(suppliersProvider.notifier).search(q),
              ),
            ),
            _StatusFilterBar(
              active: activeStatus,
              onSelected: (s) =>
                  ref.read(suppliersProvider.notifier).setStatus(s),
            ),
            Expanded(
              child: state.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorState(
                  onRetry: () =>
                      ref.read(suppliersProvider.notifier).refresh(),
                ),
                data: (suppliers) => suppliers.isEmpty
                    ? const _EmptyState()
                    : _SuppliersList(suppliers: suppliers),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({required this.active, required this.onSelected});
  final SupplierStatus? active;
  final ValueChanged<SupplierStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding, vertical: AppSpacing.xs),
        children: [
          _chip(context, 'All', active == null, () => onSelected(null)),
          for (final s in SupplierStatus.values) ...[
            const SizedBox(width: AppSpacing.sm),
            _chip(context, _statusLabels[s]!, active == s, () => onSelected(s)),
          ],
        ],
      ),
    );
  }

  Widget _chip(
      BuildContext context, String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent
              : AppColors.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.footnote.copyWith(
            color: selected ? Colors.white : AppColors.accent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SuppliersList extends ConsumerWidget {
  const _SuppliersList({required this.suppliers});
  final List<Supplier> suppliers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // payable hint is best-effort — a failure here must not break the list
    final aging = ref.watch(payablesAgingProvider).value;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding, vertical: AppSpacing.md),
      itemCount: suppliers.length,
      itemBuilder: (_, i) {
        final s = suppliers[i];
        final payable = aging?.balanceFor(s.id) ?? 0;
        return Padding(
          padding: EdgeInsets.only(
              bottom: i < suppliers.length - 1 ? AppSpacing.md : 0),
          child: _SupplierCard(supplier: s, payable: payable),
        );
      },
    );
  }
}

class _SupplierCard extends StatelessWidget {
  const _SupplierCard({required this.supplier, required this.payable});
  final Supplier supplier;
  final double payable;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: InkWell(
        onTap: () => context.push('/suppliers/${supplier.id}'),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(Icons.local_shipping,
                      color: AppColors.accent, size: 20),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(supplier.name, style: AppTypography.headline),
                    if (supplier.phone != null) ...[
                      const SizedBox(height: 2),
                      Text(supplier.phone!,
                          style: AppTypography.footnote
                              .copyWith(color: AppColors.textMuted)),
                    ],
                    if (payable > 0) ...[
                      const SizedBox(height: 4),
                      Text('Payable ${formatPkr(payable)}',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.destructive)),
                    ],
                  ],
                ),
              ),
              _StatusBadge(status: supplier.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final SupplierStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      SupplierStatus.active => AppColors.success,
      SupplierStatus.inactive => AppColors.textMuted,
      SupplierStatus.blacklisted => AppColors.destructive,
    };
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        _statusLabels[status]!,
        style: AppTypography.caption
            .copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_shipping,
                size: 48, color: AppColors.textHint),
            const SizedBox(height: AppSpacing.md),
            Text('No suppliers yet',
                style: AppTypography.subhead
                    .copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.xs),
            Text('Add a supplier to start creating purchase orders.',
                textAlign: TextAlign.center,
                style: AppTypography.footnote
                    .copyWith(color: AppColors.textHint)),
            const SizedBox(height: AppSpacing.xl),
            PermissionGate(
              module: 'purchase',
              action: 'create',
              child: AppButton(
                label: 'New Supplier',
                onPressed: () => context.push('/suppliers/create'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppInlineBanner(
                message: 'Could not load suppliers.',
                type: BannerType.error),
            const SizedBox(height: AppSpacing.md),
            AppButton(label: 'Retry', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
