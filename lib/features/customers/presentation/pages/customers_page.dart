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
import '../../domain/entities/customer.dart';
import '../controllers/customers_controller.dart';
import '../widgets/customer_card.dart';

/// Chip order — index 0 is "All", the rest follow [CustomerStatus.values].
const _statusLabels = ['All', 'Active', 'Inactive', 'Blacklisted'];

class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
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
      ref.read(customersProvider.notifier).search(q);
    });
  }

  void _submitSearch(String q) {
    _debounce?.cancel();
    ref.read(customersProvider.notifier).search(q);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customersProvider);
    final activeStatus = ref.watch(customersProvider.notifier).statusFilter;
    final isWide = ModuleScaffold.isWideOf(context);

    final selectedChip = activeStatus == null
        ? 0
        : CustomerStatus.values.indexOf(activeStatus) + 1;

    // Search and filters are meaningless while the list cannot be shown, so
    // they hide in the loading and error states — as the design draws it.
    final showControls = !state.isLoading && !state.hasError;

    final newCustomerButton = PermissionGate(
      module: 'customers',
      action: 'create',
      child: AppButton(
        label: 'New customer',
        icon: LucideIcons.plus,
        size: AppButtonSize.sm,
        onPressed: () => context.push('/customers/create'),
      ),
    );

    return ModuleScaffold(
      title: 'Customers',
      maxContentWidth: 1080,
      actions: [
        _ReceivablesAction(),
        if (isWide && showControls) newCustomerButton,
      ],
      floatingActionButton:
          !isWide && showControls ? _NewCustomerFab() : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showControls)
            Padding(
              padding: EdgeInsets.fromLTRB(
                  isWide ? 32 : 16, 14, isWide ? 32 : 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppSearchField(
                    controller: _searchController,
                    hint: 'Search name, phone or email…',
                    onSubmitted: _submitSearch,
                    onClear: () => _submitSearch(''),
                  ),
                  const SizedBox(height: 14),
                  AppFilterChips(
                    labels: _statusLabels,
                    selected: selectedChip,
                    onSelected: (i) => ref
                        .read(customersProvider.notifier)
                        .setStatus(
                            i == 0 ? null : CustomerStatus.values[i - 1]),
                  ),
                ],
              ),
            ),
          Expanded(
            child: state.when(
              loading: () => Padding(
                padding: EdgeInsets.fromLTRB(
                    isWide ? 32 : 16, 14, isWide ? 32 : 16, 20),
                child: const AppListSkeleton(rows: 5, rowHeight: 84),
              ),
              error: (e, _) => AppErrorState(
                icon: LucideIcons.cloudOff,
                title: "Unable to load customers",
                body: 'Unable to reach the server. Try again in a moment.',
                retryLabel: 'Retry',
                onRetry: () => ref.read(customersProvider.notifier).refresh(),
              ),
              data: (customers) {
                if (customers.isEmpty) {
                  return _query.isEmpty && activeStatus == null
                      ? AppEmptyState(
                          icon: LucideIcons.users,
                          title: 'No customers yet',
                          body: 'Add your first customer and their sales, '
                              'credit and ledger will show up here.',
                          action: PermissionGate(
                            module: 'customers',
                            action: 'create',
                            child: AppButton(
                              label: 'New customer',
                              icon: LucideIcons.plus,
                              onPressed: () =>
                                  context.push('/customers/create'),
                            ),
                          ),
                        )
                      : AppEmptyState(
                          icon: LucideIcons.searchX,
                          title: 'No matches',
                          body: _query.isEmpty
                              ? 'No customers have this status. Try a '
                                  'different filter.'
                              : 'No customers match “$_query”. Try a '
                                  'different name or clear the filters.',
                        );
                }
                return _CustomersList(customers: customers, isWide: isWide);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Header action linking to the receivables aging screen.
class _ReceivablesAction extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Semantics(
      button: true,
      label: 'Receivables',
      child: IconButton(
        tooltip: 'Receivables',
        onPressed: () => context.go('/receivables'),
        icon: Icon(LucideIcons.receiptText, size: 20, color: lum.g600),
      ),
    );
  }
}

class _CustomersList extends ConsumerWidget {
  const _CustomersList({required this.customers, required this.isWide});

  final List<Customer> customers;
  final bool isWide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Receivable hint is best-effort — a failure here must not break the list,
    // and an unresolved aging call shows no due pill rather than a false clear.
    final aging = ref.watch(receivablesAgingProvider).value;
    final pad = isWide ? 32.0 : 16.0;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(pad, 14, pad, isWide ? 32 : 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 12.0;
          // Two-up once the row is wide enough for a 340px card, else one-up —
          // derived from the measured width, never a hand-picked ratio.
          final twoUp = constraints.maxWidth >= 720;
          final itemWidth =
              twoUp ? (constraints.maxWidth - gap) / 2 : constraints.maxWidth;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final c in customers)
                SizedBox(
                  width: itemWidth,
                  child: CustomerCard(
                    customer: c,
                    receivable: aging?.balanceFor(c.id),
                    isWide: isWide,
                    onTap: () => context.push('/customers/${c.id}'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The design's floating pill CTA for narrow layouts.
class _NewCustomerFab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return PermissionGate(
      module: 'customers',
      action: 'create',
      child: Semantics(
        button: true,
        label: 'New customer',
        child: InkWell(
          onTap: () => context.push('/customers/create'),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: ClayContainer(
            variant: ClayVariant.soft,
            color: lum.accent,
            borderRadius: AppRadius.pill,
            isDark: lum.isDark,
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.plus, size: 19, color: Colors.white),
                SizedBox(width: 9),
                Text(
                  'New customer',
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
