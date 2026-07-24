import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/approvals/presentation/controllers/approvals_controller.dart';
import '../../features/customers/presentation/controllers/customers_controller.dart';
import '../../features/dashboard/presentation/controllers/dashboard_controller.dart';
import '../../features/hr/presentation/controllers/employees_controller.dart';
import '../../features/purchasing/presentation/controllers/purchase_orders_controller.dart';
import '../../features/repair/presentation/controllers/repair_detail_provider.dart';
import '../../features/repair/presentation/controllers/repair_jobs_controller.dart';

/// Re-fetch a tab's landing data when the user (re)enters its branch, so tab
/// roots don't show stale data and you never need to pull-to-refresh them.
///
/// Tab roots live in the shell's `StatefulShellRoute.indexedStack`, which keeps
/// every branch mounted — so their providers never refetch on tab return on
/// their own. Invalidating here forces a fresh load the moment you switch to
/// the tab. (Pushed detail pages already refetch on open via autoDispose, and
/// invalidating a not-yet-created provider is a safe no-op.)
///
/// Branch indices mirror bottom_nav_shell's order. Excluded on purpose:
/// Inventory (1) and Sales (3) manage their own refresh (per request);
/// Settings (4), Reports (7), Accounting (8) are static hubs with no
/// landing-screen data to reload.
void reloadBranchOnEnter(WidgetRef ref, int branch) {
  switch (branch) {
    case 0: // Dashboard
      ref.invalidate(dashboardProvider);
    case 2: // Purchase — PO list provider is kept alive; refetch so a PO
            // approved elsewhere (Approvals tab) shows its new status on return.
      ref.invalidate(purchaseOrdersProvider);
    case 5: // Repair
      ref.invalidate(repairJobsProvider);
      ref.invalidate(techniciansProvider);
    case 6: // Customers
      ref.invalidate(customersProvider);
      ref.invalidate(receivablesAgingProvider);
    case 9: // Approvals
      ref.invalidate(pendingApprovalsControllerProvider);
    case 10: // HR
      ref.invalidate(employeesProvider);
  }
}
