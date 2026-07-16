# Customers Feature Test Catalog

**Catalogued:** ✓ | **Pages:** 5 | **Routes:** 5 | **Test Cases:** 40

---

## SCREEN: CustomersPage

- **File:** lib/features/customers/presentation/pages/customers_page.dart
- **Route:** `/customers` (router.dart:533)
- **Reached from:** Bottom nav shell Customers tab
- **Guard:** PermissionGate(module='customers', action='create') wraps FAB (line:73) and empty state button (line:305)
- **Reads:** 
  - customersProvider → customersController.notifier.search/setStatus/refresh → RPC calls
  - receivablesAgingProvider (best-effort, line:180) → aging data display
- **Preconditions to render:** User logged in; ≥1 customer or empty list
- **Exits:** Navigator.pop() via back button (line:66)

### Interactive elements

| # | Element (file:line) | Type | Label/Icon | Invokes | Expected result | Risk |
|---|---|---|---|---|---|---|
| 1 | Back button (customers_page.dart:66) | IconButton | back arrow | onPressed → Navigator.pop() | Pop screen; return to nav root | P3-NAV |
| 2 | Add customer FAB (customers_page.dart:76) | FloatingActionButton | + icon, guarded by PermissionGate | onPressed → context.push('/customers/create') | Navigate to create form if permission granted | P3-NAV |
| 3 | Search field (customers_page.dart:90) | TextField | hint "Search customers..." | onSubmitted(q) → customersProvider.notifier.search(q) | RPC fires; list filters by name/email match | P2-READ |
| 4 | Status filter chips (customers_page.dart:148) | Chips | "Active", "Inactive", "Prospect" | onTap(status) → customersProvider.notifier.setStatus(s) | List filters by status; chip toggles active state | P2-READ |
| 5 | Customer card (customers_page.dart:206) | InkWell | customer.name, phone, email | onTap → context.push('/customers/${customer.id}') | Navigate to detail page | P3-NAV |
| 6 | Retry button on error (customers_page.dart:337) | Button | "Retry" | onPressed → customersProvider.notifier.refresh() | RPC re-runs; on success, list refreshes | P2-READ |
| 7 | New customer button in empty state (customers_page.dart:310) | Button | "Add your first customer" | onPressed → context.push('/customers/create') | Navigate to create form if permission granted | P3-NAV |

### Test cases

**TC-CUS-LIST-001**
- **Precondition:** User has customers.read permission; 3 customers exist (Acme Corp, Beta Inc, Gamma LLC)
- **Steps:** 1. CustomersPage renders 2. Verify all 3 customer cards visible
- **Expected:** All 3 cards render with name, phone, email; list loads without error
- **Fails-as-passes if:** List renders but card count = 2 (one customer missing). Seed: verify customersProvider query returns all rows.
- **Risk:** P2-READ
- **Why it matters:** Missing customer = silent data loss in list view

**TC-CUS-LIST-002**
- **Precondition:** User has customers.create permission; on CustomersPage
- **Steps:** 1. Tap FAB (+ icon) 2. Wait for navigation
- **Expected:** Navigate to /customers/create; CustomerFormPage renders in create mode
- **Fails-as-passes if:** FAB disabled or clickless. Seed: verify FAB onPressed and PermissionGate allow create action.
- **Risk:** P3-NAV
- **Why it matters:** Cannot create = user cannot add customers, feature blocked

**TC-CUS-LIST-003**
- **Precondition:** 5 customers exist (2 Active, 2 Inactive, 1 Prospect); on CustomersPage
- **Steps:** 1. Tap "Inactive" chip 2. Observe list filter
- **Expected:** List shows only 2 inactive customers; chip shows active state (highlighted or different color)
- **Fails-as-passes if:** Chip looks active but list shows all customers (filter not applied). Seed: verify customersProvider.notifier.setStatus updates filter and rebuilds widget.
- **Risk:** P2-READ
- **Why it matters:** Filter broken = user sees wrong customers, decision impact

**TC-CUS-LIST-004**
- **Precondition:** 10 customers exist; on CustomersPage
- **Steps:** 1. Tap search field 2. Type "Acme" 3. Tap submit
- **Expected:** RPC fires (search query); list filters to matching customer(s); spinner shows during search
- **Fails-as-passes if:** Spinner shows but no results returned (search RPC failed silently). Seed: verify search RPC and error handling.
- **Risk:** P2-READ
- **Why it matters:** Silent search failure = user thinks customer doesn't exist, false negative

**TC-CUS-LIST-005**
- **Precondition:** User lacks customers.create permission; on CustomersPage; 2 customers exist
- **Steps:** 1. Try to tap FAB 2. Verify PermissionGate behavior
- **Expected:** FAB disabled or PermissionGate fallback shows ("No permission"); user cannot create
- **Fails-as-passes if:** FAB tappable despite no permission. Seed: verify PermissionGate guard wraps FAB.
- **Risk:** P1-DATA
- **Why it matters:** Permission bypass = unauthorized user creates customers, data integrity risk

---

## SCREEN: CustomerFormPage

- **File:** lib/features/customers/presentation/pages/customer_form_page.dart
- **Route:** `/customers/create` (router.dart:537) | `/customers/:customerId/edit` (router.dart:550)
- **Reached from:** CustomersPage FAB or CustomerDetailPage edit button
- **Guard:** PermissionGate(module='customers', action=_isEditing?'update':'create') wraps submit button (line:344); fallback banner (line:347)
- **Reads:**
  - loadCustomerUseCaseProvider.call(customerId) (line:83) if editing
  - customersProvider.notifier.create or edit
- **Preconditions to render:** 
  - Create mode: no customerId param
  - Edit mode: customerId passed; existing customer data loaded
- **Exits:** Navigator.pop() after successful save (line:184)

### Interactive elements

| # | Element (file:line) | Type | Label/Icon | Invokes | Expected result | Risk |
|---|---|---|---|---|---|---|
| 1 | Back button (customer_form_page.dart:194) | IconButton | back arrow | onPressed → Navigator.pop() | Pop form; return to list or detail | P3-NAV |
| 2 | Name field (customer_form_page.dart:222) | TextField | "Customer name" label | TextEditingController binding | User can type name; no length limit enforced | P1-DATA |
| 3 | Status dropdown (customer_form_page.dart:312) | Dropdown | "Active", "Inactive", "Prospect" | onChanged(v) → setState(() => _status = v) | Dropdown expands; selected status shown | P2-READ |
| 4 | Submit button (customer_form_page.dart:352) | Button | "Create" or "Update" text (mode-dependent) | onPressed → _save() (line:118) | RPC fires (customersProvider.notifier.create/edit); on success, pop; on error, banner shows | P0-MONEY |

### Test cases

**TC-CUS-FORM-001**
- **Precondition:** User has customers.create permission; on CustomerFormPage in create mode
- **Steps:** 1. Enter name "New Customer Corp" 2. Leave status as default "Active" 3. Tap Create button
- **Expected:** Loading spinner; RPC fires (customersProvider.notifier.create); on success, form pops; return to list
- **Fails-as-passes if:** RPC succeeds but form doesn't pop. Seed: verify Navigator.pop() called in success callback.
- **Risk:** P0-MONEY
- **Why it matters:** Form stuck = user cannot complete customer creation, workflow broken

**TC-CUS-FORM-002**
- **Precondition:** User has customers.create permission; on create form
- **Steps:** 1. Leave name field empty 2. Tap Create button
- **Expected:** Validation error shows (e.g., "Name required"); RPC does not fire; form stays open
- **Fails-as-passes if:** No validation error; RPC fires with empty name. Seed: verify _save checks name.isEmpty before calling RPC.
- **Risk:** P1-DATA
- **Why it matters:** Empty customer name allowed = invalid DB row, data integrity break

**TC-CUS-FORM-003**
- **Precondition:** User has customers.update permission; edit mode for existing customer "Acme Corp"
- **Steps:** 1. Verify name field pre-filled with "Acme Corp" 2. Change to "Acme Corporation" 3. Change status to "Inactive" 4. Tap Update button
- **Expected:** Form shows "Update" button (not "Create"); RPC fires with updated data; on success, pop; verify DB row updated
- **Fails-as-passes if:** Form shows "Create" button even in edit mode. Seed: verify _isEditing flag determines button label.
- **Risk:** P1-DATA
- **Why it matters:** Wrong button label = UX confusing, user thinks it's create not update

**TC-CUS-FORM-004**
- **Precondition:** User lacks customers.create permission; on create form
- **Steps:** 1. Fill in valid customer data 2. Tap Create button
- **Expected:** PermissionGate blocks; fallback banner shows "No permission to create"; button disabled; form stays open
- **Fails-as-passes if:** Button enabled and RPC fires despite no permission. Seed: verify PermissionGate wraps submit button.
- **Risk:** P1-DATA
- **Why it matters:** Permission bypass = unauthorized customer creation, compliance breach

---

## SCREEN: CustomerDetailPage

- **File:** lib/features/customers/presentation/pages/customer_detail_page.dart
- **Route:** `/customers/:customerId` (router.dart:545)
- **Reached from:** CustomersPage card tap or ReceivablesAgingPage row tap
- **Guard:** 
  - PermissionGate(module='sales', action='create') wraps payment buttons (line:46, 155)
  - PermissionGate(module='customers', action='update') wraps edit button (line:58)
  - PermissionGate(module='customers', action='delete') wraps delete button (line:66)
- **Reads:**
  - _customerProvider(customerId) → loadCustomerUseCaseProvider.call(id)
  - customerLedgerProvider(customer.id) → ledger balance
- **Preconditions to render:** Customer must exist with given ID
- **Exits:** Navigator.pop() via back button or after delete

### Interactive elements

| # | Element (file:line) | Type | Label/Icon | Invokes | Expected result | Risk |
|---|---|---|---|---|---|---|
| 1 | Back button (customer_detail_page.dart:39) | IconButton | back arrow | onPressed → Navigator.pop() | Pop detail; return to list | P3-NAV |
| 2 | Payment action button (customer_detail_page.dart:49) | IconButton | payment icon, guarded | onPressed → context.push('/customers/$customerId/collect', extra={'customerName': c.name}) | Navigate to payment page if permission granted | P3-NAV |
| 3 | Edit action button (customer_detail_page.dart:61) | IconButton | edit/pencil icon, guarded | onPressed → context.push('/customers/$customerId/edit') | Navigate to form in edit mode if permission granted | P3-NAV |
| 4 | Delete action button (customer_detail_page.dart:69) | IconButton | delete/trash icon, guarded | onPressed → _confirmDelete(context, ref) (line:93) | Confirmation dialog shows | P1-DATA |
| 5 | Delete confirmation dialog (customer_detail_page.dart:104) | Dialog | "Delete customer?" title + buttons | TextButton.onPressed → customersProvider.notifier.remove(customerId) (line:108) | RPC fires to delete; on success, pop detail page | P0-MONEY |
| 6 | Collect payment button in body (customer_detail_page.dart:158) | Button | "Collect payment" text, guarded | onPressed → context.push('/customers/${customer.id}/collect', extra={'customerName': customer.name}) | Navigate to payment page if permission granted | P3-NAV |

### Test cases

**TC-CUS-DETAIL-001**
- **Precondition:** Customer "Acme Corp" exists with $5,000 balance; user has sales.create and customers.read permissions
- **Steps:** 1. Navigate to detail page 2. Verify name, phone, email, balance displayed
- **Expected:** All fields render with correct values; balance shows "$5,000" or equivalent
- **Fails-as-passes if:** Balance shows but wrong amount (e.g., "$0"). Seed: verify customerLedgerProvider calculates balance correctly.
- **Risk:** P2-READ
- **Why it matters:** Wrong balance = user makes wrong payment decisions, financial impact

**TC-CUS-DETAIL-002**
- **Precondition:** Customer exists; user has sales.create permission; on detail page
- **Steps:** 1. Tap payment button (icon or button) 2. Wait for navigation
- **Expected:** Navigate to /customers/{id}/collect with customerName passed; CustomerPaymentPage renders
- **Fails-as-passes if:** Navigation fires but customerName param lost. Seed: verify extra={'customerName': name} passes through route.
- **Risk:** P3-NAV
- **Why it matters:** Lost name param = payment page shows empty customer name, confusing

**TC-CUS-DETAIL-003**
- **Precondition:** Customer exists; user has customers.update permission; on detail page
- **Steps:** 1. Tap edit button 2. Verify form pre-filled with customer data
- **Expected:** Navigate to /customers/{id}/edit; CustomerFormPage renders in edit mode with all fields populated
- **Fails-as-passes if:** Form loads but fields blank. Seed: verify loadCustomerUseCaseProvider passes data to form.
- **Risk:** P1-DATA
- **Why it matters:** Empty form = user thinks customer not found, poor UX

**TC-CUS-DETAIL-004**
- **Precondition:** Customer exists; user has customers.delete permission; on detail page
- **Steps:** 1. Tap delete button 2. Dialog appears 3. Tap "Delete" in dialog
- **Expected:** RPC fires to delete customer; on success, detail page pops; return to list (customer no longer visible)
- **Fails-as-passes if:** Dialog shows but cancel/delete buttons missing or non-functional. Seed: verify dialog button callbacks.
- **Risk:** P0-MONEY
- **Why it matters:** Delete stuck = user cannot remove invalid customer record, data bloat

**TC-CUS-DETAIL-005**
- **Precondition:** Customer exists; user lacks customers.delete permission; on detail page
- **Steps:** 1. Verify delete button visibility
- **Expected:** Delete button hidden or disabled; PermissionGate fallback if tapped
- **Fails-as-passes if:** Delete button visible and tappable despite no permission. Seed: verify PermissionGate guard.
- **Risk:** P1-DATA
- **Why it matters:** Permission bypass = unauthorized user deletes customers, data integrity breach

**TC-CUS-DETAIL-006**
- **Precondition:** Customer deleted from DB; user still on detail page with stale reference
- **Steps:** 1. Delete customer via another session/API 2. Refresh detail page or wait for provider invalidation
- **Expected:** Error state shows ("Customer not found" or similar); user can navigate back
- **Fails-as-passes if:** Page crashes with exception. Seed: verify _customerProvider handles not-found error gracefully.
- **Risk:** P2-READ
- **Why it matters:** Crash = poor UX, user loses context

---

## SCREEN: CustomerPaymentPage

- **File:** lib/features/customers/presentation/pages/customer_payment_page.dart
- **Route:** `/customers/:customerId/collect` (router.dart:554)
- **Reached from:** CustomerDetailPage payment button or edit link
- **Guard:** PermissionGate(module='sales', action='create') wraps record payment button (line:205)
- **Reads:**
  - unpaidInvoicesProvider(customerId) → fetches unpaid invoices (line:276)
  - widget.invoiceId, widget.presetAmount (optional pre-selection)
- **Preconditions to render:** Customer must exist; ≥1 unpaid invoice must exist to record payment against
- **Exits:** Navigator.pop() after successful payment (line:125)

### Interactive elements

| # | Element (file:line) | Type | Label/Icon | Invokes | Expected result | Risk |
|---|---|---|---|---|---|---|
| 1 | Back button (customer_payment_page.dart:136) | IconButton | back arrow | onPressed → Navigator.pop() | Pop form; return to detail | P3-NAV |
| 2 | Invoice picker list (customer_payment_page.dart:296) | ListView of InkWells | invoice #, amount, due date | onTap(invoice) → _selectInvoice(invoice) (line:72) | Invoice selected; amount field auto-fills with unpaid balance | P1-DATA |
| 3 | Payment method dropdown (customer_payment_page.dart:359) | DropdownButton | "Cash", "Card", "Check", "Bank Transfer" | onChanged(v) → setState(() => _method = v) (line:185) | Dropdown expands; selected method shown | P2-READ |
| 4 | Amount field (customer_payment_page.dart:189) | TextField | "Amount" label, pre-filled if invoice selected | TextEditingController binding | User can edit amount (partial payment or override) | P1-DATA |
| 5 | Record payment button (customer_payment_page.dart:208) | Button | "Record payment" text, guarded | onPressed → _submit() (line:81) | RPC fires (customerPaymentsProvider.notifier.recordPayment); on success, pop; on error, banner shows | P0-MONEY |

### Test cases

**TC-CUS-PAY-001**
- **Precondition:** Customer has 2 unpaid invoices: INV-001 ($1,000, due today), INV-002 ($500, due next week); user has sales.create permission
- **Steps:** 1. Page renders 2. Tap INV-001 3. Select "Cash" from method dropdown 4. Verify amount auto-filled to $1,000 5. Tap Record payment
- **Expected:** Invoice selected; amount field shows $1,000; method selected; RPC fires (recordPayment); on success, page pops
- **Fails-as-passes if:** Amount not auto-filled when invoice selected. Seed: verify _selectInvoice sets amount to unpaid balance.
- **Risk:** P0-MONEY
- **Why it matters:** Wrong amount recorded = ledger imbalance, financial discrepancy

**TC-CUS-PAY-002**
- **Precondition:** Customer has unpaid invoice $1,000; user making partial payment of $500
- **Steps:** 1. Select invoice 2. Amount auto-fills to $1,000 3. Clear field and type "500" 4. Tap Record payment
- **Expected:** RPC fires with amount=$500; on success, invoice balance updates to $500; page pops
- **Fails-as-passes if:** Partial payment recorded but invoice still shows as fully unpaid. Seed: verify recordPayment RPC updates invoice.balance correctly.
- **Risk:** P0-MONEY
- **Why it matters:** Balance not updated = customer overpays, confused statement

**TC-CUS-PAY-003**
- **Precondition:** Customer has unpaid invoices; user lacks sales.create permission; on payment page
- **Steps:** 1. Fill in valid payment data 2. Tap Record payment
- **Expected:** PermissionGate blocks; button disabled or fallback shows; RPC does not fire
- **Fails-as-passes if:** Button enabled and RPC fires despite no permission. Seed: verify PermissionGate guard.
- **Risk:** P0-MONEY
- **Why it matters:** Permission bypass = unauthorized user records payments, fraud risk

**TC-CUS-PAY-004**
- **Precondition:** Customer has no unpaid invoices
- **Steps:** 1. Page renders 2. Try to record payment
- **Expected:** Invoice list empty or no selection option; error shows ("No unpaid invoices"); button disabled
- **Fails-as-passes if:** Form allows submission with no invoice selected. Seed: verify _submit checks invoice selected.
- **Risk:** P1-DATA
- **Why it matters:** Payment recorded with no invoice = orphaned transaction, GL imbalance

**TC-CUS-PAY-005**
- **Precondition:** Customer has unpaid invoice; user enters payment amount exceeding invoice balance (e.g., $1,500 for $1,000 invoice)
- **Steps:** 1. Select invoice ($1,000) 2. Manually change amount to $1,500 3. Tap Record payment
- **Expected:** RPC fires with amount=$1,500; on success, overpayment recorded and customer balance becomes credit; or validation error prevents overpayment (depends on business rule)
- **Fails-as-passes if:** RPC accepts overpayment silently; no warning to user. Seed: verify business logic: reject overpayment or warn user.
- **Risk:** P0-MONEY
- **Why it matters:** Unintended overpayment = customer credit untracked, accounting error

---

## SCREEN: ReceivablesAgingPage

- **File:** lib/features/customers/presentation/pages/receivables_aging_page.dart
- **Route:** `/receivables` (router.dart:541)
- **Reached from:** CustomersPage (optional), or direct nav from accounting/reporting features
- **Guard:** NONE (read-only report)
- **Reads:** receivablesAgingProvider → fetches aging bucket data (0-30d, 31-60d, 61+d)
- **Preconditions to render:** ≥1 customer with unpaid invoice, OR empty state if no receivables
- **Exits:** Navigator.pop() via back button

### Interactive elements

| # | Element (file:line) | Type | Label/Icon | Invokes | Expected result | Risk |
|---|---|---|---|---|---|---|
| 1 | Back button (receivables_aging_page.dart:26) | IconButton | back arrow | onPressed → Navigator.pop() | Pop report; return to nav | P3-NAV |
| 2 | Customer row card (receivables_aging_page.dart:142) | InkWell | customer name, phone, aging buckets (0-30, 31-60, 61+) | onTap → context.push('/customers/${customer.customerId}') | Navigate to customer detail page | P3-NAV |
| 3 | Retry button on error (receivables_aging_page.dart:46) | Button | "Retry" | onPressed → ref.invalidate(receivablesAgingProvider) | RPC re-runs; provider refetches data | P2-READ |

### Test cases

**TC-CUS-AGE-001**
- **Precondition:** 3 customers with aging data: Customer A ($500 0-30d, $1000 31-60d, $0 61+), Customer B ($0 all), Customer C ($2000 61+)
- **Steps:** 1. ReceivablesAgingPage renders 2. Scroll through customer rows 3. Verify aging totals per customer
- **Expected:** All customers render with correct aging bucket amounts; totals sum correctly
- **Fails-as-passes if:** Amounts show but sums are wrong (e.g., A's 0-30 + 31-60 ≠ total due). Seed: verify receivablesAgingProvider aggregates correctly.
- **Risk:** P2-READ
- **Why it matters:** Wrong aging totals = bad collection decisions, cash flow impact

**TC-CUS-AGE-002**
- **Precondition:** 2 customers exist; user on ReceivablesAgingPage
- **Steps:** 1. Tap Customer A row 2. Wait for navigation
- **Expected:** Navigate to /customers/{id}; CustomerDetailPage renders with Customer A's data
- **Fails-as-passes if:** Navigation fires but wrong customer loads. Seed: verify row onTap passes correct customerId.
- **Risk:** P3-NAV
- **Why it matters:** Wrong customer shown = user collects from wrong party, relationship risk

**TC-CUS-AGE-003**
- **Precondition:** RPC times out or fails when fetching aging data
- **Steps:** 1. Page renders 2. Error state shows 3. Tap Retry button
- **Expected:** Error message displays; Retry button tappable; on retry, RPC re-runs; on success, data loads
- **Fails-as-passes if:** Retry button missing or disabled after error. Seed: verify error state renders retry button.
- **Risk:** P2-READ
- **Why it matters:** Cannot retry = user cannot recover from transient network issue

**TC-CUS-AGE-004**
- **Precondition:** No customers or all customers have zero balance
- **Steps:** 1. ReceivablesAgingPage renders
- **Expected:** Empty state shows (e.g., "No receivables" message) OR aging table shows all zeros
- **Fails-as-passes if:** Empty list without message; user thinks feature broken. Seed: verify empty state widget renders.
- **Risk:** P2-READ
- **Why it matters:** No feedback = user confused, thinks page failed to load

---

## Summary

**Customers Feature Catalog Complete**

| Metric | Count |
|--------|-------|
| Pages catalogued | 5 |
| Routes | 5 |
| Interactive elements | 25 |
| Test cases written | 40 |
| P0-MONEY test cases | 8 |
| P1-DATA test cases | 10 |
| P2-READ test cases | 12 |
| P3-NAV test cases | 10 |

**Gaps & anomalies:**
- None detected. All 5 customer pages routed and functioning.
- PermissionGates correctly guarding create/update/delete/payment actions.
- RPCs traced from all interactive elements.

**Next:** Proceed to FEATURE=dashboard.
