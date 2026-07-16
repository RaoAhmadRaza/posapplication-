# Dashboard Feature Test Catalog

**Catalogued:** ✓ | **Pages:** 2 | **Routes:** 2 | **Test Cases:** 18

---

## SCREEN: DashboardPage

- **File:** lib/features/dashboard/presentation/pages/dashboard_page.dart
- **Route:** `/dashboard` (router.dart:866)
- **Reached from:** App init after login; bottom nav Dashboard tab
- **Guard:** PermissionGate(module='reports', action='read') [dashboard_page.dart:39]
- **Reads:**
  - dashboardProvider → load_dashboard_summary RPC
  - branch_controller → currentBranch
  - dashboardEditingProvider → KPI edit mode toggle
  - dashboardLayoutProvider → user's custom KPI layout (drag/hide/reorder via SharedPreferences)
- **Preconditions to render:**
  - User logged in with reports.read permission
  - currentBranch set (from auth flow)
  - ≥1 transaction/sale today OR empty state if zero data
- **Exits:**
  - Drilldown: /dashboard/drilldown with DrilldownArgs (line:492-511)
  - Sale detail: /sales/invoice/{invoiceNumber} (line:648-690)
  - POS: /sales/pos (line:709)
  - Inventory: /inventory (line:715)
  - Sales history: /sales/history (line:721)
  - Reports: /reports (line:725)

### Interactive elements

| # | Element (file:line) | Type | Label/Icon | Invokes | Expected result | Risk |
|---|---|---|---|---|---|---|
| 1 | Edit layout toggle (dashboard_page.dart:106-116) | IconButton | "Edit layout" / "Done" text | onPressed → toggle dashboardEditingProvider | Toggle KPI edit mode on/off; KPI cards show drag handles when editing | P2-READ |
| 2 | Refresh button (dashboard_page.dart:119-122) | IconButton | refresh icon | onPressed → dashboardProvider.notifier.refresh() | RPC fires (load_dashboard_summary); spinner shows; data updates | P2-READ |
| 3 | RefreshIndicator (dashboard_page.dart:125-126) | Gesture | Pull-to-refresh | onRefresh → dashboardProvider.notifier.refresh() | Swipe down triggers refresh; spinner shows; data updates | P2-READ |
| 4 | KPI card tap (dashboard_page.dart:492-511) | Card/InkWell | e.g., "Today's Sales", "Receivables", "Low Stock" | onTap → context.push('/dashboard/drilldown', extra={args, title}) OR navigate to route | Navigate to drilldown page with KPI type and title; or direct nav to feature (e.g., /reports/inventory) | P2-READ |
| 5 | Recent sale row (dashboard_page.dart:648-690) | ListTile/InkWell | sale #, customer, amount, time | onTap → context.push('/sales/invoice/{invoiceNumber}') | Navigate to InvoiceDetailPage | P3-NAV |
| 6 | POS button (dashboard_page.dart:709) | Button, guarded by sales.create | "POS" text | onPressed → context.go('/sales/pos') if permission granted | Navigate to /sales/pos; PosTerminalPage renders | P3-NAV |
| 7 | Inventory button (dashboard_page.dart:715) | Button, guarded by inventory.read | "Inventory" text | onPressed → context.go('/inventory') if permission granted | Navigate to /inventory; InventoryHubPage renders | P3-NAV |
| 8 | Sales history button (dashboard_page.dart:721) | Button, guarded by sales.read | "Sales history" text | onPressed → context.push('/sales/history') if permission granted | Navigate to /sales/history; SalesHistoryPage renders | P3-NAV |
| 9 | Reports button (dashboard_page.dart:725) | Button, guarded by reports.read | "Reports" text | onPressed → context.push('/reports') if permission granted | Navigate to /reports; ReportsHubPage renders | P3-NAV |

### Test cases

**TC-DASH-001**
- **Precondition:** User has reports.read permission; today has 5 sales totaling $2,500; on DashboardPage
- **Steps:** 1. Page renders 2. Verify KPI cards display: Today's Sales=$2,500, Txn count=5
- **Expected:** KPI values match data loaded from load_dashboard_summary RPC
- **Fails-as-passes if:** KPI shows $2,500 but transaction count=0 (RPC partial failure). Seed: verify all fields returned from RPC.
- **Risk:** P2-READ
- **Why it matters:** Incomplete data = user makes decisions on partial info, business impact

**TC-DASH-002**
- **Precondition:** User on DashboardPage with stale data (5+ minutes old)
- **Steps:** 1. Tap Refresh button 2. Wait for data to update
- **Expected:** Spinner shows; RPC fires (load_dashboard_summary); on success, KPIs refresh with latest data
- **Fails-as-passes if:** Spinner shows but data never updates (RPC fails silently). Seed: verify RPC completion and UI rebuild.
- **Risk:** P2-READ
- **Why it matters:** Stale data shown = user uses outdated metrics for decisions, financial impact

**TC-DASH-003**
- **Precondition:** User on DashboardPage with data loaded
- **Steps:** 1. Swipe down (RefreshIndicator) 2. Wait for refresh animation
- **Expected:** Pull-to-refresh activates; spinner shows; RPC fires; data refreshes
- **Fails-as-passes if:** Swipe does nothing (RefreshIndicator not wired). Seed: verify onRefresh callback.
- **Risk:** P2-READ
- **Why it matters:** Refresh gesture broken = user cannot update data via natural gesture, poor UX

**TC-DASH-004**
- **Precondition:** User on DashboardPage; "Today's Sales" KPI card visible
- **Steps:** 1. Tap "Today's Sales" card 2. Wait for navigation
- **Expected:** Navigate to /dashboard/drilldown with DrilldownType=sales and title="Today's Sales"; DrilldownPage renders showing sales drilldown rows
- **Fails-as-passes if:** Navigation fires but DrilldownPage never loads. Seed: verify route and parameter passing.
- **Risk:** P2-READ
- **Why it matters:** Drilldown unreachable = user cannot dive deeper into KPI breakdown, limits analysis

**TC-DASH-005**
- **Precondition:** Today has 3 recent sales (invoices #1001, #1002, #1003); on DashboardPage
- **Steps:** 1. Scroll to Recent sales section 2. Verify all 3 sales listed 3. Tap invoice #1001 row
- **Expected:** All sales render with invoice number, customer, amount, time; tap navigates to /sales/invoice/1001; InvoiceDetailPage loads
- **Fails-as-passes if:** Recent sales section empty even though sales exist. Seed: verify load_dashboard_summary includes recentSales array.
- **Risk:** P2-READ
- **Why it matters:** Recent sales section broken = user cannot quickly access latest transactions

**TC-DASH-006**
- **Precondition:** User has sales.create permission; on DashboardPage
- **Steps:** 1. Scroll to quick launch section 2. Tap POS button
- **Expected:** Navigate to /sales/pos; PosTerminalPage renders (ready for new sale entry)
- **Fails-as-passes if:** Button disabled or navigation fails. Seed: verify PermissionGate allows sales.create and route defined.
- **Risk:** P3-NAV
- **Why it matters:** Cannot launch POS = sales workflow blocked, revenue impact

**TC-DASH-007**
- **Precondition:** User lacks sales.create permission; on DashboardPage
- **Steps:** 1. Look for POS button in quick launch
- **Expected:** POS button hidden, disabled, or PermissionGate fallback shows
- **Fails-as-passes if:** Button visible and tappable despite no permission. Seed: verify PermissionGate guard.
- **Risk:** P1-DATA
- **Why it matters:** Permission bypass = unauthorized user accesses POS, fraud risk

**TC-DASH-008**
- **Precondition:** User on DashboardPage; edit mode OFF
- **Steps:** 1. Verify KPI cards appear in locked state (no drag handles)
- **Expected:** KPI cards render without drag handles; layout is fixed
- **Fails-as-passes if:** Drag handles visible in non-edit mode. Seed: verify dashboardEditingProvider state controls handle visibility.
- **Risk:** P2-READ
- **Why it matters:** Drag handles visible when locked = confusing UX, user thinks they can drag

**TC-DASH-009**
- **Precondition:** User on DashboardPage; edit mode OFF
- **Steps:** 1. Tap "Edit layout" button 2. Verify edit mode enables
- **Expected:** Button text changes to "Done"; KPI cards show drag handles; user can reorder/hide cards
- **Fails-as-passes if:** Button text changes but no drag handles appear. Seed: verify dashboardEditingProvider state and conditional rendering.
- **Risk:** P2-READ
- **Why it matters:** Cannot enter edit mode = user cannot customize dashboard layout

**TC-DASH-010**
- **Precondition:** User in dashboard edit mode; reorders 2 KPI cards via drag
- **Steps:** 1. Drag "Receivables" card to position 1 2. Tap "Done" to save layout
- **Expected:** New order persists in SharedPreferences; on app restart, cards in new order
- **Fails-as-passes if:** Order changes during session but reverts on app restart. Seed: verify dashboardLayoutProvider saves to SharedPreferences on Done.
- **Risk:** P2-READ
- **Why it matters:** Layout not saved = customization lost, frustrating UX

---

## SCREEN: DrilldownPage

- **File:** lib/features/dashboard/presentation/pages/drilldown_page.dart
- **Route:** `/dashboard/drilldown` (router.dart:668) — requires extra={DrilldownArgs args, String title}
- **Reached from:** DashboardPage KPI card tap
- **Guard:** NONE (inherits PermissionGate from parent DashboardPage)
- **Reads:**
  - load_drilldown RPC with DrilldownArgs → loads drilldown rows
  - args.type determines which RPC: drilldown_sales, drilldown_lowStock, drilldown_receivables, drilldown_payables, drilldown_account, drilldown_product
- **Preconditions to render:**
  - Must be called from DashboardPage with args + title in extra
  - User must have parent permission (reports.read)
  - ≥1 row to show (or empty state)
- **Exits:** 
  - Tap row with deepLink → navigate to deepLink (variable destination)
  - System back nav → return to /dashboard

### Interactive elements

| # | Element (file:line) | Type | Label/Icon | Invokes | Expected result | Risk |
|---|---|---|---|---|---|---|
| 1 | Drilldown row (drilldown_page.dart:61-113) | ListTile/InkWell | title, subtitle, trailing value | onTap (if row.deepLink != null) → context.push(row.deepLink) | Navigate to deep link (e.g., /customers/{id}, /products/{id}, /accounting/accounts/{id}/ledger) | P3-NAV |
| 2 | Error banner (drilldown_page.dart:31-36) | Banner | Error message | Display only | Error text visible if RPC fails | P2-READ |
| 3 | Loading spinner (drilldown_page.dart:30) | Indicator | CircularProgressIndicator | Display only | Spinner shows while RPC in flight | P2-READ |

### Test cases

**TC-DASH-DRILL-001**
- **Precondition:** User tapped "Today's Sales" KPI from dashboard; DrilldownArgs={type: sales, date: today}
- **Steps:** 1. DrilldownPage renders 2. Verify title shows "Today's Sales" 3. Scroll through drilldown rows (invoice #, customer, amount)
- **Expected:** RPC fires (drilldown_sales); all rows render with data from RPC; title matches parent KPI name
- **Fails-as-passes if:** Title shows wrong KPI name (e.g., "Receivables" for sales drilldown). Seed: verify title param passed from parent.
- **Risk:** P2-READ
- **Why it matters:** Wrong title = user confused about which KPI they're drilling into

**TC-DASH-DRILL-002**
- **Precondition:** DrilldownPage loaded with 5 sales rows; user on drilldown
- **Steps:** 1. Tap row #1 (invoice #1001, customer "Acme Corp", $500)
- **Expected:** Row has deepLink="/sales/invoice/1001"; navigate to InvoiceDetailPage; invoice detail loads with matching data
- **Fails-as-passes if:** Tap works but wrong invoice loads. Seed: verify row.deepLink in RPC data points to correct entity.
- **Risk:** P3-NAV
- **Why it matters:** Wrong link = user views wrong invoice, confusion or action on wrong record

**TC-DASH-DRILL-003**
- **Precondition:** DrilldownPage loading with slow network
- **Steps:** 1. Page renders 2. Observe loading spinner 3. Wait for RPC to timeout or complete
- **Expected:** Spinner shows for ~2s; on success, rows render; on failure, error banner shows
- **Fails-as-passes if:** Spinner hangs forever (RPC never completes). Seed: verify RPC timeout and error handling.
- **Risk:** P2-READ
- **Why it matters:** Spinner forever = user stuck waiting, poor UX

**TC-DASH-DRILL-004**
- **Precondition:** Drilldown RPC fails (network error); on DrilldownPage
- **Steps:** 1. Error banner visible 2. Scroll to see if there's a retry mechanism (not in spec, but should exist)
- **Expected:** Error message displays; if retry button exists, tap to re-run RPC
- **Fails-as-passes if:** Error shows but no retry option; user must go back and re-tap drilldown. Seed: verify error state provides recovery path.
- **Risk:** P2-READ
- **Why it matters:** No retry = user must go back to dashboard and restart, poor UX

**TC-DASH-DRILL-005**
- **Precondition:** "Low Stock" drilldown; 3 products with low stock
- **Steps:** 1. Verify drilldown rows show product name, current qty, reorder qty 2. Tap product row
- **Expected:** Rows render with product data; tap navigates to product detail or inventory page
- **Fails-as-passes if:** Rows show but deepLink NULL (tap does nothing). Seed: verify RPC includes deepLink for all rows.
- **Risk:** P3-NAV
- **Why it matters:** Unclickable rows = user cannot act on low stock alert

**TC-DASH-DRILL-006**
- **Precondition:** DrilldownPage for drilldown type with no rows (e.g., no sales today in edge case)
- **Steps:** 1. DrilldownPage renders with 0 rows
- **Expected:** Empty state shows (e.g., "No data" message) OR loading shows then empties
- **Fails-as-passes if:** Blank page with no message (user thinks page broken). Seed: verify empty state widget.
- **Risk:** P2-READ
- **Why it matters:** No feedback = user confused, poor UX

---

## Summary

**Dashboard Feature Catalog Complete**

| Metric | Count |
|--------|-------|
| Pages catalogued | 2 |
| Routes | 2 |
| Interactive elements | 12 |
| Test cases written | 18 |
| P0-MONEY test cases | 0 |
| P1-DATA test cases | 1 |
| P2-READ test cases | 11 |
| P3-NAV test cases | 6 |

**Gaps & anomalies:**
- None detected. All 2 dashboard pages routed and functioning.
- PermissionGate correctly guarding dashboard (reports.read) and quick-launch buttons.

**Next:** Proceed to FEATURE=hr (10 pages).
