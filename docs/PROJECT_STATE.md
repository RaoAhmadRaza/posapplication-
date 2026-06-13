# PROJECT STATE — Lumina POS

Last updated: 2026-06-11

## Stack & Architecture

Flutter + Supabase (Postgres + Auth + Storage). Clean architecture with plain Riverpod
(no codegen, no build_runner) and go_router. Dependency chain:

```
page → controller (Notifier<AsyncValue<T>>) → use case (Provider) → repository (abstract)
→ repository impl → remote datasource → supabase
```

Domain has entities + value objects + abstract repo + thin use cases (one call each).
Data has a single remote datasource holding all Supabase calls + repository impl that
maps AuthException → sealed AuthFailure. Presentation uses ConsumerStatefulWidgets
wired to controllers; no UI in controllers.

## Project Structure

```
lib/
  main.dart                  # Supabase.init + window_manager (desktop-guarded) + ProviderScope
  app.dart                   # MaterialApp.router(theme: AppTheme.light, themeMode: light)
  router.dart                # 33 routes, auth redirect, StatefulShellRoute bottom nav
  core/
    env.dart / supabase.dart  # Supabase URL + key; global client singleton
    error/auth_failure.dart   # 14 sealed AuthFailures + RecoveryState + RecoveryStage
    state/
      app_flow_state.dart     # EnvCheckState + WorkspaceInitState ChangeNotifiers
    services/
      pin_service.dart        # sha256 PIN hash + secure storage + Supabase sync
    design/
      app_colors.dart         # accent #007AFF, background #FFF, fieldFill #F2F2F7, etc.
      app_radius.dart         # field/button=12, card=14, chip=12
      app_shadows.dart        # single card shadow (black 5%)
      app_spacing.dart        # xs(4)..xxxl(40), screenPadding=24, fieldGap=18
      app_typography.dart     # largeTitle(34/bold)..caption(12) + field/label/hint/error
      app_theme.dart          # light ThemeData, accent seed, 12px input fields
      app_motion.dart         # fast/base/slow + easeOutCubic curve
      widgets/
        app_button.dart       # filled/tinted/plain/destructive, loading, icon
        app_text_field.dart   # label + icon + focus border + obscure toggle
        app_card.dart         # white card, separator border, subtle shadow
        app_otp_field.dart    # 6-digit pinput, themed pins
        app_inline_banner.dart # error/success/info tinted banner
        responsive_form_scaffold.dart # SafeArea + centered scrollable form
        bottom_nav_shell.dart # StatefulShellRoute widget, 4-tab bottom NavigationBar
    services/
      pin_service.dart        # sha256 PIN hash + secure storage + Supabase sync
      device_service.dart     # device fingerprint (UUID + model + OS) + upsert
      mfa_service.dart        # TOTP enroll/challenge/verify via Supabase MFA API
      audit_service.dart      # audit_logs insert with debugPrint + retry
      login_throttle_service.dart # local secure-storage brute-force throttle + server RPC
    widgets/
      permission_gate.dart    # ConsumerWidget gating by "module:action"
      pin_pad.dart            # 0-9 grid + delete, dots, haptic
  features/auth/
    domain/
      entities/     auth_profile.dart (incl. roleId, tenantId), permission.dart, branch.dart,
                    device.dart
      value_objects/ (empty — contents deleted as dead code)
      repositories/ auth_repository.dart (abstract) + SignUpResult, SignInResult,
                    device_repository.dart (abstract), session_repository.dart (abstract),
                    audit_log_repository.dart (abstract)
      usecases/     17 files: sign_in/up/out, verify_email/recovery_otp,
                    request/set_password, resend_code, load_profile,
                    load_permissions, load_user_branches, load_devices, approve_device,
                    revoke_device, list_sessions, revoke_session, load_audit_logs
    data/
      datasources/  auth_remote_datasource.dart (profile/perms/branches/devices/audit_logs),
                    session_remote_datasource.dart (Edge Function calls)
      models/       auth_profile_model.dart (fromJson)
      repositories/ auth_repository_impl.dart, device_repository_impl.dart,
                    session_repository_impl.dart, audit_log_repository_impl.dart
    presentation/
      controllers/  12 controllers: auth, sign_in/up, otp, forgot, reset, profile,
                    permission, branch, devices, sessions, security_logs
      pages/        21 pages: splash, env-check, login, signup, otp, forgot, reset,
                    branch-select, workspace-init, pin-lock, pin-setup, devices,
                    sessions, security-logs, mfa-challenge, mfa-enroll,
                    dashboard, inventory, sale, settings, home (→ /dashboard redirect)
  features/inventory/
    domain/       entities (7), failures (sealed InventoryFailure), repository (abstract 36 methods),
                  usecases (23: Load/Save/Delete for all resources + Search, SetPrimaryImage)
    data/         datasource (all Supabase + RPC calls), models (7 fromJson/toJson),
                  repository impl (PostgrestException → InventoryFailure)
    presentation/ controllers (4 AsyncNotifiers), pages (9: hub, CRUD forms, product editor,
                  barcode templates)
```

## Auth Status — All Flows Working End to End

All flows (signup ± OTP, login, forgot-password→OTP→reset, logout, session persistence) use
go_router redirect — no manual post-auth context.go(). Recovery via two-stage RecoveryStage enum
(codeVerified → /reset forced; awaitingCode → /otp). Redirect priority: codeVerified >
awaitingCode > !loggedIn > loggedIn.

### Router (33 routes, single _redirect, StatefulShellRoute bottom nav)

Pre-auth / gated routes (full-screen, no bottom bar):

| Route | Page | Guard |
|-------|------|-------|
| /splash | SplashPage | waitingRoutes → /dashboard |
| /env-check | EnvironmentCheckScreen | Sticky if !EnvCheckState.passed |
| /login | LoginPage | authRoutes — allowed when logged out |
| /signup | SignupPage | authRoutes — allowed when logged out |
| /otp | OtpPage(email, isRecovery) | authRoutes + sticky awaitingCode |
| /forgot | ForgotPasswordPage | authRoutes — allowed when logged out |
| /reset | ResetPasswordPage | Sticky if codeVerified |
| /branch-select | BranchSelectPage | Sticky if needsSelection |
| /workspace-init | WorkspaceInitScreen | Sticky if !completed && !needsMfa |
| /pin-lock | PinLockScreen | Sticky if PinLockState.locked |
| /pin-setup | PinSetupScreen | N/A (pushed from Settings; not in waitingRoutes) |
| /devices | DevicesScreen | Authenticated + PermissionGate |
| /security-logs | SecurityLogsScreen | Authenticated + PermissionGate |
| /sessions | SessionsScreen | Authenticated + PermissionGate |
| /mfa-challenge | MfaChallengeScreen | Sticky if MfaState.needsMfa |
| /mfa-enroll | MfaEnrollScreen | Authenticated |
| /home | — (redirect) | → /dashboard |
| /inventory/categories | CategoriesPage | Authenticated |
| /inventory/categories/create | CategoryFormPage | Authenticated + inventory:create |
| /inventory/categories/:categoryId | CategoryFormPage | Authenticated |
| /inventory/brands | BrandsPage | Authenticated |
| /inventory/brands/create | BrandFormPage | Authenticated + inventory:create |
| /inventory/brands/:brandId | BrandFormPage | Authenticated |
| /inventory/products | ProductsPage — search + category/status filters | Authenticated |
| /inventory/products/create | ProductFormPage — core fields + variants/images/pricing | Authenticated + inventory:create |
| /inventory/products/:productId | ProductFormPage(productId:) — edit mode | Authenticated |
| /inventory/barcode-templates | BarcodeTemplatesPage | Authenticated |
| /inventory/barcode-templates/create | BarcodeTemplateFormPage | Authenticated + inventory:create |
| /inventory/barcode-templates/:templateId | BarcodeTemplateFormPage | Authenticated |

Shell branches (persistent bottom nav, only when authenticated + all gates passed):

| Branch | Path | Page |
|--------|------|------|
| Dashboard | /dashboard | DashboardPage — greeting + profile summary + placeholder |
| Inventory | /inventory | InventoryHubPage — product/category/brand/barcode entry rows + stubs |
| Sale | /sale | SalePage — "Coming soon" stub |
| Settings | /settings | SettingsPage — account profile, security rows, admin rows, logout |

Redirect priority: codeVerified > awaitingCode > env_check > !loggedIn > pin_locked >
needsSelection > workspace_init > needsMfa > waitingRoutes → /dashboard > proceed.

## Design System

Clean iOS, light mode only. Accent `#007AFF`. System grays, hairline separators, 12px
radii, subtle card shadow. No gradients, no neumorphism, no smooth_corner — that approach
was abandoned. Design tokens in `core/design/`. Reusable widgets: AppButton (4 variants),
AppTextField, AppCard, AppOtpField, AppInlineBanner, ResponsiveFormScaffold.

## Database

Schema version-controlled in `supabase/migrations/` (previously cloud-only):

| Migration | Contents |
|-----------|----------|
| `20260609000000_init.sql` | `public.tenants`, `public.roles`, `public.users` (PK FK → auth.users cascade); Demo Store + ADMIN/CASHIER seed; `handle_new_user()` trigger v1 (always Demo Store/CASHIER); RLS on all 3 tables |
| `20260609000001_signup_provisioning.sql` | Replaces trigger: if `business_name` meta → create tenant + ADMIN/CASHIER roles → assign ADMIN; else fallback Demo Store/CASHIER |
| `20260609000002_auth_full_schema.sql` | Extends `tenants`/`roles`/`users`; adds `branches`, `user_branch_assignments`, `permissions`, `devices`, `sessions`, `mfa_configs`, immutable `audit_logs`; `auth_tenant_id()`/`auth_role_name()` RLS helpers + RLS on new tables; seeds Demo Store permission matrix (ADMIN 36 / CASHIER 6) + Main Branch (BR01) + assignments; upgrades `handle_new_user()` to full provisioning (business → new tenant as ADMIN + branch + matrix; fallback → Demo Store CASHIER) |
| `20260611000000_failed_login_rpc.sql` | SECURITY DEFINER functions `increment_failed_login(p_email)` and `reset_failed_login(p_email)` on `public.users`; increments counter, sets `locked_until = now() + 15min` at count >= 5; server-side brute-force lockout complementing local secure-storage throttle |
| `20260611000001_product_catalog.sql` | Product catalog: enums, tables (categories, brands, products, variants, images, pricing, barcode templates), indexes, RLS, triggers |
| `20260611163739_product_sku_and_search.sql` | pg_trgm + GIN trigram indexes; SKU auto-gen via `next_product_sku()` + BEFORE INSERT trigger; `search_products()` RPC for ILIKE substring search |

RLS uses `auth.uid()` via helper functions `auth_tenant_id()`/`auth_role_name()` in the
live project (the migration policy bodies use inline `auth.uid()` as the shipped version).

See DATABASE_SCHEMA.md for full schema reference.

## RBAC — Dynamic Permission Layer

Permission matrix loaded after profile: `permissionMatrixProvider` (AsyncValue<Set<String>> of
"module:action" keys for granted==true). Exposed via `canProvider` family + `PermissionController.can()`.
PermissionGate widget gates UI by `module:action`. Branch support: Branch entity, selectBranch, single/
multi-branch auto-select. PIN quick-login: PinService (sha256+secure storage+Supabase), PinPad, PinLock
(biometric via local_auth). MFA (TOTP): MfaService wraps Supabase MFA API (enroll/challenge/verify),
MfaState drives router. Bottom nav: StatefulShellRoute 4-tab NavigationBar; detail screens push above.

## Inventory — Product Catalog (Slice A) — COMPLETE

Full §3.4 catalog schema (categories, brands, products, product_variants, product_images,
product_pricing_tiers, barcode_templates) + pg_trgm trigram indexes + SKU auto-gen trigger.
Clean-architecture inventory feature under `lib/features/inventory/`. Inventory hub in shell;
detail screens push full-screen. Search via PostgreSQL trigram-accelerated ILIKE. Permission-
gated by `inventory:*` matrix (ADMIN full CRUD; CASHIER read-only). Soft-deletes use SECURITY
DEFINER RPCs (soft_delete_brand/category/product) enforcing tenant + inventory:delete inline;
duplicate UPDATE policies collapsed to one per table. No open bugs. Next: Slice B stock engine
(warehouses, stock_balance, immutable stock_ledger).

## Known Issues / Dead Code

**Dead code (defined, zero callers):**
- `ServerErrorFailure` — defined but never instantiated
- `cupertino_icons` package — in pubspec but no Cupertino widget/icon imported

**Minor:**
- `RecoveryState` lives in `core/error/auth_failure.dart` — semantically not a failure; works but misplaced
- `widget_test.dart` — smoke test, ProviderScope-wrapped; no test infrastructure beyond this
- Profile loaded once on mount (no pull-to-refresh)

## What's Next

Slice A (Product Catalog) complete with zero open bugs: taxonomy CRUD, products with search/
filters, product editor with variants/images/pricing, barcode templates, soft-delete via RPCs.
Next: Slice B stock engine (warehouses, stock_balance, immutable stock_ledger, transfers,
counts, IMEI tracking).
immutable stock_ledger, transfers, counts, IMEI).
