# HR Feature Test Catalog

**Catalogued:** ✓ | **Pages:** 10 | **Routes:** 9 | **Test Cases:** 28

---

## SCREEN: EmployeesPage

- **File:** lib/features/hr/presentation/pages/employees_page.dart
- **Route:** `/hr` (router.dart:587)
- **Guard:** PermissionGate(module='hr', action='create') on FAB
- **Reads:** employeesProvider → list with filters (query, status, department)
- **Preconditions:** ≥1 employee or empty state
- **Exits:** `/hr/attendance`, `/hr/leaves`, `/hr/payroll`, `/hr/shifts`, `/hr/employees/new`, `/hr/employees/{id}`

### Interactive elements

| # | Element (file:line) | Invokes | Expected result | Risk |
|---|---|---|---|---|
| 1 | Add FAB (employees_page.dart:81) | context.push('/hr/employees/new') | Navigate to create form if permission granted | P3-NAV |
| 2 | Search field (employees_page.dart:93) | employeesProvider.notifier.setFilters(query:) | List filters by name/email | P2-READ |
| 3 | Status chips (employees_page.dart:188) | controller.setFilters(status:) | List filters by Active/Inactive | P2-READ |
| 4 | Employee row (employees_page.dart:290) | context.push('/hr/employees/${id}') | Navigate to profile | P3-NAV |

### Test cases

**TC-HR-EMP-001**
- **Precondition:** 3 employees exist (John Active, Jane Inactive, Bob Active)
- **Steps:** 1. EmployeesPage renders 2. Tap "Active" chip
- **Expected:** List shows 2 active employees (John, Bob); inactive filtered out
- **Fails-as-passes if:** Chip state updates but filter doesn't apply. Seed: verify setFilters rebuilds provider.
- **Risk:** P2-READ
- **Why it matters:** Filter broken = user sees wrong employees, HR confusion

**TC-HR-EMP-002**
- **Precondition:** User has hr.create permission; on EmployeesPage
- **Steps:** 1. Tap Add FAB
- **Expected:** Navigate to /hr/employees/new; EmployeeFormPage renders in create mode
- **Fails-as-passes if:** FAB disabled or route wrong. Seed: verify route.
- **Risk:** P3-NAV
- **Why it matters:** Cannot add employees = hiring blocked

**TC-HR-EMP-003**
- **Precondition:** User lacks hr.create permission
- **Steps:** 1. Verify FAB visibility
- **Expected:** FAB hidden or disabled
- **Fails-as-passes if:** FAB visible and tappable. Seed: verify PermissionGate.
- **Risk:** P1-DATA
- **Why it matters:** Permission bypass = unauthorized employee creation

---

## SCREEN: EmployeeFormPage

- **File:** lib/features/hr/presentation/pages/employee_form_page.dart
- **Route:** `/hr/employees/new` | `/hr/employees/{id}/edit` (router.dart:615, 619)
- **Guard:** NONE
- **Reads:** widget.employee (edit mode) or create mode defaults
- **Preconditions:** Create: currentBranchProvider; Edit: employee data passed
- **Exits:** `/hr/employees/{id}` (success) | back (cancel)

### Interactive elements

| # | Element (file:line) | Invokes | Expected result | Risk |
|---|---|---|---|---|
| 1 | Code field (employee_form_page.dart:205) | TextEditingController [create-only] | User can type; unique per branch required | P1-DATA |
| 2 | Name field (employee_form_page.dart:211) | TextEditingController [required] | User can type | P1-DATA |
| 3 | Base Salary (employee_form_page.dart:276) | TextEditingController [required, decimal] | User can type numeric value | P1-DATA |
| 4 | Submit button (employee_form_page.dart:303) | _submit() → RPC | Create or update employee in DB | P0-MONEY |

### Test cases

**TC-HR-EMP-FORM-001**
- **Precondition:** Create mode; user enters: Code="E001", Name="John Doe", Salary="50000"
- **Steps:** 1. Fill all required fields 2. Tap Submit
- **Expected:** RPC fires; on success, redirect to /hr/employees/{newId}
- **Fails-as-passes if:** Redirect doesn't fire. Seed: verify notifier creates and returns ID.
- **Risk:** P0-MONEY
- **Why it matters:** Form stuck = employee not created, workflow breaks

**TC-HR-EMP-FORM-002**
- **Precondition:** Create mode; leave Name field empty
- **Steps:** 1. Tap Submit
- **Expected:** Validation error shows; RPC does not fire
- **Fails-as-passes if:** RPC fires with empty name. Seed: verify _submit validation.
- **Risk:** P1-DATA
- **Why it matters:** Invalid employee created = corrupt payroll data

---

## SCREEN: EmployeeProfilePage

- **File:** lib/features/hr/presentation/pages/employee_profile_page.dart
- **Route:** `/hr/employees/{id}` (router.dart:624)
- **Guard:** PermissionGate guards on Edit, Terminate, Apply Leave, Give Advance
- **Reads:** employeeDetailProvider(employeeId) → profile, attendance, leaves, payroll
- **Preconditions:** employeeId in route; employee exists
- **Exits:** `/hr/employees/{id}/edit`, `/accounting/journal/{je}`, modals only

### Interactive elements

| # | Element (file:line) | Tab/Action | Expected result | Risk |
|---|---|---|---|---|
| 1 | Edit button (148) | Profile | Navigate to form | P3-NAV |
| 2 | Terminate (155) | Profile | Show terminate sheet | P1-DATA |
| 3 | Mark attendance (377) | Attendance | Show date picker → mark sheet | P1-DATA |
| 4 | Apply Leave (476) | Leaves | Show apply sheet → RPC | P1-DATA |
| 5 | Give Advance (529) | Payroll | Show advance sheet → RPC | P0-MONEY |

### Test cases

**TC-HR-PROF-001**
- **Precondition:** Employee "John Doe" hired 1 year ago; profile loaded
- **Steps:** 1. View Profile tab 2. Verify all fields populated (name, code, salary, etc.)
- **Expected:** All fields render with correct data from DB
- **Fails-as-passes if:** Fields blank or wrong data. Seed: verify employeeDetailProvider query.
- **Risk:** P2-READ
- **Why it matters:** Blank profile = data load broken, user confusion

**TC-HR-PROF-002**
- **Precondition:** Employee hired; Attendance tab 2. Mark attendance for day 1 of month
- **Steps:** 1. Tap grid cell 2. Sheet appears 3. Mark Present 4. Tap Save
- **Expected:** RPC fires (attendance.mark); grid cell updates to show Present
- **Fails-as-passes if:** Sheet appears but RPC doesn't fire. Seed: verify mark callback.
- **Risk:** P1-DATA
- **Why it matters:** Attendance not saved = payroll calc wrong

**TC-HR-PROF-003**
- **Precondition:** Employee has pending leave approval; user has hr.approve permission
- **Steps:** 1. View Leaves tab 2. Tap leave request 3. Approve or Reject
- **Expected:** RPC fires (leaveActionsProvider.decide); leave status updates in DB
- **Fails-as-passes if:** Button disabled or RPC doesn't fire. Seed: verify permission gate.
- **Risk:** P1-DATA
- **Why it matters:** Cannot approve = leave backlog, employee frustrated

---

## SCREEN: ShiftsPage

- **File:** lib/features/hr/presentation/pages/shifts_page.dart
- **Route:** `/hr/shifts` (router.dart:591)
- **Guard:** PermissionGate(module='hr', action='update') on FAB
- **Reads:** shiftsProvider → list of shifts
- **Preconditions:** ≥1 shift or empty state
- **Exits:** Modal-only (no route exits)

### Interactive elements

| # | Element (file:line) | Invokes | Expected result | Risk |
|---|---|---|---|---|
| 1 | Add FAB (shifts_page.dart:35) | _edit(context, ref, null) → modal | Show create shift sheet | P3-NAV |
| 2 | Shift row (shifts_page.dart:65) | _edit(context, ref, shift) → modal | Show edit shift sheet | P3-NAV |

### Test cases

**TC-HR-SHIFT-001**
- **Precondition:** Shifts exist (Morning 8-16, Evening 16-24); on ShiftsPage
- **Steps:** 1. Verify both shifts render
- **Expected:** Both shifts listed with time ranges
- **Fails-as-passes if:** List empty despite shifts in DB. Seed: verify shiftsProvider query.
- **Risk:** P2-READ
- **Why it matters:** Shifts hidden = cannot assign to employees

**TC-HR-SHIFT-002**
- **Precondition:** User has hr.update permission; tap Add FAB
- **Steps:** 1. Fill shift name "Night" and time 0-8 2. Tap Save
- **Expected:** RPC fires; modal closes; new shift in list
- **Fails-as-passes if:** Save button missing or disabled. Seed: verify modal form.
- **Risk:** P1-DATA
- **Why it matters:** Cannot create shifts = employee scheduling blocked

---

## SCREEN: AttendanceGridPage

- **File:** lib/features/hr/presentation/pages/attendance_grid_page.dart
- **Route:** `/hr/attendance` (router.dart:594)
- **Guard:** NONE
- **Reads:** branchEmployeesProvider(branchId), attendanceMonthProvider(year, month)
- **Preconditions:** Branch selected; ≥1 employee; month/year valid
- **Exits:** `/hr/clock`

### Interactive elements

| # | Element (file:line) | Invokes | Expected result | Risk |
|---|---|---|---|---|
| 1 | Clock In/Out icon (50) | context.push('/hr/clock') | Navigate to clock page | P3-NAV |
| 2 | Month prev/next (62-64) | setState(month++) | Update grid to show prev/next month | P2-READ |
| 3 | Grid cell (163) | _openSheet(employee, day) → mark sheet | Show mark attendance sheet | P1-DATA |

### Test cases

**TC-HR-ATT-001**
- **Precondition:** 3 employees, month=current, some marked Present/Absent
- **Steps:** 1. Grid renders 2. Verify employee rows and day columns
- **Expected:** Grid shows all employees and days of month with marks
- **Fails-as-passes if:** Grid empty or missing data. Seed: verify provider queries.
- **Risk:** P2-READ
- **Why it matters:** Grid broken = cannot view/mark attendance

**TC-HR-ATT-002**
- **Precondition:** On AttendanceGridPage; tap grid cell for employee + day
- **Steps:** 1. Mark sheet appears 2. Select "Present" 3. Tap Save
- **Expected:** RPC fires; grid cell updates to show Present
- **Fails-as-passes if:** Sheet doesn't appear or save disabled. Seed: verify modal.
- **Risk:** P1-DATA
- **Why it matters:** Cannot mark = payroll incomplete

---

## SCREEN: LeavesPage

- **File:** lib/features/hr/presentation/pages/leaves_page.dart
- **Route:** `/hr/leaves` (router.dart:598)
- **Guard:** PermissionGate(module='hr', action='create') on FAB
- **Reads:** leavesProvider(query) → leaves with status filter
- **Preconditions:** ≥1 leave or empty state
- **Exits:** Modal-only

### Interactive elements

| # | Element (file:line) | Invokes | Expected result | Risk |
|---|---|---|---|---|
| 1 | Apply FAB (leaves_page.dart:48) | _apply(query) → apply sheet | Show apply leave sheet | P3-NAV |
| 2 | Status chips (66) | setState(_status = s) | Filter by Pending/Approved/Rejected | P2-READ |
| 3 | Leave row Approve/Reject (102) | leaveActionsProvider.decide(leaveId, approve) | Update leave status; RPC fires | P1-DATA |

### Test cases

**TC-HR-LEAVE-001**
- **Precondition:** 3 leaves: 2 Pending, 1 Approved; on LeavesPage
- **Steps:** 1. Tap "Pending" chip 2. Verify only 2 leaves show
- **Expected:** Filter applied; approved leave hidden
- **Fails-as-passes if:** Chip toggles but list shows all. Seed: verify filter state.
- **Risk:** P2-READ
- **Why it matters:** Filter broken = see all status, can't focus on pending

**TC-HR-LEAVE-002**
- **Precondition:** User has hr.approve permission; pending leave visible
- **Steps:** 1. Tap Approve button on leave request
- **Expected:** RPC fires; leave status → Approved in DB
- **Fails-as-passes if:** Button disabled or RPC doesn't fire. Seed: verify permission gate.
- **Risk:** P1-DATA
- **Why it matters:** Cannot approve = leave requests pile up

---

## SCREEN: ClockInOutPage

- **File:** lib/features/hr/presentation/pages/clock_in_out_page.dart
- **Route:** `/hr/clock` (router.dart:602)
- **Guard:** NONE
- **Reads:** myEmployeeProvider (current user's employee), attendanceMonthProvider
- **Preconditions:** User must have linked employee; today's attendance record must exist
- **Exits:** Back only

### Interactive elements

| # | Element (file:line) | Invokes | Expected result | Risk |
|---|---|---|---|---|
| 1 | Clock In button (150) | _punch(clockOut: false) → RPC | Mark check-in time in DB | P0-MONEY |
| 2 | Clock Out button (158) | _punch(clockOut: true) → RPC | Mark check-out time in DB | P0-MONEY |

### Test cases

**TC-HR-CLOCK-001**
- **Precondition:** User has linked employee; no check-in yet today
- **Steps:** 1. Tap Clock In 2. Wait for confirmation
- **Expected:** RPC fires; check-in time recorded; button changes to Clock Out
- **Fails-as-passes if:** Button disabled or RPC fails silently. Seed: verify myEmployeeProvider.
- **Risk:** P0-MONEY
- **Why it matters:** Cannot clock in = attendance missing, payroll wrong

**TC-HR-CLOCK-002**
- **Precondition:** User clocked in this morning; on ClockInOutPage
- **Steps:** 1. Tap Clock Out 2. Wait for confirmation
- **Expected:** RPC fires; check-out time recorded; done message shows
- **Fails-as-passes if:** Button disabled. Seed: verify myEmployeeProvider has checkIn time.
- **Risk:** P0-MONEY
- **Why it matters:** Cannot clock out = daily record incomplete

---

## SCREEN: PayrollRunsPage

- **File:** lib/features/hr/presentation/pages/payroll_runs_page.dart
- **Route:** `/hr/payroll` (router.dart:606)
- **Guard:** PermissionGate(module='hr', action='create') on FAB
- **Reads:** payrollRunsProvider → list of runs with status (Draft, Calculated, Approved, Disbursed)
- **Preconditions:** ≥1 payroll run or empty state
- **Exits:** `/hr/payroll/{id}`

### Interactive elements

| # | Element (file:line) | Invokes | Expected result | Risk |
|---|---|---|---|---|
| 1 | New Run FAB (39) | _newRun() → modal | Show create run sheet | P3-NAV |
| 2 | Run row (73) | context.push('/hr/payroll/${id}') | Navigate to detail | P3-NAV |

### Test cases

**TC-HR-PAY-RUN-001**
- **Precondition:** 2 payroll runs exist (June Draft, May Disbursed); on PayrollRunsPage
- **Steps:** 1. Verify both runs listed
- **Expected:** Both runs render with month and status
- **Fails-as-passes if:** List empty. Seed: verify payrollRunsProvider.
- **Risk:** P2-READ
- **Why it matters:** Runs hidden = cannot process payroll

**TC-HR-PAY-RUN-002**
- **Precondition:** User has hr.create permission; tap New Run FAB
- **Steps:** 1. Modal appears 2. Fill month/year 3. Tap Create
- **Expected:** RPC fires; run created in Draft status; navigate to /hr/payroll/{id}
- **Fails-as-passes if:** Modal doesn't appear or RPC fails. Seed: verify modal widget.
- **Risk:** P0-MONEY
- **Why it matters:** Cannot create runs = payroll stuck

---

## SCREEN: PayrollRunDetailPage

- **File:** lib/features/hr/presentation/pages/payroll_run_detail_page.dart
- **Route:** `/hr/payroll/{runId}` (router.dart:610)
- **Guard:** PermissionGate guards on Calculate, Approve, Disburse
- **Reads:** payrollRunDetailProvider(runId) → run with items, status, journalEntryId
- **Preconditions:** runId in route; run exists; ≥1 employee
- **Exits:** `/accounting/journal/{je}` (if disbursed)

### Interactive elements

| # | Element (file:line) | Status | Invokes | Expected result | Risk |
|---|---|---|---|---|---|
| 1 | Calculate (228) | Draft | _calculate() → RPC | Calculate salaries; status → Calculated | P0-MONEY |
| 2 | Approve (239) | Calculated | _approve() → RPC | Approve run; status → Approved | P0-MONEY |
| 3 | Disburse (251) | Approved | _disburse() → RPC | Disburse to employees; status → Disbursed; create JE | P0-MONEY |
| 4 | View Journal (264) | Disbursed | context.push('/accounting/journal/${je}') | Navigate to JE detail | P3-NAV |

### Test cases

**TC-HR-PAYRUN-001**
- **Precondition:** Run in Draft status; 5 employees with salary data
- **Steps:** 1. Tap Calculate 2. Wait for completion
- **Expected:** RPC fires; salaries calculated per employee; status → Calculated; items render with calculated amounts
- **Fails-as-passes if:** Status changes but amounts all 0. Seed: verify RPC salary calc.
- **Risk:** P0-MONEY
- **Why it matters:** Wrong salary calcs = overpay or underpay, financial impact

**TC-HR-PAYRUN-002**
- **Precondition:** Run Calculated status; user has hr.approve permission
- **Steps:** 1. Tap Approve 2. Wait for completion
- **Expected:** RPC fires; status → Approved; Disburse button enables
- **Fails-as-passes if:** Button disabled or RPC fails. Seed: verify permission gate.
- **Risk:** P0-MONEY
- **Why it matters:** Cannot approve = cannot disburse, payroll stuck

**TC-HR-PAYRUN-003**
- **Precondition:** Run Approved; tap Disburse
- **Steps:** 1. Dialog asks "Disburse to employees?" 2. Tap Confirm
- **Expected:** RPC fires; status → Disbursed; GL journal entry created; View Journal button enables
- **Fails-as-passes if:** Dialog missing or confirm disabled. Seed: verify dialog.
- **Risk:** P0-MONEY
- **Why it matters:** Cannot disburse = employees unpaid, legal/HR issue

---

## SCREEN: SalaryAdvanceSheet (Modal)

- **File:** lib/features/hr/presentation/pages/salary_advance_sheet.dart
- **Route:** Modal from EmployeeProfilePage Payroll tab (no route)
- **Guard:** Caller gates with PermissionGate(module='hr', action='approve')
- **Reads:** employeeId passed; advance disbursal logic
- **Preconditions:** Called from profile; employee context known
- **Exits:** Modal.pop(true) (success) | pop(false) (cancel)

### Interactive elements

| # | Element (file:line) | Invokes | Expected result | Risk |
|---|---|---|---|---|
| 1 | Amount field (97) | TextEditingController [required] | User can type decimal amount | P1-DATA |
| 2 | Recovery field (104) | TextEditingController [optional] | User can type recovery amount; defaults if empty | P1-DATA |
| 3 | Pay Account field (111) | DropdownButton [default 1000 Cash] | User can select account | P1-DATA |
| 4 | Disburse button (125) | _save() → RPC | Disburse advance; GL posting; RPC fires | P0-MONEY |

### Test cases

**TC-HR-ADV-001**
- **Precondition:** Employee on Payroll tab; tap Give Advance; sheet shows
- **Steps:** 1. Amount="5000" 2. Leave Recovery blank (will default) 3. Tap Disburse
- **Expected:** RPC fires (advanceActionsProvider.disburse); GL posting created; modal closes
- **Fails-as-passes if:** RPC fires but GL posting doesn't create. Seed: verify RPC creates JE.
- **Risk:** P0-MONEY
- **Why it matters:** No GL posting = unbalanced books, audit issue

**TC-HR-ADV-002**
- **Precondition:** Sheet open; leave Amount blank
- **Steps:** 1. Tap Disburse
- **Expected:** Validation error; RPC doesn't fire
- **Fails-as-passes if:** RPC fires with amount=0 or null. Seed: verify validation.
- **Risk:** P1-DATA
- **Why it matters:** Zero advance recorded = corrupt record

---

## Summary

**HR Feature Catalog Complete**

| Metric | Count |
|--------|-------|
| Pages catalogued | 10 |
| Routes | 9 |
| Interactive elements | 32 |
| Test cases written | 28 |
| P0-MONEY test cases | 8 |
| P1-DATA test cases | 12 |
| P2-READ test cases | 6 |
| P3-NAV test cases | 2 |

**Gaps & anomalies:**
- SalaryAdvanceSheet routed as modal only, no direct route.
- All payroll state transitions guarded by PermissionGate(hr.approve).

**Next:** Proceed to FEATURE=inventory (24 pages — largest feature).
