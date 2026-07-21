# PROJECT STATE — Lumina POS

Last updated: 2026-07-21

## Stack & Architecture

Flutter + Supabase (Postgres + Auth + Storage). Clean architecture with plain Riverpod
(no codegen, no build_runner) and go_router. Dependency chain:

```
page → controller (Notifier<AsyncValue<T>>) → use case (Provider) → repository (abstract)
→ repository impl → remote datasource → supabase
```

## Project Structure

```
lib/
  main.dart app.dart router.dart
  core/design/  (tokens + theme + shared widgets)
  core/services/ (pin, device, mfa, audit, login_throttle, scanner_support)
  core/widgets/  (bottom_nav_shell, pin_pad, permission_gate, barcode_scan_page)
  features/auth/ (21 pages, 12 controllers)
  features/inventory/ (catalog + stock-engine + stock-ops + barcode + labels)
  features/notifications/ (entities, model, datasource, repo, controller, page)
  features/sales/ (data + domain + controllers + 7 pages + receipt service)
    domain/entities/  7  domain/failures/  sealed SalesFailure  domain/usecases/  7
    data/models/  6  data/datasources/  1  data/repositories/  1  data/services/  1 (receipt PDF)
    presentation/controllers/  4  presentation/pages/  7 (open/close session, POS terminal, payment, success, receipt)
  features/dashboard/ (data + domain + controller)
  features/{purchasing,suppliers,customers,accounting,repair,hr}/ (full clean-arch per feature)
```

## UI Redesign — LUMINA design system (IN PROGRESS, started 2026-07-20)
Reskinning the app to the Claude-Design "LUMINA" system (source zip: React/TS + tokens.css, kept in
scratchpad — reference only, NOT importable). Frontend-only; backend/routing/controllers untouched
(see CLAUDE.md "Frontend/UI-only tasks" guardrail). Now LIGHT + DARK ("Counter mode") via a toggle.
- **L1 foundation — DONE.** 3 brand fonts bundled (Clash Display, Satoshi, JetBrains Mono in
  assets/fonts/ + pubspec). lib/core/design tokens remapped to Lumina: AppColors (light statics, new
  accent #2C6BFF) + `LumColors` ThemeExtension (full light+dark) read via `context.lum`; AppTypography
  (3 families, 8-pt scale); AppRadius (sm12/md16/lg22/xl28); clay.dart = ClayContainer CustomPainter
  (TRUE inset shadows — Flutter has none natively). ThemeController (ValueNotifier<ThemeMode>) + app.dart
  wires theme+darkTheme+toggle. 6 shared widgets reskinned (AppButton clay-lumen, AppTextField inset
  well + focus ring, AppCard clay, AppOtpField, AppInlineBanner, ResponsiveFormScaffold) — APIs
  UNCHANGED so all 12+ features still compile. Every auth screen inherits the brand automatically.
- **L2 primitives — DONE.** LuminaGlyph (flutter_svg, assets/images/lumina-glyph*.svg), LuminaWordmark,
  AppCheckbox (clay), AuthHeroScaffold (responsive: two-column ink Prism hero ≥900px / stacked mobile).
- **L2 Login — DONE + verified** (compiles, runs clean on macOS, no exceptions). Bespoke card, hero,
  remember-me (decorative), Use-PIN / forgot / QR-join / create-account links; all controller/throttle/
  nav wiring identical to before.
- **L2 all 17 auth screens — DONE** (login, signup, otp, forgot, reset, branch-select, workspace-init,
  pin-lock, pin-setup, mfa-challenge, mfa-enroll, devices, security-logs, sessions, settings,
  environment-check, splash). Card-form screens use AuthHeroScaffold + AuthFormCard; gate screens use
  clay cards/keypads; list screens (devices/sessions/security-logs) use AppCard clay rows with
  mono timestamps + status pills; settings gained a Dark-mode toggle (ThemeController); splash is the
  ink Prism hero. All theme-aware via context.lum (light + dark), all controller/provider/nav wiring
  byte-identical. Shared PinPad also made theme-aware. Login field focus = soft accent glow (fixed
  hard-ring). 12 screens reskinned in parallel via subagents, each flutter-analyze clean.
- Font on iOS: bumped ios deploy target 13→14 (file_picker req) + fresh Pods (cleared file_picker
  module-clash). New deps: flutter_svg (logo). GATE: full `flutter analyze` = 13 pre-existing infos,
  0 new across all 17 screens + shared widgets. VERIFY OWED: on-device visual eyeball of the post-auth
  screens (agent env can't screenshot; Login already eyeballed OK on iOS sim).

## UI Redesign — dashboard + nav (DONE 2026-07-21; detail in DECISIONS)
Second design export, SAME design-system UUID as the auth zip → tokens/theme/clay reused UNCHANGED; pure
consumer-side reskin per docs/UI_REDESIGN_PLAYBOOK.md. No router/domain/data/supabase edits; every
controller/provider binding byte-identical.
- **Nav now responsive** (bottom_nav_shell.dart is core/widgets = user-approved exception; path/class/ctor
  identical so router.dart untouched). ≥900px = 244px left rail (wordmark, clay-soft active item, Settings
  below a hairline, user block); <900px = bottom bar with the accentSoft pill behind the active icon.
  branchMap/goBranch/permission gating lifted VERBATIM. Theme-aware + Semantics/44dp.
- **Dashboard** 772-line page → ~260-line root + 10 widgets in presentation/widgets/. Bespoke app bar
  (edit + spinning refresh + bell + sync pill, no search — dead control, deliberately omitted). Two real
  bugs fixed: KPI grid is a GridView at **5 cols wide / 2 narrow** (was hardcoded 2-up = 2 giant desktop
  tiles), and dashboard+nav moved off light-only AppColors → **dark mode now works**. Edit mode moved inline
  onto each tile. Drilldown page reskinned (RESULTS meta, clay card, inbox/cloud-off states).
- Charts: sales trend HAND-ROLLED (gloss on latest bar, 55ms staggered entrance); donut KEEPS fl_chart.
  Both respect OS reduce-motion.
- **Deltas are honest**: DashboardSummary has no comparison fields, so only today_sales shows a real delta
  (derived from salesTrend last-vs-prev); the other 9 show static sub-labels. Nothing fabricated.
- New: app_pill.dart, app_money_text.dart; format.dart += formatAmount/displayCurrency (formatPkr delegates,
  output identical). NotificationBell + SyncStatusWidget restyled, logic untouched — sync pill now also on
  the dashboard header, so drain-on-reconnect can fire there (accepted). New dep: lucide_icons_flutter
  ^3.1.15 (31 symbols pre-verified, zero transitive deps).
- GATE: analyze 13 pre-existing/0 new; macOS builds + boots clean (WORKSPACE-STATE completed=true, no render
  exceptions); flutter test = same 2 failures as clean HEAD (proven in a HEAD worktree), NOT from this work.
- **Parity pass after user screenshot review (2026-07-21):** 4 real bugs found by comparing the running app
  against the reference renders. (1) Avatars (welcome card + rail) rendered as shadow-only — `ClayVariant.lumen`
  paints NO fill of its own and I passed no colour; `AppButton` was the existing correct precedent
  (`color: lum.accent`). (2) KPI tiles had dead space below the content — guessed `childAspectRatio` replaced
  with a LayoutBuilder that derives the ratio from real cell width against a content-height constant. (3) The
  donut was MISSING entirely: both chart cards were conditionally dropped when their data was empty, and
  `payment_breakdown` is scoped to TODAY in the RPC (`dashboard_summary.sql`), so a day with no sales removed
  the card. Both charts now always render with an in-card empty state. (4) Bar value labels floated at the top
  of the chart area instead of sitting on the bar. Also added `gradient` to ClayContainer (additive, painter
  now takes a shader) so tiles/welcome card get the design's surface→g50 wash.
- **Global search — LIVE** (`lib/features/search/`, user asked for it wired, not decorative). Header field
  (wide only) drops a results overlay: products + customers + invoices, each section gated client-side via
  `canProvider` because read RLS on those tables is tenant-only, not permission-checked. Built as a
  presentation-level aggregator over the modules' EXISTING use cases — no new datasource, no migration. Only
  backend-ish change: an optional `search` param threaded through loadInvoices datasource→repo→usecase
  (`.ilike('invoice_number', ...)`); every existing caller is unaffected. ⌘K / Ctrl+K wired in BottomNavShell
  via CallbackShortcuts (first keyboard shortcut in the app) targeting a GlobalKey on the field; 300ms debounce
  matching the app's existing idiom; 2-char minimum; 5 hits per section.
- **VERIFY OWED (on-device eyeball)** — agent env still cannot screenshot: 900px nav boundary, 5/2-col grid,
  dark mode, edit persistence across restart, 6 drilldown kinds, permission-gated nav variants, and the search
  overlay (typing, ⌘K focus, Esc dismiss, result deep-links).
- Pre-existing bug seen in run log, untouched: LoginThrottleService.reset still throws -34018 from
  FlutterSecureStorage.delete on macOS despite the MacOsOptions fix. Needs its own slice.

## UI Redesign — sales module (DONE 2026-07-21; detail in DECISIONS)
Third design export, SAME design-system UUID again → tokens/theme/clay untouched; consumer-side reskin
of all 11 sales screens per docs/UI_REDESIGN_PLAYBOOK.md. No router/domain/data/supabase edits; every
controller/provider binding byte-identical. Sales was the last module still on light-only static
`AppColors` — it now has **zero** static-colour references and works in Counter mode.
- **Nav is module-aware.** Inside `/sales/*` bottom_nav_shell.dart renders the design's sales rail
  (Point of sale / Sales history / Returns / Session) above a hairline, with the other modules below it;
  narrow layouts get the same 4 tabs plus a Modules tab opening a sheet (the export has no way back out
  of sales — that escape is ours). Same file/class/ctor, so router.dart is untouched.
- **POS rebuilt**: 932-line page → composition root + `presentation/widgets/pos/` (product grid, search
  bar, cart panel, cart sheet, banners). Catalogue is now a card grid (LayoutBuilder-derived aspect
  ratio, never hand-picked) with category chips fed by the existing `categoriesProvider`; chips are
  **hidden offline** because `CachedProduct` has no category. Desktop = grid + 360px cart column;
  mobile = grid + floating View-cart bar → sheet. Offline gating, autosave, scan, stale-session badge
  and every provider read lifted verbatim.
- **Honest data**: close-session shows only what `close_cashier_session` returns (opening float / total
  sales / transactions → expected in drawer + variance strip) — the design's cash/card/wallet split
  does not exist in the backend and was NOT fabricated. History rows drop the design's "n items"
  (not in the list query); invoice items render `description` + price × qty (invoice_items has no SKU
  or product name); the return screen keeps its reason chips (the RPC requires a reason, the design has
  none). Sync chip, bell and avatar are wired to the real widgets, not the export's hardcoded values.
- New shared widgets: `app_qty_stepper.dart`, `app_filter_chips.dart`, `app_section_card.dart`,
  `app_money_field.dart`. New sales widgets: `sales_scaffold.dart` (header + SalesHeader + avatar),
  `sales_rise.dart`, `sales_empty_state.dart`. No new dependencies.
- **Sales routes cross-fade** (2026-07-21, user-requested router edit): all 8 in-shell sales routes plus
  `/sales/invoice/:invoiceId` moved to `pageBuilder` + the existing fade helper (renamed
  `_authFadePage` → `_fadePage`, now shared with auth). The rail and header are the same on every sales
  screen, so the default slide made static chrome appear to travel. Paths/builders/extra contracts
  unchanged.
- **Product-tile fixes after user screenshot review**: tile overflowed by 9px (guessed height constant),
  the placeholder slot shrink-wrapped into a pill (`crossAxisAlignment.start` on a width-less
  Container), and a missing `StockLevel` read as "Stock not cached" even online. Tile height is now the
  literal sum of named row constants scaled by `MediaQuery.textScalerOf`; stock semantics split by
  connectivity (online → out of stock + untappable, offline → uncached + still sellable). Covered by
  `test/sales/product_tile_layout_test.dart` (8 tests; verified to fail 7/8 when the shortfall is
  reintroduced).
- GATE: `flutter analyze` 10 issues (was 13 — the 3 POS infos died with the rewrite), **0 new**; macOS
  debug builds clean; `flutter test` = the same 2 failures as clean HEAD, re-proven in a detached
  worktree this session.
- **VERIFY OWED (on-device eyeball)**: 900px rail/bottom-bar boundary, grid column counts, dark mode on
  all 11 screens, the offline pass (chips hidden, cash-only payment), cart sheet on a phone, and a
  screenshot diff against the reference renders.

## UI Redesign — repair module (DONE 2026-07-21; detail in DECISIONS)
Fourth design export, SAME design-system UUID → tokens untouched; consumer-side reskin of all 5
repair screens + both pickers. Repair was the last module on light-only `AppColors` — now zero
static-colour references, works in Counter mode.
- **Repair is now a nav-shell branch** (user-approved router edit): appended as branch **index 5**
  after Settings so 0–4 and `_kSalesBranch = 3` never shift; gated `repair:read`; all 5 routes moved
  to `pageBuilder` + the shared `_fadePage`. `/repair/:repairId` still declared last. The 3 inbound
  deep links (inventory hub, approvals, notifications) switched `push` → `go`; intra-module
  drill-downs (intake, detail) keep `push` so back returns to the board.
- **Sales chrome promoted**: `sales_scaffold.dart` → `core/widgets/module_scaffold.dart`
  (`ModuleScaffold`/`ModuleHeader`/`ModuleAvatar`); sales file is now 3 typedefs, its 9 pages
  untouched. `bottom_nav_shell.dart`'s sales-only rail generalised to any module — repair rail =
  Repair jobs / Workload / History, plus the same Modules escape hatch.
- **Board**: column width DERIVED in a LayoutBuilder (share the width when all 7 fit, else 268px
  min + horizontal scroll) — never hand-picked. ≥900px board / grouped list below; **no manual
  Board-List toggle** (user asked for width-driven responsiveness like the earlier reskins).
  Header search is REAL (client-side over the loaded list). Bulk bar is now the design's floating
  ink pill; drag-to-status kept.
- **Honest data**: no `awaiting_parts` column (not in `repair_status_enum`); cost summary is
  Parts / Estimate / Final (no labour field exists); part rows have no SKU; the history timeline
  shows the timestamp alone when `changed_by` is not a known technician; workload keeps the real
  delivered / avg-turnaround instead of the mock's high/urgent (repairJobsProvider is filtered).
- New: `widgets/repair_sheet.dart` (one modal-or-sheet helper, replaced every raw `AlertDialog`),
  `repair_job_card.dart`, `repair_states.dart`, `repair_timeline.dart`; `repair_status_ui.dart`
  rewritten on `AppPill`. `repair_detail_page.dart` split via `part` into page + cards + dialogs.
  Additive tokens: `LumColors.transit*`, `AppPillTone.transit`, `AppButtonSize` (md/sm). No new deps.
- GATE: analyze **8 issues, 0 new** (baseline 10); macOS debug builds clean; `flutter test` = the
  same 2 failures as clean HEAD.
- **VERIFY OWED (on-device eyeball)**: 900px rail/bottom-bar boundary, board columns + drag, dark
  mode on all 5 screens, bulk select, close-&-invoice / warranty paths, screenshot diff vs renders.

## UI Redesign — settings module (DONE 2026-07-21; detail in DECISIONS)
Fifth design export, SAME design-system UUID (5cd3f8f0-…) → tokens untouched; consumer-side reskin
of the settings hub + 5 sub-screens + auth's Profile & security. Settings was the last module on
light-only static `AppColors` (31 refs, 0 `context.lum`) — now zero, works in Counter mode.
- **Sub-screens moved INSIDE the nav shell** (user-approved router edit): the six `/settings/*`
  routes left the top-level list and became siblings of `/settings` in the existing settings
  `StatefulShellBranch`, on `pageBuilder` + the shared `_fadePage`. Paths, page classes and the
  hub's `context.push` call sites are byte-identical; no branch index moved. AppBars replaced by
  the design's in-page back header, so the rail is no longer duplicated by a second bar.
- **New shared primitives** in `core/design/widgets/`: `app_toggle.dart` (46×28 inset pill switch —
  Material's Switch cannot express it), `app_dropdown.dart` (clay-inset well on a stdlib
  `MenuAnchor`, so dismissal/focus/keyboard come free), `app_settings_row.dart`
  (`AppSettingsRow` + `AppSettingsGroup`), `app_detail_scaffold.dart`. `repair_sheet.dart` was
  PROMOTED to `core/design/widgets/app_sheet.dart` (`showAppSheet`/`AppSheetHeader`); the repair
  file is now two aliases, so its 5 call sites are untouched. `AppTextField` gained `maxLines` +
  `helperText` (additive; defaults unchanged, no existing call site moved).
- **Honest data**: the design's per-row device/session counts ("3 devices", "2 active") have no
  source on that page and are OMITTED, not invented; the GL line shows the account code alone
  (`resolvedAccountCode`) because no account name exists in the payload; payment icons are mapped
  from `code` with a generic wallet fallback; the hub's version is the REAL `PackageInfo.version`,
  not the mock's v3.2.0. Theme stays light-only in Preferences (that is what `UiPreferences`
  offers) — dark lives on the profile Counter-mode toggle, exactly as the design does it.
- Branch country/currency/timezone became the export's 3-option dropdowns (user's call); a branch
  stored on any other value still displays it — `AppDropdown` keeps an unmatched value as its own
  option rather than reading as unselected. Both branch sheets moved onto `showAppSheet`.
- The profile page's admin rows are now filtered against `permissionMatrixProvider` BEFORE the
  group builds instead of each being `PermissionGate`-wrapped: a gated-out row still occupies a
  slot, which would leave its hairline behind as a stray rule. Same permission keys.
- New dep: `package_info_plus` (hub version line). GATE: `flutter analyze` **8 issues, 0 new**
  (baseline 8); macOS debug builds and boots clean; `flutter test` = the same 2 failures as clean
  HEAD (widget_test smoke + kpi_layout_persistence), re-proven in a detached worktree this session.
- **VERIFY OWED (on-device eyeball)**: 900px rail/bottom-bar boundary, dark mode on all 7 screens,
  both branch sheets, every dropdown menu, the toggles, and a screenshot diff vs the renders.

## Auth UX pass — Phases 1–4 DONE (2026-07-20)
Interaction/UX depth pass on top of the LUMINA reskin (plan: friction→feedback→flow→a11y; delight
Phase 5 deferred). Frontend + minimal flow/routing (user-approved exception to UI-only guardrail).
- **P1 friction:** AppTextField gained autofocus/autofillHints/enabled; AppOtpField gained autofocus
  (default) + controller/focusNode. Every auth form autofocuses + wires OS autofill (username/email/
  password/newPassword/oneTimeCode). Login: email-format validation, **removed dead "Remember me"**.
  Signup: double-submit guard + email validation. OTP + MFA-challenge: wrong code auto-clears + refocus.
  MFA-enroll: copy-secret button + unified on AppOtpField.
- **P2 feedback:** new AppHaptics, AppToast (showAppToast), AppConfirmDialog (showAppConfirm), animated
  AppInlineBanner; AppButton fires a selection haptic. Destructive actions now **confirm** (device
  revoke, session sign-out, account log-out); success **toasts** on reset / pin-setup / mfa-enroll.
- **P3 flow:** sign-out escape ("Not you? Sign out") on branch-select / workspace-init / mfa-challenge
  (were no-escape dead-ends); removed dead "Use PIN instead" on login; MFA "another method" now signs
  out (was self-loop); branch-select Retry + neutral empty + per-tile spinner; mfa-challenge verify
  spinner + start-failure Retry; workspace-init wrapped in AuthHeroScaffold (desktop hero continuity)
  + removed PII debugPrint; /otp extra-cast guarded; mfa-challenge route now cross-fades; raw
  error.toString() fallbacks → generic message.
- **P4 a11y:** Semantics on AppButton / AppCheckbox / PinPad keys / settings rows; AppInlineBanner is a
  liveRegion; password eye-toggle is a 44×44 target; **ThemeController now persists** (shared_preferences)
  so dark mode survives cold start.
- New design-system files: app_haptics.dart, widgets/app_toast.dart, widgets/app_confirm_dialog.dart.
  GATE: full flutter analyze = 13 pre-existing infos, 0 new; macOS boots clean.
- **P5 delight — DONE (2026-07-20):** hero `_PrismHero` glows now breathe (6s repeating controller,
  opacity+scale, warm glow opposite phase); success toast icon pops in (elastic `AppSuccessCheck`) —
  reused by reset/pin-setup/mfa-enroll since all three success-toast; 3 list screens (devices/sessions/
  security-logs) swapped bare spinner → shimmer `AppListSkeleton` (one gradient-sweep controller). All
  three respect OS reduce-motion (static fallback). No shimmer package — hand-rolled (CLAUDE.md lesson).
  New files: widgets/app_success_check.dart, widgets/app_list_skeleton.dart. GATE: analyze 13 pre-existing
  infos/0 new; macOS builds clean. Optional (clay-pressed AppButton + PIN dots) deferred (YAGNI).

## Auth — COMPLETE
All flows end-to-end. 33+ routes, auth redirect, StatefulShellRoute bottom nav. RBAC, branch selection, PIN lock +
biometric, TOTP MFA (clean-arch, typed AuthFailure — retry banner not lockout), device/session/security management.
Login-throttle fix (2026-07-20, TC-AUTH-LOGIN-004): _submit throttle pre-check now starts the live cooldown ticker
(was static text + enabled button → "stuck timer"); _tick reads captured _cooldownEmail not the live field. Device
re-run owed (6 failed sign-ins to arm lock). Detail in DECISIONS.
Recovery-flow fix (2026-07-20, TC-AUTH-OTP-002/RESET-001): recovery OTP verify skipped /reset → dashboard. Root =
verifyOTP(recovery) creates a session whose onAuthStateChange ran resetUserScopedState() → RecoveryState.reset(),
clobbering codeVerified. Fix: router uid-change handler skips the reset while RecoveryState.isRecovering; reset success
now signOut()s the transient recovery session → lands on /login. Device re-run owed. Detail in DECISIONS.
PIN brute-force fix (2026-07-20, TC-AUTH-PIN-002, P0 SECURITY): two bypasses closed. (1) 3 wrong PINs called
PinLockState.unlock() → wrong PIN dropped the guesser into /dashboard on the victim's live session; now _lockOut()
signOut()s → /login (never unlock). (2) PinLockState.locked is in-memory + only armed on resume, so a force-quit +
relaunch skipped /pin-lock entirely; main.dart now arms the lock synchronously on cold start when a restored session
has a local PIN hash. Device re-run owed. Detail in DECISIONS.

## Staff-onboarding (QR) — Phases 1–9 DONE, feature COMPLETE (2026-07-18; detail in DECISIONS)
Runbook v3. Phase 1 (security, ships alone): closed CRITICAL self-role-escalation — "users update own" RLS now has a
WITH CHECK pinning tenant_id/role_id to the pre-update snapshot (auth_tenant_id/auth_role_id) + column-grant limiting
authenticated UPDATE to full_name/phone/avatar_url/pin_hash. Removed anon lock/unlock DoS (Option A): revoked
increment/reset_failed_login from anon/public, deleted client sites, LoginThrottleService local-only. provision_tenant
revoked from public/anon + ERR_FORBIDDEN_TENANT guard (auth.uid()-NULL signup path exempt). hierarchy_level backfilled
(3 dirty tenants → ADMIN=1/CASHIER=5) + guard_role_hierarchy trigger. New helpers is_admin_role_name, auth_can_grant_role
(drift-proof subset gate). Verified via rolled-back probes; live cashier-JWT + app-signup smoke = owner acceptance.
Phase 2 (phase2_staff_invites_schema): invite_status_enum + staff_invites/staff_invite_branches (token_hash unique,
multi-branch, expiry) RLS read-only, no write/anon policy. Phase 3 (phase3_staff_invite_rpcs): 7 SECURITY DEFINER fns —
create (four-guard name/subset/level/branch), validate (anon pre-auth), consume (trigger-only race-safe single-use),
revoke/list/regenerate/release_abandoned. Phase 4 (phase4_handle_new_user_invite): handle_new_user now 4-path —
invite_token→join existing tenant (stub-insert+consume+backfill FK-order fix; token scrubbed), business_name→ADMIN
(unchanged), demo_mode→Demo (gated), else→raise. All 4 gate-proven through the real trigger. Phase 5
(phase5_roles_permissions): list_permission_catalog/create_tenant_role/update_role_permissions/list_tenant_roles +
update_user_role (2nd escalation door — same 4 guards + last-admin lockout). Gate-proven via rolled-back JWT-claim
impersonation as ADMIN. Phase 6 (Flutter `lib/features/staff/`, clean-arch mirror of approvals + list_tenant_users RPC):
6 pages — staff invites (list/revoke/regenerate/release), invite create, QR (shown-once token), roles+members tabs,
role form (permission picker), user role change; wired into router + Settings "Team" group + HR "Create login" (first
writer of employees.user_id). Phase 7 (invitee, first pre-auth path): login "Scan invite QR" → /join/scan (MobileScanner,
both token shapes) → validate (anon) → /join/redeem (signUp with invite_token, never business_name) → /otp → in; join
routes added to pre-auth authRoutes. Phase 8 (signup gating): business name now REQUIRED client-side + "Try demo"
button (demoMode threaded through signUp chain) — no more blank→Demo-Store→trigger-500. Phase 9 (tests): full guard
matrix runtime-proven via rolled-back impersonation (S18/S19 lateral-grant, S15 last-admin, S21 null-hier all blocked;
1.10 blocks ADMIN re-drift); data integrity clean. Remaining: owner on-device acceptance (PIN/MFA/POS smoke). analyze clean.

## Inventory — COMPLETE (Slices A/B/C; detail in DECISIONS.md)
Catalog (categories/brands/products + variants/images/pricing, barcode templates, trigram search, SKU auto-gen,
soft-delete RPCs). Stock engine (trigger-maintained stock_balance over immutable stock_ledger; all writes via
post_stock_movement; negative blocked; warehouses CRUD + opening-balance + levels + ledger). Stock ops
(adjustments/transfers/counts, imei_records, inventory_settings, number_series; +4 enums, 10 RPCs; full clean-arch).

## Database Migrations

Ordered, applied set lives in `supabase/migrations/` (filenames = the index); rationale logged in DECISIONS.md by
date. Coverage: auth/RBAC → catalog/stock → sales/returns → dashboard → purchasing/CRM ledgers → M07 accounting
(7 money paths) → M08 reporting → M09 repair → M11 notifications → security (Phase 1).

## Peripheral features — COMPLETE (detail in DECISIONS.md)
Barcode scanning (mobile_scanner, shared scanBarcode/BarcodeScanPage); label printing (LabelPdfService/LabelPrintPage);
notifications (+prefs, trg_low_stock_notify, hub bell badge); bulk CSV import (bulk_import_products); voice search (speech_to_text).

## Known Issues
- Profile loaded once (no pull-to-refresh); IMEI section not yet in product edit form (SERIALIZED)
- ✓ FIXED (DECISIONS): number_series landmine (D1); cron reproducibility (D5). BUILD: macOS+Android OK; file_picker pinned 12.0.0-beta.7 (D4), withData/bytes→readAsBytes() still pending.
- Auth test-diagnosis fixes (docs/AUTH_TEST_DIAGNOSIS.md; branch fix/auth-runbook-v1, DB migrations pushed to
  prod). 11 clusters verified against source, then fixed across 9 phases. Client (Cluster E/D1/D2/C): login
  empty-field error; real password-strength scorer (length + char-class + sequential/repeat); WeakPasswordFailure
  mapping + signup surfaces AuthFailure.message; duplicate-email signup detected via empty `identities`. Native
  (G): MainActivity → FlutterFragmentActivity + biometric errors surfaced. DB migrations (pushed): audit_logs
  tenant_id stamped by BEFORE-INSERT trigger + tightened insert policy (was RLS-invisible); public.sessions now
  mirrored from auth.sessions via guarded trigger (was dead write path) + added tenant_id/last_active_at columns
  the read path assumed; supabase_realtime publication + REPLICA IDENTITY FULL on devices/sessions/audit_logs/
  permissions; create_branch RPC (tenant-scoped, settings:create, assigns creator, I8-safe). Client realtime
  subscribe-reload on those 4 controllers + permissionMatrix refetch on permissions change (no relogin). Settings
  hub ungated so CASHIER reaches self-service MFA/PIN (admin groups still settings:read). Role-permission editing
  UI (dual-mode role form + tappable non-system cards). Branch create FAB + Switch-branch entry. Cluster A
  (recovery) REFUTED in code — no fix, device retest owed. Cluster B (recovery-any-email) left as likely-intended
  anti-enumeration. Device/runtime gate-proves still owed (manual TC-AUTH, hardware biometric, 2-device sessions,
  realtime propagation, guard-through-UI); RUNBOOK 0.9 publication/isolation re-check owed.

## Tenant Provisioning — COMPLETE (creation-time, gate-proven; full detail in DECISIONS.md)
`provision_tenant()` seeds the golden set (20 CoA / 10 number_series / 4 tax / OPEN fiscal / 3+3 templates /
REPAIR-SERVICE sentinel / Main Warehouse / 7 payment methods) idempotently; `verify_tenant_provisioning()` gates it
(`complete`). handle_new_user calls it in the signup txn (failure rolls signup back atomically). Phase 1 hardened it:
revoked from public/anon + ERR_FORBIDDEN_TENANT guard (signup path exempt via auth.uid()=NULL). Ops: cron
verify_provisioning_daily alerts admins on any complete=false; fiscal reuses current_fiscal_period (MONTHLY).

## Migration Import — COMPLETE
`lib/features/migration_import/` clean-arch (reuses InventoryFailure). 4 set-based RPCs (migrate_import_categories/brands/products/stock); MigrationImportPage 4 FK-ordered step cards. Route /inventory/import-migration.

## Sales V1 — Core COMPLETE

DB foundation (S1): customers, cashier_sessions, invoices, invoice_items, payments + RLS; RPCs create_sale,
open/close_cashier_session, create_sales_return, void_invoice; invoice-immutability trigger; INVOICE
number_series seed. Full clean-arch sales feature: POS terminal (search+scan, cart, customer picker,
multi-payment/credit, tax, hold/resume, void, return), DB-backed session lifecycle (open/close, variance,
staleness), cart autosave, history+detail (Reprint/Share), 80mm receipt PDF. Permission-gated routes +
bottom-nav. create_sale enforces min_selling_price + credit_limit (overridable by sales:approve); tax is
server-authoritative (D6, 2026-07-16 — from tax_rules, client tax_pct ignored, raises if no active rule).
close_cashier_session gated sales:create + owner-only. Live-sales banner via sessionSalesProvider (no silent
zero). Full per-slice detail in DECISIONS.md.

### Sales V1 Deferred
delivery_orders, loyalty, customer_groups, pricing-tier. (offline sync → Sync/Offline §3.3.)

## Dashboard V2 — COMPLETE (relocated to features/dashboard/, clean-arch)
page moved out of auth/ → features/dashboard/presentation/pages/. reports:read gate, pull-refresh, fl_chart bar+pie,
recent sales, quick-launch. 10-KPI grid (6 orig + payables/cash/bank/pl) CONFIGURABLE — show/hide + order persisted
SERVER-SIDE per user via ui_preferences.dashboard_layout_json / upsert_ui_preferences (clean-arch, read on load / write
on change; first run migrates any legacy shared_preferences layout up once, then server-authoritative). Each KPI taps a DrilldownPage
over drilldown_* RPCs; rows deep-link (invoice→/sales/invoice, product→/inventory/stock, journal→/accounting/journal).
DASHBOARD-RUNBOOK-v1 (branch fix/dashboard-runbook-v1, static-verified): A pull-to-refresh now awaits reload
(refresh() returns Future + ListView AlwaysScrollableScrollPhysics); G drilldown error state gained a Retry
(invalidates drilldownProvider, mirrors dashboard page's Retry); B+E invoice-detail lookup now resolves by id OR
invoice_number (recent-sale + sales/receivables/product drilldowns pushed invoice_number into an id-only lookup →
silent infinite spinner; loadDetail fed resolved invoice.id). Both match arms stay inside the RLS-scoped invoices
list — no RLS loosened. C (POS gate) + D (edit toggle) verified NOT code defects (gate correct, reorder persists
server-side + restart-safe) — left untouched; re-test only. OWED runtime: 16-TC click-through, restricted-acct
TC-007, toggle+restart TC-008/009/010, throttled DRILL-003.

## M08 Reporting — backend LIVE (DB layer), all gate-proven rolled-back
- MVs (reporting_materialized_views): 6 matviews (daily_sales [fan-out FIXED], inventory_valuation [canonical], account_balances, cust/supp_aging, product_performance) refreshed CONCURRENTLY; raw select revoked (definer RPCs).
- Drilldowns (reporting_drilldowns/_complete/_payables): 6 RPCs leak-proven; ALL 10 dashboard KPIs tappable (stock_value+pl→existing pages).
- Scheduling (reporting_schedules + deliveries_fix): run_due (pg_cron */15) queues PENDING report_deliveries; SEND = M11 dep.
- Analytics (analytics_events): immutable partitioned+gin, RLS read-own/definer-write (FLAG: only a DEFAULT partition, no time-bounded ones — inserts degrade not reject). AI recs (ai_recommendations): generate_reorder_recommendations + act_on_recommendation; ML deferred.
- Reporting UI COMPLETE (features/reporting/ + reporting_read_rpcs): ReportsHubPage /reports + Inventory/Product-Perf/Cust-Supp-Aging/Trends/Forecasting (fl_chart, definer RPCs over MVs), ScheduledReports (reports:export), SmartInsights (ai_recs + REORDER→Create-PO), PDF/CSV export.

## M11 Notifications — ACCEPTED (all layers LIVE; provider keys pending)
- Templates (notifications_templates): sms+email (§3.13) seeded 3+3/tenant, {{placeholder}}. NEW 'notifications' perm module (6 grants/ADMIN × 5 tenants). RLS tenant-read + notifications:update. Gate-proven.
- Dispatch (notifications_dispatch + notify_status_enum_cast_fix + notify_skip_push_no_transport D3 2026-07-17): notify() single producer — IN_APP DELIVERED + one PENDING/extra channel, PUSH skipped entirely (no transport); render_template / mark_all_read / unread_count / upsert_preference. Producers migrate incrementally. NOTE: notification_preferences is empty (0 rows) — notify() has never executed in production.
- Detectors (notifications_detectors): fn_overdue_receivables / fn_unpaid_salaries / fn_stock_mismatch + fn_low_stock_notify → daily-idempotent IN_APP alerts; pg_cron 07:00 (in migrations/cron_bootstrap.sql, D5). Gate-proven.
- Sender (edge fn notification-sender) + Push (notifications_device_tokens): service-role (unauth→401) drains PENDING notifications/comm_logs/report_deliveries via Twilio+SendGrid+FCM v1, marks SENT/FAILED/SKIPPED (PUSH-no-token -> SKIPPED, D3 2026-07-17, one-shot sender has no retry so FAILED there was unrecoverable); deployed, inert until keys; cron trigger DEFERRED. Keys: TWILIO_*/SENDGRID_KEY/FROM_EMAIL/FCM_SERVICE_ACCOUNT. Flutter firebase_messaging DEFERRED. FLAGGED not built: sender is one-shot, no attempts/retry column — a real transient error (e.g. SendGrid down) permanently kills a notification today, PUSH or not.
- UI COMPLETE (features/notifications/): NotificationBell (badge, 30s poll) → /notifications Center (filters, deep-links, mark-all-read) + /settings (6 event_types × 5 channels, PUSH chip disabled-with-reason 2026-07-16 D3). Admin: /templates, /bulk, /logs. NEXT: provider keys + drain cron; migrate producers to notify(); sender retry design (flagged above).

## Purchasing — COMPLETE (back end + Flutter)

Back end (migrations, all applied): suppliers, purchase_orders(+items), grns(+items), purchase_invoices,
supplier_payments; RPCs create/update/submit/approve/cancel_purchase_order, receive_goods,
create_purchase_invoice, record_supplier_payment (overpayment guard), supplier_ledger, payables_aging.
Landed cost by line_total; canonical warehouse_id NULL stock via post_stock_movement PURCHASE_RECEIPT; serialized IMEI →
imei_records AVAILABLE. PO lifecycle DRAFT→SUBMITTED→APPROVED→PARTIALLY_RECEIVED/RECEIVED→INVOICED, CANCELLED. Two
receive_goods bugs forward-fixed: enum-cast (20260711101802), imei IN_STOCK→AVAILABLE (20260711111535).

## Sync / Offline (§3.3) — D1–D11 LIVE — SYNC & OFFLINE COMPLETE (gate-proven)
D11 sync_retry_intent (20260716161000, LIVE — not money): closed the exception GRAVEYARD (resolve only ANNOTATED; the lost sale
never posted). retry_sync_intent (sync:resolve) re-queues an ABANDONED/FAILED intent + replays inline impersonating the original
cashier; D4 key ⇒ exactly one invoice, already-applied = no-op. sync_replay guard OPEN-scoped so a re-failed retry re-surfaces.
Flutter Retry action beside Resolve. Gate green: graveyard→recover→no-double-post→re-surface.
D10 sync_replay_classifier_fix (20260716160000, LIVE — not money): closed bug class #7 (silent FAILED-at-cap). terminal regex +=
NO_TENANT|PERMISSION_DENIED (revoked/tenant-less cashier → ABANDONED+exception; was stuck FAILED<cap invisible); transient at cap
(attempts+1≥5) now also surfaces. Gate before/after: 3 silent holes → visible; below-cap transient still retries (no over-fire).
SIGN-OFF #5 (p_transaction_date) DEFERRED BY CHOICE — accepted latent misstatement, NOT "safe": posting at current_date IS the
defect, open period only makes it SILENT (sale synced across midnight/month-end books to the wrong day/period, all gates green).
REVISIT at month-end or on any overnight-offline report. See DECISIONS Sign-off #5.
D1 sync_pull_reference (20260716073759 + fix 125000, LIVE): Class A pull-only delta + stock_balance full pull; SECURITY DEFINER
per-subquery tenant filter evicts soft-delete tombstones (INVOKER RLS silently dropped them). D2 sync_foundation (075906):
sync_outbox + sync_exceptions (append-only, NEVER makes an invoice) + 2 enums + `sync` perm; RPC-only writes (insert→42501).
D3 sync_invoice_idempotency (131500): invoices += idempotency_key/device_id/local_ref; uq_invoices_idem PARTIAL = un-raceable
double-post guard. D4 sync_create_sale_idempotency (133000, MONEY): create_sale += p_idempotency_key (drop+create 7-arg); replay
returns the ORIGINAL invoice, guard BEFORE next_number, ACL re-hardened. (full per-D detail in DECISIONS)
D7.1 CLIENT (lib/features/sync/, mirrors approvals; +sqflite/ffi/connectivity_plus/uuid, NO build_runner): sqflite cache (hand
DAOs) + pull-reference watermark delta (deleted_at→evict); ConnectivityMonitor. Offline CASH-ONLY — a cash sale appends a SALE
intent (uuid key, provisional local_ref), NEVER create_sale. POS: SyncStatusWidget; credit/returns/customer/close-register
disabled offline w/ reason; search cache-first; success shows local_ref PROVISIONAL.
D7.2 replay drain + Exception Centre (sync_push_intent 20260716151500 — idempotent client→server enqueue): on reconnect DRAIN
oldest-first ONE AT A TIME; idempotent 3 ways (push key + replay guard + create_sale key) → drain-twice/kill-mid = 3 invoices not 6.
SyncExceptionCentrePage /sync/exceptions (sync:read, product deep-links, Resolve/Retry). SyncStatusSheet. sqflite v2 (onUpgrade).
D8 ops (sync_drain_cron 20260716154500): cron `sync_outbox_drain_5min` (*/5, in migrations/cron_bootstrap.sql) drains server-side — impersonates each row's
cashier (pg_cron has no JWT) then routes through sync_replay_sale_intent; service_role only; registered AFTER D4/D5 green.
DEFERRED (full list in DECISIONS): sync_log/conflicts/domain_events (superseded LWW); offline variants/stock caching; #5; probe.
D5 sync_replay_driver (20260716134500, LIVE): sync_replay_sale_intent (for-update-skip-locked → create_sale w/ the outbox key →
APPLIED + stamps is_offline/synced_at/device_id/local_ref) + resolve_sync_exception. Terminal→ABANDONED + sync_exceptions;
transient→FAILED. RELAXED fn_invoice_immutability for a metadata-only stamp on a PAID invoice (jsonb-diff, financials still
immutable — gate-proven). Classifier holes later closed in D10.

### Purchasing (Flutter) — COMPLETE
`lib/features/purchasing/` full clean-arch (mirrors suppliers/sales): 6 entities + 2 status enums + 5 RPC result types;
sealed PurchaseFailure; 13 usecases; ONE PurchaseRemoteDataSource (all selects + 8 RPCs) → typed failures. Controllers:
PurchaseOrders (list/status/create/edit/submit/approve/cancel/receive) + detail/grns providers; PurchaseInvoices
(create→match_variance) + payments; PurchasePayments. 10 pages: Hub, PO list, PO form (supplier + inline product-search
editor + charges + live totals, edit DRAFT-only, accepts reorder seed), PO detail (status-gated actions + linked GRNs/
invoices), GrnReceive (per-line qty/reject/batch/expiry + IMEI for SERIALIZED), InvoiceMatch (3-way variance), invoices
list+detail (Record Payment), SupplierPayment (blocks overpayment), ReorderSuggestions (≤reorder_point → seeds PO).
Routes /purchasing/* + 5th "Purchase" bottom-nav branch gated purchase:read. DB lifecycle verified rolled-back. analyze clean.
PO-form validation fix (2026-07-20): a line with qty/cost but no product looked complete (showed a line total) yet was
silently dropped by _save; if it was the only line the generic "add at least one line" error confused users. Now every
line is validated individually (product required, qty>0, cost≥0) with a precise message, and the product selector is a
proper required field that highlights red ("Product required") on save when unset. Device re-run owed.

### Suppliers CRM (Flutter) — COMPLETE
`lib/features/suppliers/` full clean-arch: Supplier/SupplierStatus + SupplierLedger/PayablesAging entities; sealed
SupplierFailure; 7 usecases; SuppliersRemoteDataSource (ILIKE search, status filter, ledger/aging RPCs); controller +
ledger/aging providers. Pages: list (search, status chips, payable hint, FAB purchase:create), form (purchase:update/
delete), detail (ledger balance/timeline + Record Payment TODO). Routes /suppliers[/create|/:id|/:id/edit]; hub row. Verified vs live RLS.

### Customers CRM (Flutter) — COMPLETE (parity with suppliers)
`lib/features/customers/` full clean-arch mirroring suppliers (Customer moved from sales — old paths re-export).
CustomerLedger/ReceivablesAging entities; CustomerFailure; usecases + datasource (customer_ledger/receivables_aging) +
controllers. Pages: list, form, detail (credit + ledger + Collect Payment), ReceivablesAging. Collect-payment:
record_customer_payment + unpaid-invoice picker → CustomerPaymentPage (/customers/:id/collect, sales:create, overpayment
blocked). Receivables KPI; POS chip shows remaining credit; CreditLimitExceededFailure from create_sale. DEFERRED: groups,
loyalty, comms, bulk import, statements.

### Purchase Returns (Flutter) — COMPLETE
`lib/features/purchasing/` extended. Debit-note-style return of received goods. Domain: PurchaseReturn(+Item/Status/
ReturnCreateResult); PurchaseFailure += ReturnExceedsReceived/ImeiCountMismatch/ImeiNotFound. 4 usecases; datasource
(loadPurchaseReturns/loadReturnedQtysForPo embedded-summed / rpc create_purchase_return p_reduce_invoice=false) +
controller/providers. Pages: list (+status), detail (lines + returned IMEIs), form (mirrors GRN receive: received/
already-returned/available per line, qty bounded, SERIALIZED needs exactly qty IMEIs, reason required). Entry: PO detail
"Return" + invoice "Return Against Bill" (purchase:update); routes /purchasing/returns[/create|/:id]. Ledger kind=RETURN =
credit. No migration (RPC + PR- series pre-live). Rolled-back dry-run verified incl. over-return guard.

### M07 Accounting — COMPLETE (all 6 money paths auto-post)

DB-level double-entry GL. `post_journal` = sole ledger writer (balance + immutability + CLOSED-period guard enforced;
ungated auto-posts pass `p_gate=false`). D6 (20260716140000): raises ERR_PERIOD_CLOSED into a CLOSED fiscal period —
UNCONDITIONAL (not behind p_gate; a closed period is an accounting control, not a permission). fiscal_periods.status was
decorative before (D11.4: no check existed); prerequisite for back-dating offline sales [SIGN-OFF #5]. All 6 money paths —
SALE, CUSTOMER_PAYMENT, PURCHASE_INVOICE, SUPPLIER_PAYMENT,
PURCHASE_RETURN, SALES_RETURN — emit a balanced journal (six-path gate green; trial_balance + balance_sheet true); GL
reconciles 1:1 with AR/AP subledgers. Payment→GL split CLOSED (S1–S2, S8): all 4 divergent hardcodes gone;
resolve_payment_account SOLE resolver in 7 money paths; close_repair_job keeps literal 1000 (cash-only by construction —
Deferral A). tax_rules CONSUMED (S4): resolve_tax_rate defaults product/POS tax (create_sale untouched, caller p_tax_pct
authoritative). A6 UI: `lib/features/accounting/` clean-arch — hub, CoA tree, ledger, journal list+detail (reverse gated),
manual voucher, expenses, bank/tax-rule CRUD, Reports (export gated), fiscal periods + bank reconciliation.

## Settings / M12 — S1–S8 COMPLETE (backend gated settings:update; per-phase detail in DECISIONS)
UI (S6): `lib/features/settings/` clean-arch, ONE datasource, typed SettingsFailure. SettingsHubPage = bottom-nav
/settings (settings:read) → Profile&Security, Business settings, Branches, Payment methods (7 enum complete), Tax rules,
Number series (read-only; fiscal_year_reset DROPPED D2), Preferences, Notifications. formatPkr follows branch currency.

## M09 Repair & Service — COMPLETE (backend + Flutter)
Backend (applied + gate-verified; full detail in DECISIONS 2026-07-13/14): repair_jobs/parts/status_history +
repair_status_enum(9), RJ- series, REPAIR-SERVICE sentinel (type=SERVICE) + 4200 Service Revenue, REPAIR_USE movement.
Lifecycle RPCs + close_repair_job (7th money path: invoice + REPAIR_INVOICE journal; parts COGS Dr 5000/Cr 1200).
Pipeline C3–C6: bulk_change_repair_status + technician perf; C4 communication_logs notify intents; C5 parts output tax;
C6 WARRANTY_CLAIM re-repair (original_repair_id self-FK, 5200 Warranty Cost). SERVICE non-stock guard; signature capture
(private bucket + RLS, 60s signed URLs). Flutter (`lib/features/repair/`): kanban (drag+bulk), intake, detail (close
Close&Invoice vs Warranty-no-charge + warranty link), workload, history, QR label. DEFERRED: edit, intake signature, SMS.

## M10 HR & Payroll — COMPLETE (backend H1–H6 + UI H7.1–H7.3)
Backend (all migrations applied + rolled-back-gate-verified; full per-phase detail in DECISIONS 2026-07-14):
- H1 foundation: 7 enums, employees+shifts tables, RLS (tenant read / hr-gated writes), NEW `hr` perm module
  (+trg_seed_hr_perms), CoA seeds 6200 Salary / 2120 Deductions Payable / 1150 Employee Advances.
- H2-H4: create/update/terminate_employee, upsert_shift; mark_attendance (late/OT, edit needs reason), apply/decide_leave;
  create_payroll_run → calculate_payroll (basic+OT−advance−deductions, net≥0) → approve_payroll_run.
- H5 disburse (**8th money path**): disburse_payroll_run posts balanced PAYROLL journal (Dr 6200 / Cr 1150/2120/1000).
- H6 advances (**9th money path**): disburse_salary_advance (Dr 1150 / Cr 1000), recovered via payroll.

HR UI (`lib/features/hr/`, full clean-arch; per-slice detail in DECISIONS H7.1–H7.3): sealed HrFailure(11), ONE datasource.
H7.1 employees/shifts (profile 4 tabs). H7.2 attendance/leaves (edit-reason, clock in/out). H7.3 payroll (DRAFT→CALCULATED
→APPROVED→DISBURSED + journal, PayslipPdf, advances). Routes /hr/*; hub gated hr:read.

## M11 Approvals — Backend + Approval Center + Workflow-config UI (full detail in DECISIONS)
approval_status_enum(6)+approval_workflow_type_enum(8); workflows/requests/actions + uq open-request-per-entity; RLS
tenant-read/RPC-only; `approvals` perm module. Engine (gate-verified): upsert_approval_workflow, request_approval
(workflow-by-threshold, no match→required:false, idempotent), act_on_approval (level role, ADMIN super-approver,
min_approvers, append-only), cancel; escalate_expired_approvals + pg_cron hourly. UI: PendingApprovals/Detail/History
+ Workflow-config. A5 PO integration LIVE: submit_purchase_order raises approval, approve blocked while chain open, inert w/o workflow. NEXT: wire other 7 types.
