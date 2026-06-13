# AUTH COMPLETE RUNBOOK — Lumina POS

Built as-of 2026-06-11. Records the auth module phased build plan and what shipped.

## Phase 0 — Foundation (complete)
- Init migration: tenants, roles, users, Demo Store seed, handle_new_user trigger
- Signup provisioning: business_name → new tenant as ADMIN; fallback → Demo Store CASHIER
- Auth full schema: branches, permissions (ADMIN 36 / CASHIER 6), devices, sessions, MFA configs, immutable audit_logs; RLS helpers + policies
- OTP retry fix, RecoveryStage enum hardening, forgot-password flow

## Phase 1 — RBAC + Entry Screens + PIN + MFA (complete)
- RBAC: Permission entity, permissionMatrixProvider (Set of "module:action"), canProvider, PermissionGate
- Branch support: loadUserBranches, currentBranchProvider, BranchRouterState → router redirect
- Entry screens: /env-check (internet + session), /workspace-init (profile + perms + branches + device reg)
- PIN: PinService (sha256 + salt), PinSetupScreen, PinLockScreen, biometric unlock, app-lock on resume
- MFA: MfaService (enroll/challenge/verify/unenroll), MfaEnrollScreen, MfaChallengeScreen, MfaState
- Home screen: ProfileCard + Security card (biometric toggle, authenticator)

## Phase 2 — Security UI + Lockout (complete)
- Home Security & Admin section: always-visible AppCard with PIN, biometric, authenticator, devices, sessions, security-log rows; admin rows PermissionGate-gated; MFA catch-22 fixed
- Server-side brute-force: RPCs increment_failed_login / reset_failed_login; account locked after 5 failures (15 min); AccountLockedFailure surfaced in login UI; local secure-storage throttle retained

## Phase 3 — Clean Architecture Refactor (complete)
- Devices: DeviceRepository + impl → LoadDevices/ApproveDevice/RevokeDevice use cases → controller no longer calls datasource directly
- Sessions: SessionRemoteDataSource (Edge Function wrapper) → SessionRepository → ListSessions/RevokeSession use cases → SessionsController → ConsumerStatefulWidget screen
- Security Logs: loadAuditLogs in auth_remote_datasource → AuditLogRepository → LoadAuditLogs use case → SecurityLogsController → ConsumerStatefulWidget screen
- Router-driven nav: removed manual context.go() after state changes from MfaChallengeScreen, PinLockScreen, BranchSelectPage; pin-setup keeps explicit nav (no gate covers it)

## Phase 4 — Polish + Docs (complete)
- Profile double-load removed: _ProfileCard reads existing state, only loads if empty/error
- Audit service: debugPrint on failure + one retry, still non-blocking
- Orphaned authStateProvider + watch_auth_state use case deleted
- PROJECT_STATE.md reconciled: 18 routes, correct redirect priority, file inventory updated
- This runbook created

## Router — 18 Routes

| Path | Page | Gate |
|------|------|------|
| /splash | SplashPage | waitingRoutes → /home |
| /env-check | EnvironmentCheckScreen | Sticky if !EnvCheckState.passed |
| /login | LoginPage | authRoutes |
| /signup | SignupPage | authRoutes |
| /otp | OtpPage | authRoutes + sticky awaitingCode |
| /forgot | ForgotPasswordPage | authRoutes |
| /reset | ResetPasswordPage | Sticky if codeVerified |
| /branch-select | BranchSelectPage | Sticky if needsSelection |
| /workspace-init | WorkspaceInitScreen | Sticky if !completed && !needsMfa |
| /pin-lock | PinLockScreen | Sticky if PinLockState.locked |
| /pin-setup | PinSetupScreen | waitingRoutes → /home |
| /devices | DevicesScreen | Authenticated + PermissionGate |
| /security-logs | SecurityLogsScreen | Authenticated + PermissionGate |
| /sessions | SessionsScreen | Authenticated + PermissionGate |
| /mfa-challenge | MfaChallengeScreen | Sticky if MfaState.needsMfa |
| /mfa-enroll | MfaEnrollScreen | Authenticated |
| /home | HomePage | Proceed |

Redirect priority: codeVerified > awaitingCode > env_check > !loggedIn > pin_locked >
needsSelection > workspace_init > needsMfa > waitingRoutes → /home > proceed.

## Auth Flow Trace

splash → env-check (passed) → login → workspace-init (profile+perms+branches+device)
→ home. MFA challenge between workspace-init and home if aal2 required. Branch-select
between login and home if multi-branch. PIN lock on resume.

## Supabase Migrations

| File | Contents |
|------|----------|
| 20260609000000_init.sql | tenants, roles, users, Demo Store, handle_new_user trigger v1 |
| 20260609000001_signup_provisioning.sql | business_name → new tenant ADMIN; fallback CASHIER |
| 20260609000002_auth_full_schema.sql | branches, permissions, devices, sessions, MFA configs, audit_logs, RLS helpers, seed matrix |
| 20260611000000_failed_login_rpc.sql | increment_failed_login / reset_failed_login RPCs |

## Edge Functions

- `list-sessions`: Admin-only, tenant-scoped session listing via service_role
- `revoke-session`: Admin-only, global sign-out + session status update via service_role
