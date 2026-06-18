# AUTH & SESSION AUDIT — Lumina POS

**Date:** 2026-06-18  
**Status:** READ-ONLY DIAGNOSIS. No code changes.  
**Scope:** Every persisted key, PIN lifecycle, lock behavior, auth-state-change map, edge cases.

---

## 1. EVERY PERSISTED KEY — SCOPE CLASSIFICATION

### 1.1 flutter_secure_storage Keys

| Key | Written (file:line) | Read (file:line) | Scope | Correct? | Risk |
|---|---|---|---|---|---|
| `pin_hash` | `pin_service.dart:25` | `pin_service.dart:17,36` | **DEVICE** | **WRONG — should be USER** | New user forced to enter old user's PIN |
| `pin_salt` | `pin_service.dart:24` | `pin_service.dart:37` | **DEVICE** | **WRONG — should be USER** | Same as pin_hash |
| `biometrics_enabled` | `pin_service.dart:61` | `pin_service.dart:56` | **DEVICE** | **WRONG — should be USER** | New user inherits biometrics pref |
| `device_uuid` | `device_service.dart:41` | `device_service.dart:38` | DEVICE | OK | Device fingerprint is device-scoped |
| `current_branch_id` | `branch_controller.dart:74,85,94,103` | `branch_controller.dart:87` | **GLOBAL** | **WRONG — should be USER** | New user may inherit wrong branch ID (cleared on switch in fix) |
| `login_attempts_<hash>` | `login_throttle_service.dart:50` | `login_throttle_service.dart:22` | USER (keyed by email hash) | OK | Cleared on successful login |
| `login_locked_<hash>` | `login_throttle_service.dart:58` | `login_throttle_service.dart:36` | USER (keyed by email hash) | OK | Cleared on successful login |

**No SharedPreferences, Hive, or local DB found.** All persistence is flutter_secure_storage only.

### 1.2 Supabase-Synced Keys

| Column | Table | Written (file:line) | Scope |
|---|---|---|---|
| `pin_hash` | `public.users` | `pin_service.dart:30` | PER-USER (server-side) — correct, but local `pin_hash` in secure storage is global |

The `setPin()` method writes the hash to BOTH local storage (global key `pin_hash`) and server (`public.users.pin_hash` for the current user). But `hasPin()` and `verifyPin()` only read from local storage. The server copy is a backup, never used for verification on this device.

---

## 2. PIN LIFECYCLE — THE BUG

### 2.1 Full PIN Service

`lib/core/services/pin_service.dart:1-73`

```dart
const _pinHashKey = 'pin_hash';      // line 8 — GLOBAL, not userId-scoped
const _pinSaltKey = 'pin_salt';      // line 9 — GLOBAL
const _biometricsKey = 'biometrics_enabled'; // line 10 — GLOBAL

// setPin: writes to local storage (global key) + server (for current auth.uid())
Future<void> setPin(String pin) async {
    await _storage.write(key: _pinSaltKey, value: salt);   // line 24 — local
    await _storage.write(key: _pinHashKey, value: hash);   // line 25 — local
    final userId = supabase.auth.currentUser?.id;
    if (userId != null) {
        await supabase.from('users').update({'pin_hash': hash}).eq('id', userId); // line 30 — server
    }
}

// hasPin: reads ONLY from local storage — NO userId check
Future<bool> hasPin() async {
    final hash = await _storage.read(key: _pinHashKey);  // line 17
    return hash != null && hash.isNotEmpty;
}

// verifyPin: reads ONLY from local storage — verifies against GLOBAL hash
Future<bool> verifyPin(String pin) async {
    final hash = await _storage.read(key: _pinHashKey);  // line 36
    final salt = await _storage.read(key: _pinSaltKey);  // line 37
    ...
    return _hash(pin, salt) == hash;
}

// clearPin: deletes local + server for CURRENT user
Future<void> clearPin() async {
    await _storage.delete(key: _pinHashKey);   // line 43
    await _storage.delete(key: _pinSaltKey);   // line 44
    await _storage.delete(key: _biometricsKey); // line 45
    final userId = supabase.auth.currentUser?.id;
    if (userId != null) {
        await supabase.from('users').update({'pin_hash': null}).eq('id', userId); // line 50
    }
}
```

### 2.2 The Reported Bug — Trace

1. **User A** sets a PIN → `pin_hash` = `hash(A's_pin, A's_salt)` stored at global key `pin_hash`
2. **User A signs out** → `signOut()` calls `resetUserScopedState()` which clears `current_branch_id` but does NOT clear `pin_hash`/`pin_salt`/`biometrics_enabled` (intentionally — these are not cleared)
3. **User B logs in** → session created, workspace init runs, profile loaded for User B
4. App goes to background, returns to foreground → `app.dart:29` triggers `_checkPinLock()`:
   ```dart
   // app.dart:34-38
   Future<void> _checkPinLock() async {
       final hasPin = await PinService.instance.hasPin(); // ← reads GLOBAL 'pin_hash' key
       if (hasPin && mounted) {
           PinLockState.instance.lock();   // ← LOCKS screen
       }
   }
   ```
5. `hasPin()` returns `true` because User A's `pin_hash` is still in local storage
6. Router redirects to `/pin-lock` → User B is asked for a PIN they NEVER set
7. If User B enters ANY PIN → `verifyPin()` compares against User A's hash → fails
8. After 3 failures → `pin_lock_screen.dart:74-75`: `PinService.instance.clearPin()` → deletes User A's pin from BOTH local storage and server (via `clearPin()` line 50 which updates `users.pin_hash = null` for the CURRENT userId — User B!)
9. User B is unlocked but User A's server PIN may OR MAY NOT be cleared (it clears for `auth.uid()` which is User B, so User A's server PIN is preserved — but User A can't recover it locally because the local hash was deleted)

### 2.3 Biometric Bug — Same Root Cause

`pin_lock_screen.dart:29-39`:
```dart
Future<void> _checkBiometrics() async {
    final canCheck = await _localAuth.canCheckBiometrics;
    final enabled = await PinService.instance.isBiometricsEnabled(); // ← reads GLOBAL 'biometrics_enabled'
    if (mounted) {
        setState(() => _showBiometrics = canCheck && enabled);
    }
}
```

User B inherits User A's biometric toggle. If User A enabled Face ID, User B sees "Use Face ID / fingerprint" on the lock screen. **Biometric unlock via OS-level local_auth is not user-scoped** — it authenticates the DEVICE owner, not the app user.

The Settings page toggle (`settings_page.dart:205-206`) also reads the global key:
```dart
final biometricsOn = hasPin ? await PinService.instance.isBiometricsEnabled() : false;
```

---

## 3. PIN-LOCK / APP-LOCK ON OPEN & CLOSE

### 3.1 Lifecycle Observer

`lib/app.dart:14-39`:

```dart
class _AppState extends State<App> with WidgetsBindingObserver {
    @override
    void didChangeAppLifecycleState(AppLifecycleState state) {
        if (state == AppLifecycleState.resumed) {
            _checkPinLock();
        }
    }

    Future<void> _checkPinLock() async {
        final hasPin = await PinService.instance.hasPin();  // line 35
        if (hasPin && mounted) {
            PinLockState.instance.lock();                     // line 37
        }
    }
}
```

### 3.2 Lock Decision Flow

1. App resumes from background → `_checkPinLock()` is called
2. **Decision is NOT user-aware** — `hasPin()` reads the global `pin_hash` key
3. If ANY user ever set a PIN on this device, ALL subsequent users get locked
4. There is no check like "does the CURRENT user have a PIN?" vs "does this device have a PIN?"
5. `PinLockState.instance` is a singleton — when locked, ALL routes redirect to `/pin-lock`:
   ```dart
   // router.dart:97-99
   if (PinLockState.instance.locked) {
       return loc == '/pin-lock' ? null : '/pin-lock';
   }
   ```

### 3.3 Fresh Login + No PIN Scenario

**Question:** User B logs in fresh, never set a PIN → should there be NO lock?

**Answer:** After login, `PinLockState._locked` is `false` (not locked). The user is not immediately locked. The lock ONLY triggers on app resume (`AppLifecycleState.resumed`). But:

- If the app is backgrounded and resumed → `_checkPinLock()` → `hasPin()` = true → LOCK
- If the user manually locks the device but never backgrounds the app → no lock
- The lock is NOT enforced on initial login — only on resume

**This means the reported bug manifests on app resume, not immediately after login.**

---

## 4. FULL onAuthStateChange MAP (post-fix)

`lib/router.dart:55-73`:

```dart
class _GoRouterRefreshStream extends ChangeNotifier {
  String? _lastUid;

  _GoRouterRefreshStream() {
    _lastUid = supabase.auth.currentUser?.id;
    supabase.auth.onAuthStateChange.listen((event) {
      final newUid = event.session?.user.id;
      final eventName = event.event.name;

      if (newUid != _lastUid || eventName == 'SIGNED_OUT') {
        // RESETS: WorkspaceInitState, MfaState, BranchRouterState, current_branch_id
        debugPrint('[AUTH-LIFECYCLE] user changed: $_lastUid -> $newUid ($eventName)');
        _lastUid = newUid;
        BranchRouterState.instance.reset();
        resetUserScopedState();
        Future.microtask(() => notifyListeners());
      } else {
        notifyListeners();  // Token refresh, same user → just re-evaluate redirect
      }
    });
  }
}
```

### 4.1 Per-Event Behavior Matrix

| Event | newUid vs _lastUid | Reset fires? | What happens |
|---|---|---|---|
| `INITIAL_SESSION` (null→A) | A != null | YES | `reset()` + clear branch storage + redirect |
| `SIGNED_IN` (A→B, account switch) | B != A | YES | Full reset + redirect |
| `SIGNED_IN` (null→A, first login) | A != null | YES | Full reset + redirect |
| `SIGNED_OUT` (A→null) | — (name check) | YES | `reset()` + clear branch + redirect to /login |
| `TOKEN_REFRESHED` (A→A) | A == A | NO | `notifyListeners()` only — no reset |
| `USER_UPDATED` (A→A) | A == A | NO | `notifyListeners()` only — no reset |
| `PASSWORD_RECOVERY` | sessions may vary | depends | Handled by RecoveryState in `_redirect()` |

### 4.2 What `resetUserScopedState()` Clears (app_flow_state.dart:93-101)

```
WorkspaceInitState.instance.reset()     → _completed = false
MfaState.instance.reset()               → _needsMfa = false
_storage.delete(key: _branchIdKey)      → clears current_branch_id
```

### 4.3 What `resetUserScopedState()` Does NOT Clear (INTENTIONAL GAPS)

| Key | Why not cleared |
|---|---|
| `pin_hash` / `pin_salt` | NOT cleared — PIN is device-scoped (bug: should be user-scoped) |
| `biometrics_enabled` | NOT cleared — biometrics is device-scoped (bug: should be user-scoped) |
| `device_uuid` | NOT cleared — device fingerprint, correct to persist |
| `login_attempts_*` / `login_locked_*` | NOT cleared — email-keyed, already correct |

---

## 5. DEVICE REGISTRATION + TRUSTED DEVICES + ACTIVE SESSIONS

### 5.1 device_uuid — Device-Scoped (Correct)

`lib/core/services/device_service.dart:37-43`:
```dart
Future<String> _getOrCreateUuid() async {
    var uuid = await _storage.read(key: _deviceUuidKey);  // global key 'device_uuid'
    if (uuid == null || uuid.isEmpty) {
        uuid = _generateUuid();
        await _storage.write(key: _deviceUuidKey, value: uuid);
    }
    return uuid;
}
```

The device UUID is generated once per app install and reused. When `registerDevice()` is called for a new user, it upserts into `public.devices` on conflict `fingerprint_hash`:
```dart
// device_service.dart:25-34
await supabase.from('devices').upsert({
    'tenant_id': tenantId,
    'user_id': userId,
    ...
    'fingerprint_hash': fingerprintHash,
}, onConflict: 'fingerprint_hash');
```

If User A and User B share the same device, the device row gets UPDATED (via upsert on fingerprint_hash) — User B's userId/tenantId overwrite User A's. This is **by design** for a single-device-per-physical-device model, but could be confusing if User A's "trusted" status was previously revoked.

### 5.2 Devices Screen — RLS-Scoped by Tenant

`auth_remote_datasource.dart:117-121`:
```dart
Future<List<Map<String, dynamic>>> loadDevices() async {
    final list = await _client.from('devices')
        .select('id, device_name, device_model, os_info, trust_level, authorized, ...')
        .order('last_seen_at', ascending: false);
    return List<Map<String, dynamic>>.from(list);
}
```

RLS policy in migration `20260609000002_auth_full_schema.sql:163-170`:
```sql
create policy "devices tenant read" on public.devices for select to authenticated
    using (tenant_id = public.auth_tenant_id());
```

**Verdict: Devices are correctly tenant-scoped via RLS.** User B cannot see User A's devices because they belong to different tenants. But on the SAME device, the fingerprint_hash upsert creates a shared row — within the new user's tenant, the device appears with the new user's userId.

### 5.3 Sessions Screen

`session_remote_datasource.dart:12-16`:
```dart
Future<List<Map<String, dynamic>>> listSessions() async {
    final res = await _client.functions.invoke('list-sessions');  // Edge Function
    final data = res.data as Map<String, dynamic>;
    final sessions = data['sessions'] as List<dynamic>? ?? [];
    return sessions.cast<Map<String, dynamic>>();
}
```

Uses an **Edge Function** (`list-sessions`) which runs with `service_role` — it can see ALL sessions. The Edge Function implementation determines scoping. If it's scoped by tenant, sessions are correctly isolated. If it returns all sessions, there's a privacy leak.

**This is a potential concern** — the app `revokeSession` also goes through an Edge Function (`revoke-session`). These functions' implementations are NOT in the client codebase and should be audited separately.

---

## 6. MFA / TOTP

### 6.1 MfaState — Singleton, Now Reset on User Change

`lib/core/state/app_flow_state.dart:65-91` — `MfaState` singleton. After the fix, `resetUserScopedState()` calls `MfaState.instance.reset()` on user change.

### 6.2 MFA Decision — Per-User from Server

`lib/core/services/mfa_service.dart:56-61`:
```dart
bool needsAal2() {
    final res = supabase.auth.mfa.getAuthenticatorAssuranceLevel();
    if (res.currentLevel == null || res.nextLevel == null) return false;
    return res.currentLevel!.name == 'aal1' && res.nextLevel!.name == 'aal2';
}
```

This reads the AAL from the **current Supabase session's JWT** — not from a cached singleton. So User B's session correctly determines whether MFA is required.

### 6.3 MFA Challenge Flow

`mfa_challenge_screen.dart:30-36`:
```dart
Future<void> _startChallenge() async {
    final factorId = await MfaService.instance.getEnrolledFactorId();
    if (factorId == null) {
        MfaState.instance.clear();     // No MFA enrolled → clear flag → proceed
        return;
    }
    ...
}
```

On user change, `MfaState.reset()` forces re-evaluation. The workspace init redirect then calls `needsAal2()`, which reads the new user's session. Correct behavior.

---

## 7. LOGIN THROTTLE

### 7.1 Keys — Email-Scoped (Correct)

`login_throttle_service.dart:17`:
```dart
String _key(String email, String prefix) => '$prefix${_hash(email)}';
```

Keys: `login_attempts_<base64(email)>` and `login_locked_<base64(email)>`. One set per email, globally.

### 7.2 Clear Timing

- On successful login: `sign_in_controller.dart:46` → `LoginThrottleService.instance.reset(email)` — clears local attempts + calls server RPC `reset_failed_login`
- On failure: `recordFailure(email)` increments local counter + calls server RPC `increment_failed_login` which can lock the account server-side

**Verdict: No cross-user leak.** Each email has independent counters.

---

## 8. WHAT SIGN-OUT / SIGN-IN ACTUALLY DO (post-fix)

### 8.1 signOut()

`auth_controller.dart:17-22`:
```dart
Future<void> signOut() async {
    AuditService.instance.log(action: 'LOGOUT', entity: 'auth');
    BranchRouterState.instance.reset();
    await resetUserScopedState();                     // clears branch storage, resets WorkspaceInitState + MfaState
    await ref.read(signOutUseCaseProvider).call();    // supabase.auth.signOut()
}
```

### 8.2 What signOut Leaves Behind (POST-FIX)

| Item | Cleared? | File:Line |
|---|---|---|
| Supabase session | YES | `auth_remote_datasource.dart:54` |
| `current_branch_id` (secure storage) | YES | `app_flow_state.dart:98` (via `resetUserScopedState`) |
| `WorkspaceInitState._completed` | YES | `app_flow_state.dart:31-33` (via reset) |
| `MfaState._needsMfa` | YES | `app_flow_state.dart:82-86` (via reset) |
| `BranchRouterState._loaded/_count` | YES | `branch_controller.dart:41-48` (via reset) |
| `profileControllerProvider` state | NO | Stays in memory, but router will force `/workspace-init` on next login (because `_completed=false`) |
| `permissionMatrixProvider` state | NO | Same as above — will be reloaded by workspace init |
| `userBranchesProvider` state | NO | Same |
| `currentBranchProvider` state | NO | Same |
| `pin_hash` / `pin_salt` | **NO** | **Should be cleared?** Currently device-scoped intentionally |
| `biometrics_enabled` | **NO** | **Should be cleared?** Currently device-scoped intentionally |
| `device_uuid` | NO | Correct — device-scoped |

### 8.3 Login Flow (post-fix)

1. `supabase.auth.signInWithPassword()` → session created
2. `_GoRouterRefreshStream` fires with `newUid != _lastUid` → `resetUserScopedState()` + `BranchRouterState.reset()`
3. Router evaluates redirect: `WorkspaceInitState.completed == false` → redirects to `/workspace-init`
4. `WorkspaceInitScreen._triggerLoads()` → `profile.load(newUserId)` → profile loaded for NEW user
5. `ref.listen(profileControllerProvider)` triggers `permissionMatrixProvider.notifier.load(newRoleId)`
6. `userBranchesProvider.notifier.load(newUserId)` → loads branches for NEW user
7. `BranchRouterState.onBranchesLoaded()` → sets new branch count
8. `WorkspaceInitState.completed = true` → router redirects to `/dashboard`

---

## 9. EDGE-CASE MATRIX

| Edge Case | Answer | File:Line Evidence |
|---|---|---|
| **New user on device with old user's PIN → wrongly demands old PIN?** | **YES** | `pin_service.dart:17` — `hasPin()` reads global `pin_hash` key, no userId. `app.dart:35-37` — triggers lock on any `hasPin`. |
| **New user inherits old user's biometric-enabled state?** | **YES** | `pin_service.dart:56` — `isBiometricsEnabled()` reads global `biometrics_enabled` key. `pin_lock_screen.dart:34` — uses this to show biometric button. |
| **New user inherits old user's selected branch?** | **FIXED** (post-fix) — NO | `app_flow_state.dart:98` — `resetUserScopedState()` deletes `current_branch_id`. `_GoRouterRefreshStream` triggers on user change. |
| **Two users, one device: can User B act within User A's tenant?** | **NO** | RLS enforces `tenant_id = auth_tenant_id()` on all tenant-scoped tables. New session → new auth.uid() → new auth_tenant_id() → isolated. |
| **App killed + reopened while logged in as B → restores B?** | **YES** | Supabase persists session in native secure storage. On restart, `supabase.auth.currentSession` has B's session. |
| **Token refresh while backgrounded → no state loss?** | **YES** | `_GoRouterRefreshStream` skips reset when `newUid == _lastUid`. Only `notifyListeners()` fires. |
| **Logout → login different user → zero residue from previous?** | **PARTIAL** | Provider state, branch storage, workspace init, MFA — all cleared/reset. BUT `pin_hash`, `pin_salt`, `biometrics_enabled` — NOT cleared. |
| **User A sets PIN/biometric, User B never set one → User B should have NONE** | **FAILS** | `hasPin()` returns true (reads User A's hash). User B gets locked. `_showBiometrics` = true (reads User A's toggle). |

---

## 10. PRIORITIZED FIX LIST

### CRITICAL (User Impact)

| # | Issue | Fix |
|---|---|---|
| 1 | PIN keys are global — User B locked by User A's PIN | Namespace as `pin_hash_<uid>`, `pin_salt_<uid>`, `biometrics_enabled_<uid>`. Update `hasPin()`, `verifyPin()`, `setPin()`, `clearPin()`, `isBiometricsEnabled()`, `setBiometricsEnabled()` to read/write per-UID. |
| 2 | Lock decision is not user-aware | `app.dart:35` — `_checkPinLock()` should call `PinService.instance.hasPin()` with the current `userId`. |
| 3 | PIN clear on 3 failures clears for wrong user | `pin_lock_screen.dart:74-75` — `clearPin()` clears local + server for current `auth.uid()`, which is correct post-login but useless if the lock screen fires before the new user signed in. Combine with fix #1. |

### HIGH (Latent Risk)

| # | Issue | Fix |
|---|---|---|
| 4 | `biometrics_enabled` key is global | Namespace per userId (same as fix #1). |
| 5 | Sessions visible to wrong user via Edge Function | Audit `list-sessions` / `revoke-session` Edge Function implementations for tenant scoping. |
| 6 | Device upsert on fingerprint_hash overwrites previous user's device record | Consider userId-scoping the device registration instead of fingerprint_hash-only upsert. |

### LOW (Correct but Worth Noting)

| # | Issue | Fix |
|---|---|---|
| 7 | `pin_hash` synced to server but never reconciled on login | On workspace init, after profile loads, compare `public.users.pin_hash` with local `pin_hash`. If different → clear local and re-prompt. |
| 8 | `RecoveryState` is a singleton, never reset on auth change | `RecoveryState.instance.stage` could leak between users. Add `RecoveryState.instance.reset()` to `resetUserScopedState()`. |

---

## 11. KEY TABLE — PERSISTED KEYS AND SCOPE

| Key | Current Scope | Correct Scope | Fix Type |
|---|---|---|---|
| `pin_hash` | **DEVICE** | USER | Namespace per UID |
| `pin_salt` | **DEVICE** | USER | Namespace per UID |
| `biometrics_enabled` | **DEVICE** | USER | Namespace per UID |
| `device_uuid` | DEVICE | DEVICE | None — correct |
| `current_branch_id` | USER (cleared on switch) | USER | Already cleared post-fix |
| `login_attempts_*` | USER (keyed by email) | USER | None — correct |
| `login_locked_*` | USER (keyed by email) | USER | None — correct |
