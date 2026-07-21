import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/controllers/permission_controller.dart';
import '../../../customers/domain/usecases/load_customers.dart';
import '../../../inventory/domain/usecases/search_products.dart';
import '../../../sales/domain/usecases/load_invoices.dart';

/// Which module a hit came from — drives its section heading and icon.
enum SearchKind { product, customer, invoice }

/// One row in the global-search results.
class SearchHit {
  const SearchHit({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final SearchKind kind;
  final String title;
  final String subtitle;

  /// Where tapping the hit navigates.
  final String route;
}

/// Results for one module, kept separate so each renders under its own heading.
class SearchSection {
  const SearchSection(this.kind, this.hits);
  final SearchKind kind;
  final List<SearchHit> hits;
}

/// Shortest query worth hitting the network for.
const _kMinQueryLength = 2;

/// Per-module cap — the palette is for jumping to a record, not browsing.
const _kPerSectionLimit = 5;

/// Global search across products, customers and invoices.
///
/// Aggregates the modules' existing use cases rather than adding a datasource:
/// nothing new is queried, it is the same reads those features already do.
/// Sections the user lacks permission for are never queried at all — read RLS
/// on these tables is tenant-scoped only, so the gate has to be here.
final globalSearchProvider =
    FutureProvider.autoDispose.family<List<SearchSection>, String>(
  (ref, rawQuery) async {
    final query = rawQuery.trim();
    if (query.length < _kMinQueryLength) return const [];

    final canProducts = ref.watch(canProvider(('inventory', 'read')));
    final canCustomers = ref.watch(canProvider(('customers', 'read')));
    final canInvoices = ref.watch(canProvider(('sales', 'read')));

    final sections = <SearchSection>[];

    if (canProducts) {
      final (products, failure) =
          await ref.read(searchProductsUseCaseProvider).call(query);
      if (failure == null && products.isNotEmpty) {
        sections.add(SearchSection(SearchKind.product, [
          for (final p in products.take(_kPerSectionLimit))
            SearchHit(
              kind: SearchKind.product,
              title: p.name,
              subtitle: p.sku,
              route: '/inventory/stock/${p.id}',
            ),
        ]));
      }
    }

    if (canCustomers) {
      final (customers, failure) =
          await ref.read(loadCustomersUseCaseProvider).call(query: query);
      if (failure == null && customers.isNotEmpty) {
        sections.add(SearchSection(SearchKind.customer, [
          for (final c in customers.take(_kPerSectionLimit))
            SearchHit(
              kind: SearchKind.customer,
              title: c.name,
              subtitle: c.phone ?? '',
              route: '/customers/${c.id}',
            ),
        ]));
      }
    }

    if (canInvoices) {
      final (invoices, failure) = await ref
          .read(loadInvoicesUseCaseProvider)
          .call(search: query, limit: _kPerSectionLimit);
      if (failure == null && invoices.isNotEmpty) {
        sections.add(SearchSection(SearchKind.invoice, [
          for (final i in invoices.take(_kPerSectionLimit))
            SearchHit(
              kind: SearchKind.invoice,
              title: i.invoiceNumber,
              subtitle: i.status.name,
              route: '/sales/invoice/${i.invoiceNumber}',
            ),
        ]));
      }
    }

    return sections;
  },
);
