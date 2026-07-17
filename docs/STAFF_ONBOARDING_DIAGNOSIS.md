# Staff Onboarding — Diagnosis Report

**Scope:** Read-only audit. No writes made to code, schema, RLS, or data. All DB evidence pulled live via
`supabase db query --linked` (Management API, read-only SELECT/introspection only) against project
`pwkmrjzksxwxypqmblel` (Lumina POS). All code evidence pulled via direct file reads / grep against
`/Users/ahmadraza/Developer/pos_app`. Live schema was used as source of truth (not migration files);
no drift check was run between the two — see Assumptions.

---

## 1. Executive Summary

- **Signup is a single public form** (`signup_page.dart`). Business name filled → new ADMIN tenant
  provisioned. Business name blank → user is silently dropped into a shared, hardcoded **Demo Store**
  tenant as CASHIER. There is no way to disable one path without touching the other — both live inside
  the same `handle_new_user()` trigger function.
- **No invite/onboarding mechanism exists anywhere** — no table, no RPC, no Edge Function, no route.
  Confirmed by exhaustive search (DB table names, DB function names, router.dart, lib/features/auth/).
- **No way for an owner to add a real cashier to their own business.** `create_employee` only writes an
  HR record (`employees` table); it never touches `auth.users` or `public.users`. Confirmed: `p_user_id`
  is hardcoded to `null` in the employee form.
- **Permissions are already data-driven** (`roles` + `permissions` tables, not an enum) — a third role
  (SUB_ADMIN) and à-la-carte per-role permissions are both addable **today, with zero schema changes**,
  just data inserts. Enforcement is real: `auth_has_permission()` is used inside RLS policies AND inside
  money/HR-moving RPCs — not cosmetic.
- **QR infrastructure is already in the app** — `qr_flutter` (generation, used for MFA enrollment) and
  `mobile_scanner` (scanning, used for 8 barcode-scan screens) are both installed and proven working.
  Neither is wired to anything invite-related yet.
- **`handle_new_user()` already branches on `raw_user_meta_data`** inside a `SECURITY DEFINER` trigger on
  `auth.users` — the mechanical pattern needed to make signup "read an invite token from metadata and
  join an existing tenant instead of creating one" already exists and is proven in production, just not
  built for that purpose yet.
- **CRITICAL, pre-existing security bug, unrelated to this feature but directly relevant to its blast
  radius:** any authenticated user (including a CASHIER) can self-promote to ADMIN in their own tenant
  via a single `UPDATE public.users SET role_id = ...` call. The RLS policy that allows a user to update
  their own row has no `WITH CHECK`, so nothing stops them from rewriting their own `role_id`. This
  should be fixed before (or alongside) shipping a feature that creates more non-ADMIN accounts.
- **Two secondary, pre-existing, lower-severity findings**: `increment_failed_login`/`reset_failed_login`
  are callable by anyone with only the anon key and take a bare email string — no proof of identity is
  required to lock or unlock any account. `provision_tenant()` takes a caller-supplied tenant UUID with
  no ownership check.
- **Single biggest blocker for the target flow:** there is no unauthenticated ("pre-auth") data-access
  pattern in this codebase at all — no anon-callable RPC reads a row by opaque token, and RLS grants
  nothing to `anon`. A QR-redemption flow needs exactly this pattern and it does not exist yet, though
  `handle_new_user()` proves the surrounding mechanics (metadata-driven branching in a definer trigger)
  are already understood and working in this codebase.

---

## 2. Stack & Architecture

- **Client:** Flutter/Dart, `supabase_flutter` package talking directly to Supabase (no custom backend
  server). Clean-architecture layering per feature: `domain/` (entities, repositories, usecases) →
  `data/` (datasources, models, repository impls) → `presentation/` (Riverpod controllers, pages,
  widgets). Confirmed for `lib/features/auth/` and `lib/features/hr/` (directory maps in Appendix B).
- **Backend:** Supabase (Postgres 15+, Supabase Auth, Storage). All business logic lives in Postgres
  `SECURITY DEFINER` functions (~180 functions in the `public` schema) called via `supabase.rpc(...)`
  from the client — there is no separate API server. 3 Supabase Edge Functions exist
  (`list-sessions`, `revoke-session`, `notification-sender`), all `verify_jwt = false` (self-verify
  internally), none related to auth/signup/invites.
- **Migrations:** 133 files under `supabase/migrations/`, applied via `supabase db push`. This report
  used the **live** schema (`supabase db query --linked`), not the migration files, per the task's own
  instruction to prefer live state — no explicit file-by-file drift check was performed (see §11).
- **Auth model:** `auth.users` (Supabase Auth) owns credentials/sessions/JWT. `public.users` is a profile
  row, `id` FK-shaped to `auth.users.id` (see `users_id_fkey` in Appendix A — the constraint exists but
  `information_schema` doesn't resolve its target table name across schemas; this is the standard
  Supabase `id references auth.users(id)` pattern). A single trigger,
  `on_auth_user_created AFTER INSERT ON auth.users → handle_new_user()`, provisions everything else.

---

## 3. Current Schema (as-built)

All RLS is enabled on every table listed below (`rls_forced = false` everywhere in the project — RLS
does not apply to the table owner / `SECURITY DEFINER` functions run as owner, which is why so much of
the enforcement lives inside the RPCs, not just RLS).

### `tenants`
`id uuid PK`, `name text NOT NULL`, `slug text`, `settings_json jsonb DEFAULT '{}'`,
`is_active boolean DEFAULT true`, `created_at timestamptz`. 5 rows live (Demo Store + 4 real
businesses). No columns for invite policy / staff limits.

### `roles`
`id uuid PK`, `tenant_id uuid NULLABLE FK→tenants`, `name text NOT NULL`, `description text`,
`is_system_role boolean DEFAULT false`, `hierarchy_level int DEFAULT 99`, `requires_mfa boolean
DEFAULT false`, `created_at timestamptz`. **Not an enum** — confirmed against the full enum list (no
`role_enum`/`user_role_enum` exists in `public`). 10 rows live: every tenant has its own ADMIN +
CASHIER role rows (tenant-scoped, not shared, except Demo Store's are the two hardcoded ones referenced
by `handle_new_user()`). `tenant_id` being nullable suggests room for global/system roles, though none
exist today (all 10 rows have a non-null `tenant_id`).

### `permissions`
`id uuid PK`, `role_id uuid NOT NULL FK→roles`, `module text NOT NULL`, `action text NOT NULL`,
`branch_scope branch_scope_enum DEFAULT 'OWN_BRANCH'` (`ALL`/`OWN_BRANCH`/`ASSIGNED_BRANCHES`),
`granted boolean DEFAULT false`, `created_at timestamptz`. 316 rows live. **Per-role, not per-user** —
there is no `user_id` column here and no separate per-user override table.

### `users`
`id uuid PK` (= `auth.users.id`), `tenant_id uuid NULLABLE FK→tenants`, `role_id uuid NULLABLE
FK→roles`, `full_name text`, `email text`, `status text DEFAULT 'ACTIVE'` (plain text, **not** cast to
the `user_status_enum` type that exists in the DB — schema drift, low-severity), `phone text`,
`avatar_url text`, `last_login_at timestamptz`, `failed_login_count int DEFAULT 0`, `locked_until
timestamptz`, `pin_hash text`, `created_at`/`updated_at timestamptz`. **No password column** —
credentials live entirely in `auth.users`. 2 rows live (one per tenant that has completed signup with
a business name).

### `employees`
`id uuid PK`, `tenant_id uuid NOT NULL FK→tenants`, `branch_id uuid NOT NULL FK→branches`, `user_id
uuid NULLABLE FK→users`, `employee_code varchar NOT NULL`, `name varchar NOT NULL`, plus HR fields
(`cnic`, `phone`, `email`, `address`, `designation`, `department`, `joining_date`, `salary_type`,
`base_salary`, `bank_name`, `bank_account_number`, `emergency_contact/phone`, `documents_json`,
`status employee_status_enum`, `notes`, `version`, soft-delete `deleted_at`, `created_by`/`updated_by`
FK→users). 0 rows live. `user_id` is nullable and, per code trace, is always inserted as `null` by the
one form that creates employees today.

### `branches`
`id uuid PK`, `tenant_id uuid NOT NULL FK→tenants`, `name`, `code`, `city`, `country DEFAULT
'Pakistan'`, `currency DEFAULT 'PKR'`, `timezone DEFAULT 'Asia/Karachi'`, `is_active boolean DEFAULT
true`, `is_main boolean DEFAULT false`, `created_at`. 3 rows live.

### `user_branch_assignments`
`id uuid PK`, `user_id uuid NOT NULL FK→users`, `branch_id uuid NOT NULL FK→branches`, `is_default
boolean DEFAULT false`, `created_at`. 2 rows live. **No unique constraint text captured beyond FK/PK**
(the `on conflict (user_id, branch_id)` clause in `handle_new_user()` implies a unique constraint on
that pair exists, though it wasn't separately itemized in the constraint dump — see §11).

### `devices` / `device_tokens`
`devices`: tenant/user/branch scoped, `fingerprint_hash`, `trust_level device_trust_level_enum`
(`PENDING`/`TRUSTED`/`RESTRICTED`/`SUSPICIOUS`/`REVOKED`/`EXPIRED`), `authorized boolean`,
`authorized_by uuid FK→users`. `device_tokens`: push-notification tokens, tenant/user scoped, `token`,
`platform`, `is_active`. Both exist and are populated (2 devices, 0 tokens live) — unrelated to invites
but structurally the closest existing pattern to "a row an authenticated user self-registers."

### `sessions` / `cashier_sessions` (do not confuse these two)
- `sessions`: `user_id`, `device_id`, `branch_id`, `ip_address`, `user_agent`, `status
  session_status_enum`, `expires_at`, `revoked_at`, `revoked_reason`. **0 rows live** despite 2 users
  and active usage — this table appears to be dead/unused schema; actual session lifecycle is handled
  entirely by Supabase Auth (`auth.sessions`, opaque to the app), confirmed by `main.dart` using
  `Supabase.initialize()` with package defaults and no custom session table writes found in the auth
  datasource. Treat any future design against `sessions` with caution — it's provisioned but not wired.
- `cashier_sessions`: `tenant_id`, `branch_id`, `cashier_id FK→users`, `device_id`, `opening_float`,
  `closing_float`, `expected_float`, `cash_variance`, `total_sales/returns/transactions`, `status
  cashier_session_status_enum` (`OPEN`/`CLOSED`/`SUSPENDED`). **This is the till/shift-handover concept**
  the target-flow questionnaire asked about (Part D.6) — it exists and has 1 live row, gated by
  `open_cashier_session`/`close_cashier_session` RPCs. It is unrelated to the QR staff-invite flow but
  confirms the codebase already has a "cashier session" concept distinct from PIN re-lock.

### `mfa_configs`
`user_id uuid UNIQUE FK→users`, `enabled boolean`, `sms_phone`, `last_used_at`. TOTP enrollment uses
`qr_flutter` to render the QR (see §4.5/§6 below) — this is the only existing QR-generation usage.

### ER sketch (auth/tenancy/staff cluster)

```
auth.users (Supabase Auth) ──1:1── public.users ──*:1── roles ──1:*── permissions
     │ (trigger: handle_new_user)      │  │                  (role_id, module, action, granted)
     ▼                                 │  └──*:1── tenants ──1:*── branches
public.tenants ◄──1:*── public.roles   │
     │                                 ├──*:*── user_branch_assignments ──*:1── branches
     └──1:*── branches                 │
                                       ├──1:1── mfa_configs
                                       ├──1:*── devices, device_tokens
                                       └──1:*── (sessions[dead] / cashier_sessions[live])

employees (tenant_id, branch_id NOT NULL) ──0:1── users.id via employees.user_id (nullable, unread
  by anything today — see §6)
```

---

## 4. Current Flows (traced, with file:line)

### 4.1 Signup — ADMIN path
1. `signup_page.dart:22-25` collects business name (optional), full name, email, password.
2. `signup_page.dart:43` blocks submit only if email/password empty — business name has no validation.
3. `signup_page.dart:49-51` passes `businessName: businessName.isNotEmpty ? businessName : null` down.
4. `auth_remote_datasource.dart:20-27`:
   ```dart
   final res = await _client.auth.signUp(
     email: email, password: password,
     data: { if (fullName != null) 'full_name': fullName,
             if (businessName != null) 'business_name': businessName },
   );
   ```
5. Supabase Auth inserts a row into `auth.users` with that metadata in `raw_user_meta_data`.
6. Trigger `on_auth_user_created` fires `handle_new_user()` (SECURITY DEFINER, `public` schema):
   - `v_business_name := nullif(trim(new.raw_user_meta_data->>'business_name'), '')` — branch point.
   - Since non-null: `insert into tenants (name) values (v_business_name)`.
   - `insert into roles (...) values (tenant_id,'ADMIN',true,1)` and `...'CASHIER',true,5`.
   - `insert into branches (...) values (tenant_id,'Main Branch','BR01',true)`.
   - `perform provision_tenant(tenant_id)` — seeds 20 chart-of-accounts rows, 8 working number series,
     4 tax rules, current fiscal period, a `REPAIR-SERVICE` sentinel product, 3 SMS + 3 email templates,
     one default warehouse per branch, 7 payment methods. Returns a `verify_tenant_provisioning()`
     completeness object (used for post-signup health checks, not surfaced to the client in this trace).
   - Direct `insert into permissions` for ADMIN: full matrix across
     `{sales,inventory,customers,reports,settings,users} × {read,create,update,delete,approve,export}`.
   - Direct `insert into permissions` for CASHIER: 6 explicit rows
     (`sales.read/create`, `inventory.read`, `customers.read/create`, `reports.read`), all
     `OWN_BRANCH`-scoped.
   - Separately, 7 *other* triggers (`seed_accounting_perms_for_admin`, `..._approvals_...`,
     `..._hr_...`, `..._notifications_...`, `..._purchase_...`, `..._repair_...`, `..._sync_...`) fire
     `AFTER INSERT ON roles` and each independently top up the ADMIN role (and only if
     `NEW.name = 'ADMIN'` exactly) with a further 6-ish rows per module (`accounting`, `approvals`,
     `hr`, `notifications`, `purchase`, `repair`, `sync`) — so the ADMIN permission set is assembled
     from **two separate mechanisms** (inline insert + 7 triggers), not one.
   - `insert into users (id, tenant_id, role_id, email, full_name) values (new.id, ...)`.
   - `insert into user_branch_assignments (user_id, branch_id, is_default) values (new.id, branch_id,
     true)`.
7. Email confirmation: not directly traced in this pass (out of the agent's scoped questions), but
   `login_page.dart:56-64` handles an `EmailNotConfirmedFailure` by redirecting to `/otp` — implying
   Supabase Auth's built-in email-OTP confirmation gate is active. Not separately verified against
   Supabase Auth project settings (outside SQL/code scope of this audit).

### 4.2 Signup — Demo Store / CASHIER path
Same steps 1-5 above, except step 6 skips straight to the `else` branch:
```sql
else
  v_tenant_id := '00000000-0000-0000-0000-000000000001';   -- Demo Store
  v_role_id   := '00000000-0000-0000-0000-000000000012';   -- Demo Store CASHIER (fallback)
  v_branch_id := '00000000-0000-0000-0000-0000000000b1';   -- Demo Store Main Branch
```
then falls through to the same `insert into users` / `insert into user_branch_assignments` as the ADMIN
path. All three UUIDs are literal string constants inside the function body — confirmed live in
`tenants` (`00000000-0000-0000-0000-000000000001` = "Demo Store", created 2026-06-08) and `roles`
(`00000000-0000-0000-0000-000000000012` = CASHIER, `tenant_id` = the same Demo Store UUID).

### 4.3 Login
1. `login_page.dart:38-51` collects email/password; a client-side `LoginThrottleService`
   (`login_page.dart:44-48`) adds a local cooldown independent of the server-side
   `increment_failed_login`/`reset_failed_login` mechanism (§7).
2. `sign_in_controller.dart:16-49` calls the sign-in usecase.
3. `auth_remote_datasource.dart:41-44`: `_client.auth.signInWithPassword(email: email, password:
   password)`.
4. On `EmailNotConfirmedFailure`, redirect to `/otp` (`login_page.dart:56-64`).
5. Post-login, the router guard (`router.dart:199-201`) checks `MfaState.instance.needsMfa` and forces
   `/mfa-challenge` if AAL2 is required — MFA is enforced as a **router-level gate after sign-in**, not
   inside the sign-in call itself.

### 4.4 Session + PIN re-lock
- Session: `main.dart:25-28` — `Supabase.initialize(url: Env.supabaseUrl, publishableKey:
  Env.supabaseAnonKey)` with no explicit `persistSession`/`autoRefreshToken`/storage overrides — package
  defaults apply (`supabase_flutter` defaults to `persistSession: true`, `autoRefreshToken: true`,
  platform-appropriate local storage). Exact JWT/refresh-token expiry was **not verified** against the
  Supabase Auth project dashboard (outside SQL/code scope) — see §11.
- PIN re-lock trigger: `app.dart:28-42`, fires on `AppLifecycleState.resumed` (app foregrounded), **not**
  an idle timer. Guarded by `supabase.auth.currentUser == null` early-return, so it only re-locks the
  currently authenticated session — confirmed not a cashier-switch mechanism.
- PIN storage: `pin_service.dart:24-28,63-86` — salted SHA-256 hash in `flutter_secure_storage`, keyed
  per-user-id (`'${base}_$uid'`). `verifyPin()` compares entirely on-device; a server-mirrored
  `pin_hash` column exists on `public.users` but per the trace is used for sync/recovery, not the actual
  unlock check.

### 4.5 Permission check at runtime
- Server: `auth_has_permission(module, action)` (SQL, `SECURITY DEFINER`, `STABLE`):
  ```sql
  select exists (select 1 from permissions p join users u on u.role_id = p.role_id
    where u.id = auth.uid() and p.module = p_module and p.action = p_action and p.granted = true);
  ```
  Used directly inside RLS policies (`employees` "emp gated write") and inside RPC bodies
  (`create_employee`, `update_employee`, `update_tenant_settings`, and — per the function-list scan —
  the large majority of the ~140 other business RPCs, not individually re-verified in this pass).
- Client: `PermissionGate(module, action)` widget (`employees_page.dart:78-86` is one call site) hides
  UI when a permission is absent — this is UX-only and does not, by itself, protect data; the server
  side above is what actually blocks unauthorized writes.

### 4.6 Branch scoping at runtime
- `auth_has_branch(p_branch_id)` (SQL, `SECURITY DEFINER`, `STABLE`):
  ```sql
  select p_branch_id is null or exists (select 1 from user_branch_assignments uba
    where uba.user_id = auth.uid() and uba.branch_id = p_branch_id);
  ```
  Called inside `create_employee`/`update_employee` and (per naming pattern) most branch-taking RPCs.
  RLS policies additionally gate `branches`/`devices` reads/writes on `tenant_id = auth_tenant_id()`,
  not on individual branch membership — branch-level restriction is enforced at the RPC layer via
  `auth_has_branch`, not at the RLS layer for most tables (only `devices`/`branches` were checked in
  RLS-policy detail; a full per-table RLS branch-scope audit was out of this pass's time budget).

---

## 5. Permission Model — as-built

- **Lives entirely in data** (`roles` + `permissions` tables), not an enum, not a client-side constant.
  Confirmed no `role_enum`/`permission_enum` type exists.
- **Full vocabulary observed** (module × action pairs seen across `handle_new_user()` inline inserts +
  the 7 `seed_*_perms_for_admin()` triggers): modules = `sales`, `inventory`, `customers`, `reports`,
  `settings`, `users`, `accounting`, `approvals`, `hr`, `notifications`, `purchase`, `repair`, `sync`.
  Actions = `read`, `create`, `update`, `delete`, `approve`, `export` (plus `sync` has only `read`,
  `resolve`). This list is what's **seeded for ADMIN today** — it is not necessarily the full universe
  of `module`/`action` strings checked across all ~140 RPCs (a full grep of every `auth_has_permission`
  call site across every RPC body was not performed in this pass).
- **Enforcement is real, at two layers**: RLS policy quals (`employees` table) and inside RPC bodies
  (`create_employee`, `update_employee`, `update_tenant_settings`, and by strong inference the rest of
  the business RPC surface, given the consistent `SECURITY DEFINER` + `auth_has_permission(...)` pattern
  seen in every function body actually opened). **Not cosmetic.**
- **Granularity is per-role, not per-user.** `permissions.role_id` is `NOT NULL`; there is no per-user
  override table. A "per-user permission" today can only be simulated by giving that user their **own**
  custom role (which `roles.tenant_id` + nullable-tenant design already supports — creating N roles per
  tenant is unconstrained).
- **`auth_role_name()`** is read live from the DB on every check (`select r.name from users u join
  roles r ... where u.id = auth.uid()`) — **not** cached in the JWT as a custom claim, and not read from
  a cache. Every permission check is a fresh query.
- **Role hierarchy**: `roles.hierarchy_level` (int, default 99) exists as a column, but no query,
  trigger, or RLS policy in this codebase was found to actually compare hierarchy levels (e.g. "can
  ADMIN create a role with a lower/equal hierarchy_level than itself?") — it looks like intended-but-
  unenforced metadata today (seed data uses 1 for ADMIN, 5 for CASHIER, 99 for the two hardcoded Demo
  Store roles).

---

## 6. Employees vs Users — as-built

- **Fully separate tables**, linked only by `employees.user_id` (nullable FK → `users.id`).
- **Nothing in the codebase reads `employees.user_id`** — grepped for its usage: only written (always
  `null` from the one form that creates employees, `employee_form_page.dart:158`); no query, RLS policy,
  or RPC was found joining through it to derive login/permission state for an employee. It is
  **decorative today** — an HR record and a login account are entirely independent concepts in the
  running app.
- `create_employee`/`update_employee` RPCs never call `supabase.auth.signUp` or insert into
  `public.users` — confirmed by both the SQL function bodies (Appendix B) and by the fact the only
  `auth.signUp` call site in the entire repo is `auth_remote_datasource.dart:20`.
- **Admin UI exists**: `employees_page.dart` (list, permission-gated FAB "Add" → `hr.create`),
  `employee_form_page.dart` (create/edit), `employee_profile_page.dart` (detail). Full HR module
  (attendance, leaves, payroll, salary advances, shifts) sits alongside it in `lib/features/hr/`. None
  of it provisions a login.

---

## 7. Security Findings

Ordered by severity. Both #1 is **pre-existing and independent of the target QR-invite feature**, but
directly relevant to it: shipping a feature that creates more non-ADMIN accounts increases the number of
people who can exploit it.

### 🔴 CRITICAL — Self role-escalation via `public.users` RLS
The only UPDATE policy on `public.users`:
```
policyname: "users update own", cmd: UPDATE, roles: {public},
qual: (auth.uid() = id), with_check: NULL
```
Per Postgres RLS semantics, an UPDATE policy without an explicit `WITH CHECK` reuses the `USING` clause
(`qual`) for the new row as well. There is **no column restriction** — a signed-in user can run:
```sql
update public.users set role_id = '<any-role-id-visible-to-them>' where id = auth.uid();
```
and it will pass RLS, because the *only* thing checked is that they're updating their own row (`id =
auth.uid()`), not what they're changing it to. The ADMIN role's `id` for their own tenant is directly
readable via the `"roles tenant read"` SELECT policy (`tenant_id = auth_tenant_id()`, no role-name
restriction on who may read it). No trigger exists on `public.users` to guard `role_id` (confirmed: the
only trigger touching users-adjacent state anywhere in the DB is `on_auth_user_created` on `auth.users`
itself). `information_schema.role_table_grants` confirms `authenticated` has raw `UPDATE` privilege on
`public.users` at the SQL level. **Full chain confirmed end-to-end from live RLS text + live grants +
absence of any guarding trigger** — this is not speculative. A CASHIER can self-promote to ADMIN in
their own tenant in one query.

### 🟠 MEDIUM — Anon-exploitable account lock/unlock
`increment_failed_login(p_email text)` and `reset_failed_login(p_email text)` are `SECURITY DEFINER`,
take a bare email string, have **no `auth.uid()` check and no rate limit** inside the function body, and
are EXECUTE-granted to `anon` (confirmed in `routine_privileges`). Anyone holding only the public anon
key can lock any account for 15 minutes (`increment_failed_login` 5×) or clear any account's lock state
(`reset_failed_login`) with zero proof of identity — a pre-auth availability/DoS vector on login.

### 🟡 LOW-MEDIUM — `provision_tenant()` has no ownership check
`provision_tenant(p_tenant_id uuid)` is `SECURITY DEFINER`, EXECUTE-granted to `PUBLIC` (which includes
`anon`), and only checks that the tenant UUID exists — no `auth_tenant_id()` match, no permission check.
All inserts inside it are idempotent (`WHERE NOT EXISTS`), which limits the blast radius to "silently
top up another tenant's baseline rows" rather than destructive overwrite, but it is a cross-tenant write
reachable pre-auth if a tenant UUID is known or guessed (UUIDs are not sequential/guessable in practice,
except the well-known Demo Store constant).

### 🟢 Informational — schema drift, `users.status`
`public.users.status` is `text DEFAULT 'ACTIVE'`, not cast to the `user_status_enum` type
(`ACTIVE`/`INACTIVE`/`SUSPENDED`/`LOCKED`) that exists in the database. Not a security issue, but means
nothing currently constrains this column to valid values at the DB layer.

### Tenant isolation — is it real or advisory?
**Real, and not client-supplied.** `auth_tenant_id()` is derived server-side, purely from `auth.uid()`
via a lookup against the caller's own `public.users` row (`select tenant_id from users where id =
auth.uid()`) — it is never read from a client parameter. A replayed/stolen JWT is bound to that JWT's
own user row; RLS policies across every relevant table (`branches`, `roles`, `permissions`, `employees`,
`tenants`, `devices`) consistently gate on `tenant_id = auth_tenant_id()`. **No table in the
staff/auth/tenancy cluster was found with RLS disabled.** (Two unrelated tables elsewhere in the schema
— `analytics_events_default` and `product_sku_sequences` — have RLS off; out of scope for this audit but
noted for completeness.)

### Pre-auth (anon) surface
`anon` has broad raw SQL-level table grants (`SELECT`/`INSERT`/`UPDATE`/`DELETE`) on nearly every table —
this is Supabase's default scaffold behavior, not a deliberate decision in this codebase. It is
**neutralized by RLS**: a direct query of every RLS policy in the schema with `'anon' = ANY(roles)`
returned **zero rows** — no policy anywhere grants `anon` access to any table. Table-level grants without
a matching RLS policy net out to zero access. Similarly, `anon` has EXECUTE on the vast majority of the
~180 public functions (again, Supabase default), but nearly all of them require `auth_tenant_id()`/
`auth.uid()` internally and simply raise `ERR_NO_TENANT` for an anonymous caller — the two exceptions
that actually work anonymously are the MEDIUM/LOW findings above. **No existing anon-callable RPC reads
a single row by an opaque bearer token** (the "does a password-reset-style pattern already exist"
question) — none was found anywhere in the ~180-function inventory.

---

## 8. Gap Analysis vs Target Flow

| Target capability | Status | Evidence | What blocks it |
|---|---|---|---|
| 2.1 Public signup creates ADMIN only | ⚠️ PARTIAL | `handle_new_user()` §4.1-4.2 | The Demo-Store/CASHIER fallback branch lives in the *same* function as the ADMIN path — can't disable one without editing the function that also runs the other. No "business_name required" validation exists client- or server-side. |
| 2.1 No public route self-provisions as cashier | ❌ MISSING | `handle_new_user()` else-branch | Every blank-business-name signup becomes a Demo Store CASHIER today — this is the literal opposite of the target. |
| 2.2 Admin/sub-admin creates staff in-app, generates QR invite bound to tenant/branch/role/permissions | ❌ MISSING | B10 search (roles/permissions/device_tokens = false positives only), full function inventory, router.dart grep | No invite table, no invite RPC, no invite UI screen exists. `qr_flutter` is proven working (MFA enrollment) but not wired to this. |
| 2.3 Scan-QR entry point on login/signup screen | ❌ MISSING | `router.dart` grep for "qr"/"invite"/"onboard" = no matches | No route, no screen. `mobile_scanner` is proven working (8 barcode screens) but none are pre-auth. |
| 2.3 First scan → self-service username/password setup, attaches to existing tenant, single-use, expiring | ❌ MISSING | Same as above + no anon-callable "read row by token" pattern exists anywhere (§7) | No pre-auth data-access mechanism exists in this codebase at all — this is the largest net-new surface the target flow requires. |
| 2.4 Session persists until explicit logout | ✅ EXISTS (as far as verified) | `main.dart:25-28`, package defaults | Exact JWT/refresh expiry not verified against Supabase Auth project settings (outside this pass's scope) — see §11. |
| 2.4 PIN is device re-lock for same user, not cashier-switch | ✅ EXISTS | `app.dart:28-42`, `pin_service.dart:24-28` | None — matches target description exactly. |
| 2.5 Admin creates SUB_ADMIN with à-la-carte permissions | ⚠️ PARTIAL | `roles`/`permissions` schema (§3, §5) | The **data model already supports this with zero schema changes** — insert a `roles` row with any name, insert selected `permissions` rows. The 7 `seed_*_perms_for_admin()` triggers only fire for `NEW.name = 'ADMIN'` exactly, so a SUB_ADMIN role starts with **zero** auto-granted permissions (good — no accidental over-grant) but also means **no UI exists** to build the "select which features" experience, and the CRITICAL finding in §7 must be closed first or a self-escalating SUB_ADMIN can make themselves ADMIN in one query. |

---

## 9. Database Impact Assessment

*(Named and justified per the task's instruction — not designed. No column shapes, no SQL proposed.)*

### 9.1 Tables likely needed
- **An invite/token table** — nothing today models "a pending invitation bound to tenant + branch(es) +
  role + permission set, single-use, expiring." Confirmed absent (§B10, full table list). This is the
  one clearly net-new table the target flow requires.

### 9.2 Tables/columns likely needing changes
- **`public.users` RLS policy `"users update own"`** — needs a `WITH CHECK` (or equivalent) that
  excludes `role_id`/`tenant_id` from self-service updates. This is a **fix**, not new functionality,
  but it is squarely in the blast path of "more non-ADMIN accounts get created" and should not ship
  after this feature without being addressed.
- **`handle_new_user()`** — the function that would need to grow a second branch: "metadata contains an
  invite token → join existing tenant" alongside the current two branches. Whether that belongs inside
  this same trigger function or a separate signup path is an open question (§10).
- Possibly `user_branch_assignments` — currently has **no INSERT/UPDATE RLS policy at all** (only a
  self-read policy was found); all writes today happen through `handle_new_user()`'s definer privileges.
  A QR-redemption flow that assigns a new user to one or more branches will need either a new definer
  RPC or an explicit RLS write policy here.

### 9.3 RLS policies likely needing changes
- `public.users` UPDATE policy (§9.2, §7 CRITICAL finding).
- Whatever new invite table is added will need its own RLS (near-certainly: no `anon` policy for
  reading the invite by token — that read should go through a `SECURITY DEFINER` RPC instead, following
  the same pattern `auth_has_permission`/`auth_tenant_id` already use, rather than opening a table
  directly to `anon`).

### 9.4 Triggers/functions likely needing changes
- `handle_new_user()` (§9.2).
- A new definer RPC analogous to `create_employee`/`register_device_token` for redeeming an invite
  (validate token → not expired/used → create `auth.users` via... **note**: `auth.signUp` is a
  client-SDK call, not something a Postgres function can invoke directly; the redemption flow's
  relationship to `auth.users` creation timing vs. token validation is an open design question, not
  something this read-only pass can resolve — see §10).
- The 7 `seed_*_perms_for_admin()` triggers are `ADMIN`-name-gated by design and would **not** need to
  change for SUB_ADMIN to work — confirmed they simply won't fire for any other role name, which is
  actually the desired "no accidental over-grant" behavior for à-la-carte permissions.

### 9.5 Data migration for existing rows
- **Demo Store cashiers**: 0 rows currently link `users.tenant_id = '00000000-0000-0000-0000-000000000001'`
  among the 2 live `users` rows (both existing users belong to real tenants, not Demo Store) — so as of
  this audit there is **no existing Demo Store user data** to migrate or worry about. This could change
  before a fix ships if anyone signs up with a blank business name in the meantime.
- **Existing ADMIN/CASHIER permission backfill**: not applicable — every tenant's roles already have
  permissions seeded by `handle_new_user()`/`provision_tenant()` at signup time; no retroactive backfill
  is needed for the two existing users.
- **0 `employees` rows exist** — no HR-record backfill needed either.

### 9.6 Risk: what could break for existing users
- Any change to `handle_new_user()` risks breaking signup for **both** paths simultaneously, since
  they're the same function — this needs careful testing of both branches, not just the new one.
- Fixing the `"users update own"` RLS policy (§7) must not break legitimate self-service profile edits
  (`full_name`, `phone`, `avatar_url`, etc.) — the fix needs to allow those columns while blocking
  `role_id`/`tenant_id`.
- The 2 existing live users and their sessions are unaffected by anything scoped to a *new* invite table
  or RPC, provided `handle_new_user()`'s existing two branches are left behavior-identical.

---

## 10. Open Questions & Decisions Needed

1. **Demo Store fallback**: remove entirely, or keep as an explicit opt-in ("try before you sign up")
   rather than a silent blank-field fallback? The target flow (§2.1) says the current behavior "must be
   removed or gated" but doesn't say which.
2. **Timing of `auth.users` creation during QR redemption**: does the invited person's `auth.users` row
   get created at invite-generation time (pre-provisioned, password set later) or at first-scan time
   (via `supabase.auth.signUp` client-side, same as today)? This materially changes whether
   `handle_new_user()` needs to branch on an invite token, or whether a wholly separate redemption RPC
   creates the `public.users`/`employees` link after a normal `signUp` call. Not something this
   read-only pass can resolve from evidence alone — it's a design decision.
3. **Invite token delivery**: the target flow assumes the QR encodes something bindable to a
   single-use, expiring invite — is the token itself the sole secret (bearer-token model, like a
   password-reset link), or does it require a second factor (e.g. the invitee must also know their own
   phone/email) before redemption completes? No existing pattern in this codebase answers this — see §7,
   "no anon-callable read-by-token RPC exists" — the security shape of the token is undecided.
4. **Invite expiry policy**: no default TTL convention exists elsewhere in this codebase to copy (no
   other single-use/expiring-token table exists to pattern-match against).
5. **Can sub-admins create staff**, or is inviting staff ADMIN-only? Target §2.2 says "an ADMIN (or
   permitted SUB_ADMIN)" — this implies a `staff.create`-style permission gating the *invite-generation*
   action itself, which is a new module/action pair not in today's seeded vocabulary (§5) and would need
   to be added to whatever à-la-carte permission list a SUB_ADMIN can be granted.
6. **What happens to the CRITICAL self-escalation bug (§7)** — fix it as a prerequisite, or bundle the
   fix into the same change that ships the invite feature? Given it's a pre-existing, independent bug,
   this is a sequencing decision, not a technical one.
7. **`roles.hierarchy_level`** is seeded (1/5/99) but never read anywhere — is it meant to eventually
   gate "can this role create/edit a role at this level or lower"? If SUB_ADMIN needs to be prevented
   from creating another ADMIN or editing its own permissions upward, this column (or new logic) will
   matter.

---

## 11. Assumptions & Uncertainties

- **No file-by-file drift check** was run between the 133 migration files and the live schema — this
  report trusts live schema exclusively, per the task's own instruction to prefer it, but if the two
  have diverged, a runbook based on this report should re-verify against migrations before writing SQL.
- **Supabase Auth project-level settings** (email-OTP requirement, JWT expiry, refresh-token rotation,
  rate limiting/CAPTCHA on `/auth/v1/signup`) were **not verified** — these live in the Supabase
  dashboard/Management API, not in application SQL or Dart code, and were out of reach for this pass.
  Section 4.4's "session persists until logout" and 4.1's "is signup rate-limited" claims are therefore
  based on Flutter-side defaults only, not confirmed server-side policy.
- **Not every one of the ~180 RPC bodies was individually opened** — the `auth_has_permission(...)`
  enforcement pattern was directly confirmed in `create_employee`, `update_employee`,
  `update_tenant_settings`, and inferred (not re-verified line-by-line) for the remainder based on
  consistent `SECURITY DEFINER` signatures and the `auth_has_permission`/`auth_tenant_id` helper design.
  A "full permission vocabulary" claim in §5 is therefore a lower bound (seeded-at-signup set), not
  necessarily the complete set every RPC checks for.
- **`user_branch_assignments` unique-constraint on `(user_id, branch_id)`** is inferred from the `on
  conflict (user_id, branch_id) do nothing` clause inside `handle_new_user()`, not independently
  confirmed via a direct constraint-name query in this pass.
- **Email-OTP confirmation step** (mentioned in §4.1 step 7) was inferred from a client-side redirect
  handling `EmailNotConfirmedFailure`, not confirmed against Supabase Auth's actual project
  configuration (email confirmations could be toggled off/on independently of this client code path).
- **Row counts** (§3, §9.5) are a snapshot as of this audit (2026-07-17) and will drift as the two live
  test users continue using the app.

---

## Appendix A — Raw SQL results

Full raw JSON output for every query below is saved (not pasted here to keep this report readable) at:
`/private/tmp/claude-501/-Users-ahmadraza-Developer-pos-app/c9d26738-b4ab-48d9-a5ea-82e84edf125e/scratchpad/`
- `b1_relevant_columns.json` — full column list for the 15 tables in the staff/auth/tenancy cluster
- `b2_fks.json` — all PK/FK/UNIQUE constraints for those tables
- `b3_enums.json` — all 40 enum types + values in `public`
- `b4_rls.json` — RLS enabled/forced flag for all 82 `public` tables
- `b5_core_policies.json` — full policy text (qual + with_check) for the 10 core tables
- `b6_triggers.json` — every trigger in `public` + `auth`
- `b7_funclist.json` — all ~180 function names/args/security-definer flags in `public`+`auth`
- `b7_fulldefs.json` — full `pg_get_functiondef()` source for the 21 functions directly relevant to
  onboarding/permissions (handle_new_user, provision_tenant, create_employee, update_employee,
  auth_has_permission, auth_role_name, auth_tenant_id, auth_has_branch, register_device_token,
  increment_failed_login, reset_failed_login, the 7 seed_*_perms_for_admin, verify_tenant_provisioning,
  verify_all_tenants_provisioning, update_tenant_settings)
- `func_grants.json` / `anon_table_grants.json` / `anon_policies.json` — EXECUTE/table grants to
  anon+authenticated, and confirmation that zero RLS policies grant anything to `anon`
- `roles_rows2.json` / `users_rows.json` / `tenants_rows.json` — live data snapshots (10 roles, 2 users,
  5 tenants)
- `b9_counts.json` — row counts for the 11 core tables
- `pt_grants.json` / `users_table_grants.json` — targeted grant checks for the CRITICAL/LOW findings

## Appendix B — Key code excerpts

All quoted verbatim in §4/§6/§7 above with file:line citations. Full directory maps for
`lib/features/auth/` and `lib/features/hr/` are in the investigation transcript this report was built
from (available on request — omitted here to keep this document to a reviewable length).
