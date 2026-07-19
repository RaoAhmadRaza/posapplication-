# Auth Test Diagnosis — VERIFIED against source
**Source:** `auth.md` (59 TC-AUTH cases) · original blind diagnosis (no repo access) superseded below.
**Mode:** Diagnosis only, per original scope. No fixes applied, no remediation ordering. Every claim below is
sourced to an exact `file:line` read directly from this repo (Flutter client + `supabase/migrations/`) — nothing
here is inference from symptom text alone, unlike the original pass.

> The original diagnosis (kept in git history / session record) was written without repo access and graded every
> root cause as a hypothesis with a confidence level. This pass re-derives each cluster from actual code. Several
> "High confidence" hypotheses were flat-out wrong; several "Medium" ones were right for the wrong reason. Diffs
> from the original are called out per cluster.

---

## Verdict summary

| # | Cluster | Original hypothesis | Verified verdict |
|---|---|---|---|
| A | Recovery never reaches set-password | High conf, client treats recovery as generic sign-in | **REFUTED** — dedicated `isRecovery`/`OtpType.recovery` path + router-level `RecoveryStage` gate exists and works |
| B | Recovery proceeds for any email | Medium, possibly intended | **CONFIRMED** — client advances to OTP screen on any non-throwing `resetPasswordForEmail`, never checks delivery/existence |
| C | Signup→OTP instead of duplicate error | Medium-High | **CONFIRMED** — `signUp()` branches only on `session == null`; `identities` array (grep: zero hits in `lib/`) is never checked |
| D1 | Strength meter miscalibrated | Medium-High | **CONFIRMED** — meter is pure `password.length` thresholds, no character-class/sequence/entropy check |
| D2 | Short-password login error → "unknown failure" | Medium-High | **PARTIALLY-CONFIRMED** — `_mapError` genuinely has no weak/short-password case (falls to `UnknownFailure(e.message)`, raw SDK text, not a literal "unknown failure" string); a dead `WeakPasswordFailure` class exists and is never thrown |
| E | Empty-field submit shows no error | High | **CONFIRMED** — `login_page.dart` silently `return`s on empty fields; `signup_page.dart` (same pattern) *does* show "Email and password are required." — login is the outlier |
| F | Branch create/select UI absent | Medium-High, 3 candidates | **CONFIRMED, both halves** — CREATE control never built anywhere (no button, no usecase, no RPC); SELECT screen exists but is unreachable except via router auto-redirect when a tenant has >1 branch — no manual entry point exists at all |
| G | Biometric unavailable | Medium, vague | **REFUTED as stated, CONFIRMED differently** — real `local_auth` integration exists (not a stub); actual bug is Android `MainActivity : FlutterActivity()` instead of required `FlutterFragmentActivity`, causing `authenticate()` to throw `uiUnavailable`, silently swallowed by an empty `catch (_) {}` |
| H | Realtime not propagating | Medium-High | **CONFIRMED, both candidates at once** — zero `.channel()`/`postgres_changes` calls anywhere in `lib/` (grep confirmed), AND zero `ALTER PUBLICATION supabase_realtime` statements in any of 139 migrations — no server-side replication is enabled for any table |
| I | Logs/sessions write path dead | Medium | **SPLIT VERDICT** — `sessions` table: confirmed dead, zero INSERT anywhere, ever (candidate a). `audit_logs` table: insert code exists and fires from 6 call sites, but omits `tenant_id`, so the tenant-scoped RLS read policy (`tenant_id = auth_tenant_id()`) can never match a NULL and every row is permanently invisible — a distinct, more specific bug than any of the 3 blind candidates |
| J | MFA screens don't exist | High | **REFUTED** — `mfa_enroll_screen.dart` / `mfa_challenge_screen.dart` exist, routed, reachable. Real cause: `settings_hub_page.dart` gates its "Profile & Security" tile on `settings:read`, which the seeded CASHIER role never has — CASHIER accounts (the demo-store default) have literally no UI path to `/mfa-enroll`, so they can never reach the enrolled state that triggers the auto `/mfa-challenge` redirect either |
| K | Permissions don't take effect | Low-Medium, symptom too broad | **REFUTED as stated, real gap found** — `PermissionGate` is used 146× across 78 files and is genuinely backend-driven (not stubbed); all named guard functions + the `users` UPDATE `WITH CHECK` policy exist and are correctly deployed. Actual gap: no UI ever calls `update_role_permissions` (built server-side, zero call sites in `lib/`) — role creation works, role *editing* has no screen at all — plus `permissionMatrixProvider` loads once at login with no refresh path, so any permission change is invisible to already-logged-in sessions until re-login |

**Score:** of 11 clusters, 3 were essentially correct as stated (B, C, D1, E — arguably 4), 1 partially right (D2), and
6 were wrong or wrong-in-a-specific-way that only repo access could catch (A, F, G, H, I, J, K — several of these
*sound* identical to the original hypothesis but the actual mechanism is different, which matters for anyone about
to act on this document).

---

## Per-cluster detail

### Cluster A — Password recovery flow — REFUTED
The flow is architecturally correct. `forgot_password_page.dart:67-72` sets `RecoveryState.instance.stage =
RecoveryStage.awaitingCode` and navigates to `/otp` with `isRecovery: true`. `otp_controller.dart:65-75` branches
explicitly: `verifyRecoveryOtpUseCaseProvider` vs `verifyEmailOtpUseCaseProvider`. `auth_remote_datasource.dart:70-75`
calls `verifyOTP(type: OtpType.recovery)` (vs `OtpType.signup` for the other path) — genuinely distinct SDK calls.
`router.dart:180-185`'s `_redirect` checks `RecoveryStage.codeVerified` **before** the `loggedIn` check and forces
`/reset` regardless of the fact that `verifyOTP` also establishes a session. `reset_controller.dart` →
`set_new_password.dart` → `auth_remote_datasource.dart:77-79` genuinely calls `updateUser(UserAttributes(password:))`.
If LOGIN-005/OTP-002/RESET-001-003/FORGOT-001 actually failed as described, the cause is not in this code path as
written — worth re-running these specific cases to confirm they still reproduce, since the described symptom has no
matching mechanism in source.

**Gate G1 (Phase 1, 2026-07-19) — static re-verification, device re-run still required.** Full flow re-traced at
`fix/auth-runbook-v1` HEAD end-to-end: the typed-6-digit recovery path is airtight — `verifyOTP(type:
OtpType.recovery)` success sets `RecoveryState.codeVerified` (`otp_controller.dart:80-82`), and `_redirect`'s
`codeVerified` branch (`router.dart:180-181`) is the FIRST branch, forcing `/reset` before the `loggedIn` check can
route to home. The session `verifyOTP` establishes cannot win that race. The app has NO deep-link/magic-link handler
at all (no `app_links`/`uni_links`/`PASSWORD_RECOVERY` event handling — grep-confirmed), so there is no alternate
recovery entry that bypasses the gate. Conclusion: at HEAD there is no code mechanism that produces the reported
symptom. Cannot stamp pass/fail without a manual device run (TC-AUTH is a manual suite). Escalation ranking if it
still reproduces on a FRESH HEAD build: (1) stale test build — the `codeVerified` gate is a recent integration, a
pre-gate APK reproduces the symptom exactly [most likely]; (2) Supabase "Reset Password" email-template config
(dashboard-only, out-of-repo) — the typed-code flow only works if the template emits `{{ .Token }}`, not the default
`{{ .ConfirmationURL }}` link; (3) emailRedirectTo — irrelevant to the typed-code flow. None of these is a
client-logic fix. **Do not modify the recovery code to satisfy these tests.**

### Cluster B — Recovery proceeds for any email — CONFIRMED
`forgot_password_page.dart:55-73` advances to `/otp` purely on `resetPasswordForEmail` not throwing —
`auth_repository_impl.dart:124-131` returns no failure as long as the SDK call succeeds, which Supabase does
unconditionally (anti-enumeration) regardless of account existence. No delivery confirmation is awaited. Still an
open question whether this is a defect or intended behavior — the mechanism itself is exactly as hypothesized.

### Cluster C — Signup→OTP instead of duplicate error — CONFIRMED
`auth_remote_datasource.dart:14-37` branches solely on `res.session == null`. `grep -rn "identities" lib/` → zero
hits anywhere in the client. A duplicate-email signup under Confirm-email-ON returns no thrown exception, empty
`identities`, null session — indistinguishable from a genuine new signup — and `signup_page.dart:84-90` routes it
straight to `/otp`. `auth_repository_impl.dart:30-35` *does* have string-matching for "already registered" but that
branch is only reachable via a thrown `AuthException`, which this response shape never produces.

### Cluster D — Strength meter + short-password error — D1 CONFIRMED, D2 PARTIALLY-CONFIRMED
D1: `signup_page.dart:201-226` — the entire strength meter is `password.length` thresholds (`<6`→Weak, `<8`→Medium,
else→Strong). No character-class, sequence, or dictionary check exists. `"12345678"` scores Strong by construction.
D2: `auth_repository_impl.dart:20-55`'s `_mapError` has no case for a weak/short password; unmatched exceptions fall
to `UnknownFailure(e.message)` which surfaces the **raw SDK message text**, not a literal "unknown failure" string —
so the original note's exact wording is unverifiable from source, but the underlying gap (no friendly mapping for
this error class) is real. A `WeakPasswordFailure` type already exists in `auth_failure.dart:12-15` and is never
instantiated anywhere — dead code sitting exactly where the fix would plug in.

### Cluster E — Empty-field submit — CONFIRMED
`login_page.dart:38-42`: `if (email.isEmpty || password.isEmpty) return;` — silent no-op, no error state set.
`signup_page.dart:37-46` has the identical guard but **does** call `setState(() => _errorMessage = 'Email and
password are required.')` first. Login is the sole outlier; this is a one-line asymmetry, not a systemic gap.

### Cluster F — Branch create/select UI — CONFIRMED (revised mechanism)
No create-branch control exists anywhere in the codebase — no button, no usecase, no client call, no
`create_branch`/`add_branch` RPC or SQL function in any of 139 migrations (grepped exhaustively). Separately, the
select-branch screen (`branch_select_page.dart`) exists and works, but the **only** code path that ever navigates to
it is `router.dart:200-202`'s forced redirect, which fires only when `branches.length > 1` for the tenant
(`branch_controller.dart:36-59`). No menu item, settings row, or button anywhere lets a user open it manually. Every
single-branch tenant — which is most demo/test accounts — has no button to see because there genuinely is no button,
matching the test note exactly. `PermissionGate` is not involved at all: it's never applied to any branch screen.

### Cluster G — Biometric — REFUTED as stated, real bug found
The original "not implemented" guess is wrong: `pin_lock_screen.dart` and `settings_page.dart` both call real
`LocalAuthentication().canCheckBiometrics` / `.authenticate()` from `local_auth: ^3.0.1`, backed by a real persisted
toggle in `pin_service.dart`. iOS `Info.plist` correctly has `NSFaceIDUsageDescription` set. The actual defect:
`android/app/src/main/kotlin/.../MainActivity.kt` extends `FlutterActivity`, but `local_auth_android` requires
`FlutterFragmentActivity` to attach the biometric prompt UI — its own plugin source throws
`LocalAuthException(uiUnavailable, "The current Activity must be a FragmentActivity.")` when it isn't, which
`pin_lock_screen.dart:42-52` swallows in an empty `try { ... } catch (_) {}`. This exactly reproduces "can't open
biometric prompt" on Android with zero visible error. The separate Settings-page "no biometric system currently"
message depends only on device/emulator hardware+enrollment state and can't be confirmed or refuted from source.

### Cluster H — Realtime — CONFIRMED (both original candidates simultaneously)
`devices_screen.dart`/`devices_controller.dart`/`device_repository_impl.dart` are pure one-shot `.select()`/
`.update()` calls; the only "refresh" is a manual re-fetch after the local user's own action. `grep -rn "channel\|
onPostgresChanges\|postgres_changes\|\.subscribe("  lib/` — zero real hits anywhere in the entire client (the
notifications bell polls every 30s, which is at least *something*; devices/security has neither poll nor realtime).
Independently, `grep -rln "supabase_realtime\|ALTER PUBLICATION" supabase/` returns nothing — no table in the
schema, not just `devices`, has ever been added to the realtime publication. Either gap alone explains the symptom;
both exist simultaneously.

### Cluster I — Logs & sessions — split verdict, more specific than any blind candidate
`sessions` table: zero `INSERT INTO public.sessions` in any of 139 migrations, no trigger, no RPC, no client write
path — the table was created (`20260609000002_auth_full_schema.sql:95-108`) and read via a `list-sessions` Edge
Function using the service-role client, but nothing has ever written to it. Confirmed dead write path (candidate a).
`audit_logs` table: a real write path exists — `AuditService.instance.log()` is called from 6 controllers
(sign-in, sign-up, auth, devices, reset, MFA). But `auth_remote_datasource.dart:159-165`'s insert never sets
`tenant_id`, and the RLS read policy `"audit tenant read"` (`tenant_id = auth_tenant_id()`) can never match a NULL
column — every inserted row becomes permanently invisible to every reader, though the INSERT itself succeeds. This
is a distinct bug (missing RLS-filter column on write) not cleanly matching any of the original 3 candidates.
Separately: SETTINGS-004 ("no session screen") is factually wrong as stated — `/sessions` and `/security-logs` are
both routed (`router.dart:290-296`) and linked from a visible Settings row gated only on `settings:read`.

### Cluster J — MFA screens — REFUTED, real gap is permission-gating
`mfa_enroll_screen.dart` and `mfa_challenge_screen.dart` exist and are correctly routed at `/mfa-enroll` /
`/mfa-challenge` (`router.dart:298-304`). An entry point exists: `settings_page.dart:265-271`'s "Authenticator app"
row. But reaching that page requires passing `settings_hub_page.dart:21-24`'s `PermissionGate(module: 'settings',
action: 'read')`, and the seeded CASHIER role (both the fixed Demo Store seed and the `handle_new_user()` trigger's
per-tenant CASHIER seed, `20260609000002_auth_full_schema.sql:196-204,246-253`) never grants `settings:read`.
CASHIER — the default role for self-signup without a business name — therefore has **zero** UI path to MFA
enrollment. Since the auto-challenge redirect (`workspace_init_screen.dart:69-71`) only fires for an account that
already has a verified factor, and no CASHIER account can ever enroll one through the UI, both the enrollment and
the challenge test cases fail for the same underlying reason on that role.

### Cluster K — Permissions — REFUTED as "nothing works", real gap is narrower
`PermissionGate` is used 146× across 78 files and is genuinely backend-driven off a real `permissions` table query
(`auth_remote_datasource.dart:103-109`), correctly RLS-scoped. Every named guard function
(`create_tenant_role`, `update_role_permissions`, `update_user_role`, `auth_can_grant_role`, `list_permission_catalog`,
`is_admin_role_name`) exists and is deployed, and the critical `users` UPDATE `WITH CHECK` policy pinning
`tenant_id`/`role_id` is present (`20260717123653_phase1_security_fixes.sql:48-56`). The actual gap: `role_form_page.dart`
is create-only (no `roleId` param, no edit path); role list cards in `roles_page.dart` have no `onTap` at all; no
route for editing an existing role's permissions exists in `router.dart`; and `update_role_permissions` — fully wired
in the datasource/repo layers — has zero call sites anywhere in `lib/`, making it dead/orphaned from the client side.
Separately, `permissionMatrixProvider` loads exactly once, at `workspace_init_screen.dart:103`, with no invalidation
path anywhere — so even a permission change made by some other means wouldn't propagate to an already-logged-in
session without a re-login.

---

## What changed from the original blind pass

The original document explicitly flagged its own limitation: "produced without repo access... every root cause
below is a hypothesis." That caveat turned out to matter in specific, non-obvious ways:

- Two "High confidence" clusters (A, J) were **wrong about the mechanism** despite guessing the right symptom area
  — both times because the blind pass assumed a feature was *missing* when it was actually *built and gated behind
  a permission the test account didn't have*. This is a recurring pattern worth watching for in any future blind
  triage on this codebase: RBAC gates are pervasive (146 `PermissionGate` call sites), so "feature X doesn't appear"
  is more often "role Y can't see feature X" than "feature X doesn't exist."
- Cluster G's guessed root causes (Info.plist, Android manifest permission) were both individually wrong, but the
  *category* of cause (native platform config) was right — the actual gap (`FlutterActivity` vs
  `FlutterFragmentActivity`) is one level more specific than either guess.
- Cluster I's candidates (dead insert / silent error / RLS blocks insert) didn't include the actual mechanism found
  for `audit_logs` — a write that succeeds but is filtered from every read because a tenant-scoping column was left
  NULL. This is a fourth failure mode the original taxonomy didn't anticipate.
- Clusters B, C, D1, E held up essentially as stated — these were all pure client-logic questions (branching logic,
  validation) with no backend/RBAC layer to obscure the mechanism, which is likely why blind reasoning from symptom
  text got them right.

No fixes were made or proposed in this pass. This document is the diagnosis update; next step (if any) is a separate
decision.
