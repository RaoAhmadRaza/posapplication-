# DECISIONS — Lumina POS

Append-only log. Oldest at top, newest at bottom.

---

2026-06-09 — Backend = Supabase (Postgres + Auth + Storage), not self-hosted Node/NestJS — solo dev, speed, Firebase background; the Pipeline's NestJS/Redis/Argon2id/BullMQ specs are superseded.

2026-06-09 — Auth = Supabase Auth owns credentials/sessions/JWT; public.users is a profile (id FK auth.users); NO password stored in public.users.

2026-06-09 — Signup provisioning via handle_new_user trigger: business_name → new tenant + ADMIN/CASHIER roles + Main branch + permission matrix + branch assignment; Demo Store (fixed UUIDs) = fallback.

2026-06-09 — Email verification via custom SMTP (Supabase gates template editing behind SMTP); OTP codes via `{{ .Token }}`; verifyOTP type signup/recovery.

2026-06-09 — go_router redirect is the SINGLE source of truth for auth navigation; never navigate manually after auth; RecoveryState forces /reset during recovery.

2026-06-09 — RLS = Supabase-style via auth_tenant_id()/auth_role_name(); NOT the schema doc's SET LOCAL app.current_tenant_id pattern.

2026-06-09 — UI = clean native iOS, light mode only, accent #007AFF; the claymorphic attempt was abandoned.

2026-06-09 — Schema version-controlled in supabase/migrations/ (0001 init, 0002 signup_provisioning) — previously lived only in the cloud.

2026-06-09 — Prefer dependency-free code for tiny visual effects (flutter_inset_box_shadow was abandoned, broke the build via removed hashValues()).

2026-06-09 — Desktop-only plugins (e.g. window_manager) MUST be platform-guarded in main() or mobile crashes at launch.

2026-06-09 — Flagged paid/server-side: SMS MFA (paid provider), remote session kill (Edge Function with service_role), suspicious-login/anomaly engine (later).

2026-06-09 — Removed dead code: AuthUser entity, EmailVO/PasswordVO, ResponsiveExtension+breakpoints. AppOtpField gained optional onChanged param; OTP _autoSubmitted flag resets on error and on field edit so retry works.

2026-06-09 — Phase 0.2 auth schema applied as migration 20260609000002_auth_full_schema.sql: extended tenants/roles/users; added branches, user_branch_assignments, permissions, devices, sessions, mfa_configs, audit_logs (audit_logs immutable — update/delete revoked from anon/authenticated); RLS helpers auth_tenant_id()/auth_role_name() + RLS policies on all new tables; seeded Demo Store permission matrix (ADMIN full = 36, CASHIER = 6) + Main Branch (BR01) + branch assignments for existing users.

2026-06-09 — handle_new_user fallback role corrected ADMIN→CASHIER: non-business signups provision into Demo Store as CASHIER (role …012), matching the locked provisioning rule; business_name signups still get their own tenant as ADMIN. (Runbook draft assigned Demo ADMIN in the fallback branch — fixed before applying.)

2026-06-09 — Dynamic RBAC permission layer: Permission entity + loadPermissions datasource/repo/use case; permissionMatrixProvider (AsyncValue<Set<String>> with "module:action" keys for granted==true); canProvider (Provider.family) + PermissionController.can(); permissionsReadyProvider; AuthProfile gained roleId from existing profile query; matrix loaded in HomePage bootstrap after profile resolves.

2026-06-09 — Forgot-password flow hardened: RecoveryState bool → RecoveryStage enum (none/awaitingCode/codeVerified); forgot page validates email + waits for success before nav + sets awaitingCode; OTP controller no longer clears recovery stage on failure (stays on /otp with banner); otp_page surfaces empty-code hint + resend success; reset page validates min 8 chars + confirm-match before API call, stays on /reset on error; reset controller only clears to none on success; new AuthFailures: InvalidOtpFailure, PasswordMismatchFailure, RecoverySessionExpiredFailure; _mapError refined to distinguish wrong-code vs expired-code; resend cooldown starts only after success.

2026-06-09 — PermissionGate widget (lib/core/widgets/permission_gate.dart): ConsumerWidget watching permissionMatrixProvider, renders child if "module:action" granted, fallback otherwise (default SizedBox.shrink).

2026-06-09 — Branch support: Branch entity (id/name/code/isMain/isDefault); loadUserBranches(userId) datasource/repo/use case; userBranchesProvider (AsyncValue<List<Branch>>) + currentBranchProvider (NotifierProvider<Branch?>); branch selection persisted in flutter_secure_storage; hydrated on app start after profile resolves in home page; branchesReadyProvider.

2026-06-09 — Branch select screen + routing: /branch-select route listing branches as tappable AppCards; BranchRouterState ChangeNotifier signals needsSelection to the router; single-branch users auto-select and skip to /home; multi-branch redirect to /branch-select after login; tapping a branch persists choice and navigates to /home; redirect priority: codeVerified > awaitingCode/otp > !loggedIn > needsSelection > loggedIn.

2026-06-09 — Entry screens: /env-check (EnvironmentCheckScreen) runs internet + session checks, shows pending/ok/fail rows, auto-continues on pass; /workspace-init (WorkspaceInitScreen) triggers profile + permission + branch loading, shows "Setting up" spinner, auto-goes to /home when ready. Both wired as ChangeNotifier-driven router steps (EnvCheckState, WorkspaceInitState). Profile/permission/branch loading moved from HomePage to WorkspaceInitScreen.

2026-06-09 — PIN quick-login: PinService (sha256 + random salt, flutter_secure_storage + Supabase users.pin_hash sync); PinPad widget (0-9 grid, delete, dot dots, haptic feedback); PinSetupScreen (set + confirm 4-digit PIN); PinLockScreen (verify to unlock, 3 failed attempts clears PIN → /login); app-lock on resume via WidgetsBindingObserver in App; PinLockState ChangeNotifier for router redirect (pin_locked > loggedIn).

2026-06-09 — Biometric unlock: PinLockScreen shows "Use Face ID / fingerprint" button via local_auth when device supports biometrics + user enabled it in HomePage Security card; toggle persisted via PinService.isBiometricsEnabled/isBiometricsEnabled in secure storage; authenticate() on success unlocks without PIN.

2026-06-09 — Device registration: DeviceService gathers device name/model/OS via device_info_plus, builds sha256 fingerprint from model+OS+per-install UUID (stored in secure storage), upserts into public.devices (tenant_id, user_id, device_name, device_model, os_info, fingerprint_hash, last_seen_at) on workspace init after profile loads; AuthProfile gained tenantId from existing profile query.

2026-06-09 — Device management screen (/devices): admin-gated via PermissionGate(module:'settings', action:'update'); lists all tenant devices with trust badges (TRUSTED/REVOKED/PENDING) and OS-aware icons; ADMIN can Approve (authorized=true, trust_level=TRUSTED) or Revoke (REVOKED) each device; datasource methods loadDevices/approveDevice/revokeDevice; DevicesController with refresh after mutation.

2026-06-09 — TOTP MFA: MfaService wraps Supabase built-in MFA API (enroll/challenge/verify/unenroll, needsAal2 via getAuthenticatorAssuranceLevel, getEnrolledFactorId via listFactors). /mfa-enroll shows QR (qr_flutter) + secret + code entry. /mfa-challenge auto-challenges + verifies when currentLevel=1 and nextLevel=2. MfaState ChangeNotifier signals needsMfa to router (workspace-init → needsAal2 → /mfa-challenge → verify → home). HomePage Security card shows authenticator setup/status button. upserts public.mfa_configs on enroll/unenroll.

2026-06-11 — Home Security & Admin section: Replaced conditional _SecurityCard with always-visible _SecuritySection (AppCard with rows). PIN, biometric toggle, and authenticator rows visible to all roles. Admin rows (devices/sessions/security-logs) gated by PermissionGate. MFA-enroll always surfaced (fixes catch-22 where MFA button was hidden unless MFA already active). Layout: scrollable content between fixed header and logout button. Stable loading placeholder replaces flickering SizedBox.shrink().

2026-06-11 — Clean architecture for Devices: DeviceRepository (abstract) + DeviceRepositoryImpl → LoadDevices / ApproveDevice / RevokeDevice use cases → DevicesController. Controller no longer calls datasource directly. Datasource methods kept in auth_remote_datasource.

2026-06-11 — Clean architecture for Sessions: SessionRemoteDataSource (Edge Function wrapper) → SessionRepository + impl → ListSessions / RevokeSession use cases → SessionsController → ConsumerStatefulWidget screen. Supabase function calls moved out of UI layer.

2026-06-11 — Clean architecture for Security Logs: loadAuditLogs added to auth_remote_datasource → AuditLogRepository + impl → LoadAuditLogs use case → SecurityLogsController → ConsumerStatefulWidget screen.

2026-06-11 — Router-driven navigation cleanup: Removed manual context.go() after state changes in MfaChallengeScreen (clear MfaState), PinLockScreen (unlock PinLockState), BranchSelectPage (selectBranch). Redirect now handles all post-state-change navigation. PinSetupScreen keeps explicit nav (no redirect gate covers /pin-setup).

2026-06-11 — Minor correctness + docs: Profile double-load removed (_ProfileCard reads existing state). Audit service gains debugPrint + one retry. Orphaned authStateProvider + watch_auth_state use case deleted. AUTH_COMPLETE_RUNBOOK.md created. PROJECT_STATE.md fully reconciled.

2026-06-11 — Migration reconciliation: missing local file `20260611000000_failed_login_rpc.sql` recovered from remote DB via `supabase db query --linked`; local and remote migration lists now aligned.
2026-06-11 — Taxonomy management UI: categories + brands screens under lib/features/inventory/presentation/; list screens use plain Scaffold (not ResponsiveFormScaffold) to avoid infinite-width ListView crash; forms use Scaffold+AppBar+SingleChildScrollView; PermissionGate(module:'inventory') gates create/edit/delete; DuplicateSkuFailure surfaced as name-collision message in taxonomy forms.
2026-06-11 — Detail-screen nav fix: Settings rows use context.push (not context.go) for pin-setup, mfa-enroll, devices, sessions, security-logs. Sub-screens use Scaffold+AppBar with back button, not ResponsiveFormScaffold (avoids infinite-width ListView crash). Empty-state distinction: neutral empty state (muted icon + text) vs red error banner. /pin-setup removed from waitingRoutes so push isn't yanked. MFA enroll surfaces real error via debugPrint.

2026-06-11 — AppButton default fullWidth changed true→false (opt-in): stops infinite-width crash when placed inside Row/list items; form buttons in stretch-CrossAxisAlignment or ResponsiveFormScaffold remain full-width via parent layout; explicit fullWidth:true added to login/category-form/brand-form CTA buttons.

2026-06-11 — Products list with search + filters: ProductsController (Notifier loading/search), ProductsPage (plain Scaffold, AppTextField with controller-listener debounce 300ms, category/status filter chips via modal bottom sheets, product AppCards with name/sku/barcode/price/status chip), /inventory/products route + stub create/detail routes, inventory tab updated to link to products.

2026-06-11 — Product create/edit form: ProductEditController (Notifier with sub-resource state), ProductFormPage (core fields + collapsible sub-sections for variants/images/pricing via dialogs), routes /inventory/products/create and /inventory/products/:productId replacing stubs; sub-sections disabled until first core save; nested lists use Column of cards not ListView.
Inventory Slice A (Product Catalog) complete: full §3.4 schema + clean-arch inventory feature + Inventory tab; gated by inventory:* matrix; search via search_vector. Next: Slice B stock engine (warehouses, stock_balance, immutable stock_ledger).
2026-06-11 — Four inventory fixes: (1) product form dropdowns now watch AsyncValue for categories/brands; (2) delete controllers capture and surface (bool,failure) instead of swallowing errors; (3) SKU switched to system-generated via DB trigger (PRD-000001), removed from UI; (4) product search replaced FTS+ilike-or with trigram-accelerated ILIKE substring matching (pg_trgm GIN indexes + single .or() query).
2026-06-12 — Soft-delete moved to SECURITY DEFINER RPCs (soft_delete_brand/category/product) enforcing tenant + inventory:delete; duplicate catalog UPDATE policies collapsed to one per table; the earlier "client-side session loss" diagnosis was incorrect — the JWT was always valid, the fix required collapsing duplicate policies and bypassing the WITH CHECK via owner-privileged RPCs.

2026-06-13 — Stock Engine (Slice B) complete. Architecture: stock_balance is a trigger-maintained materialized projection of the immutable append-only stock_ledger (trg_apply_stock_ledger AFTER INSERT on stock_ledger). All stock writes go through the single post_stock_movement SECURITY DEFINER RPC — clients NEVER insert/update stock_balance or stock_ledger directly (RLS revokes insert/update/delete on both tables from anon+authenticated). Negative stock is blocked in fn_apply_stock_ledger (P0001 'insufficient stock'). Weighted-avg cost computed in the same trigger. Stock_ledger immutability enforced by trg_stock_ledger_immutable (raises P0001 on any UPDATE/DELETE). Branch isolation via auth_has_branch() helper. Warehouse scope via nullable warehouse_id on stock_balance; default warehouse per branch with uq_warehouses_one_default_per_branch partial index. Spec-gap fixes: chk qty_on_hand >= 0 added (negative BLOCKED, not allowed); warehouse seeding via ensure_default_warehouse RPC + seed INSERT; stock_ledger shipped non-partitioned (partitioning deferred to performance milestone). Supabase RLS (auth_tenant_id/auth_has_branch/auth_has_permission) supersedes the schema doc's SET LOCAL app.current_tenant_id pattern. Flutter data layer mirrors exact DB column names from migration 20260613061924_stock_engine.sql; all RPC results parsed as single-row Map (not List) — post_stock_movement and ensure_default_warehouse return single record types. Opening-balance form computes client-side delta = target - current_on_hand and hardcodes operation_type=OPENING_BALANCE, reference_type='OPENING'. Products list invalidation moved to controller saveProduct for reliability. Edit-product form seeding fixed: replaced didChangeDependencies with reactive ref.listen(productEditProvider) + _didSeed guard. Remaining stock operations (transfers, adjustments, counts, IMEI, scrap, valuation) deferred to Slice C.
