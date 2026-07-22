import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_filter_chips.dart';
import '../../../../core/design/widgets/app_list_skeleton.dart';
import '../../../../core/design/widgets/app_search_field.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/widgets/module_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/supplier.dart';
import '../controllers/suppliers_controller.dart';
import '../widgets/supplier_card.dart';

/// Chip order — index 0 is "All", the rest follow [SupplierStatus.values].
const _statusLabels = ['All', 'Active', 'Inactive', 'Blacklisted'];

class SuppliersPage extends ConsumerStatefulWidget {
  const SuppliersPage({super.key});

  @override
  ConsumerState<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends ConsumerState<SuppliersPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  /// Kept for the no-results copy, which echoes what was typed.
  String _query = '';

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
    if (q != _query) setState(() => _query = q);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(suppliersProvider.notifier).search(q);
    });
  }

  void _submitSearch(String q) {
    _debounce?.cancel();
    ref.read(suppliersProvider.notifier).search(q);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(suppliersProvider);
    final activeStatus = ref.watch(suppliersProvider.notifier).statusFilter;
    final isWide = ModuleScaffold.isWideOf(context);

    final selectedChip = activeStatus == null
        ? 0
        : SupplierStatus.values.indexOf(activeStatus) + 1;

    // Search and filters are meaningless while the list cannot be shown, so
    // they hide in the loading and error states — as the design draws it.
    final showControls = !state.isLoading && !state.hasError;

    final newSupplierButton = PermissionGate(
      module: 'purchase',
      action: 'create',
      child: AppButton(
        label: 'New supplier',
        icon: LucideIcons.plus,
        size: AppButtonSize.sm,
        onPressed: () => context.push('/suppliers/create'),
      ),
    );

    return ModuleScaffold(
      title: 'Suppliers',
      maxContentWidth: 1080,
      actions: [if (isWide && showControls) newSupplierButton],
      floatingActionButton:
          !isWide && showControls ? _NewSupplierFab() : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showControls)
            Padding(
              padding: EdgeInsets.fromLTRB(isWide ? 32 : 16, 14, isWide ? 32 : 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppSearchField(
                    controller: _searchController,
                    hint: 'Search suppliers by name or contact…',
                    onSubmitted: _submitSearch,
                    onClear: () => _submitSearch(''),
                  ),
                  const SizedBox(height: 14),
                  AppFilterChips(
                    labels: _statusLabels,
                    selected: selectedChip,
                    onSelected: (i) => ref
                        .read(suppliersProvider.notifier)
                        .setStatus(i == 0 ? null : SupplierStatus.values[i - 1]),
                  ),
                ],
              ),
            ),
          Expanded(
            child: state.when(
              loading: () => Padding(
                padding: EdgeInsets.fromLTRB(
                    isWide ? 32 : 16, 14, isWide ? 32 : 16, 20),
                child: const AppListSkeleton(rows: 5, rowHeight: 80),
              ),
              error: (e, _) => AppErrorState(
                icon: LucideIcons.cloudOff,
                title: "We couldn't load suppliers",
                body: 'Something went wrong reaching the server. Your data is '
                    'safe — try again in a moment.',
                retryLabel: 'Retry',
                onRetry: () => ref.read(suppliersProvider.notifier).refresh(),
              ),
              data: (suppliers) {
                if (suppliers.isEmpty) {
                  return _query.isEmpty && activeStatus == null
                      ? AppEmptyState(
                          icon: LucideIcons.truck,
                          title: 'No suppliers yet',
                          body: 'Add your first supplier and their purchases, '
                              'payments and balances will show up here.',
                          action: PermissionGate(
                            module: 'purchase',
                            action: 'create',
                            child: AppButton(
                              label: 'New supplier',
                              icon: LucideIcons.plus,
                              onPressed: () => context.push('/suppliers/create'),
                            ),
                          ),
                        )
                      : AppEmptyState(
                          icon: LucideIcons.searchX,
                          title: 'No matches',
                          body: _query.isEmpty
                              ? 'No suppliers have this status. Try a '
                                  'different filter.'
                              : 'No suppliers match “$_query”. Try a '
                                  'different name or clear the filters.',
                        );
                }
                return _SuppliersList(suppliers: suppliers, isWide: isWide);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SuppliersList extends ConsumerWidget {
  const _SuppliersList({required this.suppliers, required this.isWide});

  final List<Supplier> suppliers;
  final bool isWide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Payable hint is best-effort — a failure here must not break the list, and
    // an unresolved aging call shows nothing rather than a false "Settled".
    final aging = ref.watch(payablesAgingProvider).value;

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
          isWide ? 32 : 16, 14, isWide ? 32 : 16, isWide ? 32 : 20),
      itemCount: suppliers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final s = suppliers[i];
        return SupplierCard(
          supplier: s,
          payable: aging?.balanceFor(s.id),
          isWide: isWide,
          onTap: () => context.push('/suppliers/${s.id}'),
        );
      },
    );
  }
}

/// The design's floating pill CTA for narrow layouts.
class _NewSupplierFab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return PermissionGate(
      module: 'purchase',
      action: 'create',
      child: Semantics(
        button: true,
        label: 'New supplier',
        child: InkWell(
          onTap: () => context.push('/suppliers/create'),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: ClayContainer(
            variant: ClayVariant.soft,
            color: lum.accent,
            borderRadius: AppRadius.pill,
            isDark: lum.isDark,
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.plus, size: 19, color: Colors.white),
                const SizedBox(width: 9),
                const Text(
                  'New supplier',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
