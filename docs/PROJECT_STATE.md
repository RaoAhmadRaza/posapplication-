# PROJECT STATE — Lumina POS

Last updated: 2026-06-09

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
  router.dart                # 7 routes, auth redirect, RecoveryState guard
  core/
    env.dart / supabase.dart  # Supabase URL + key; global client singleton
    error/auth_failure.dart   # 9 sealed AuthFailures + RecoveryState singleton
    responsive/               # breakpoints + BuildContext.isMobile etc. (unused)
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
  features/auth/
    domain/
      entities/     auth_user.dart (unused), auth_profile.dart
      value_objects/ email_vo.dart (unused), password_vo.dart (unused)
      repositories/ auth_repository.dart (abstract) + SignUpResult, SignInResult
      usecases/     10 files: sign_in/up/out, verify_email/recovery_otp,
                    request/set_password, resend_code, load_profile, watch_state
    data/
      datasources/  auth_remote_datasource.dart (all Supabase calls)
      models/       auth_profile_model.dart (fromJson)
      repositories/ auth_repository_impl.dart (error mapping)
    presentation/
      controllers/  7 controllers: auth, sign_in/up, otp, forgot, reset, profile
      pages/        7 pages: splash, login, signup, otp, forgot, reset, home
```

## Auth Status — All Flows Working End to End

| Flow | Pages | Pattern |
|------|-------|---------|
| Signup with OTP confirm | Signup → OTP → Home | signUp → needsConfirmation → /otp → verifyOTP(signup) → router → /home |
| Signup without confirm | Signup → Home | signUp → session non-null → router → /home |
| Login | Login → Home | signInWithPassword → router → /home |
| Login (unconfirmed email) | Login → OTP → Home | EmailNotConfirmedFailure caught → route to /otp → verify → router |
| Forgot password | Forgot → OTP → Reset → Home | resetPasswordForEmail → /otp(isRecovery) → verifyOTP(recovery) → /reset → updateUser → /home |
| Logout | Home → Login | signOut → onAuthStateChange → router → /login |
| Session persistence | Splash → Home or Login | Router reads currentSession synchronously; no async gate |

All auth-driven navigation through go_router redirect — no manual post-auth context.go().

### Router (7 routes, single _redirect function)

| Route | Page | Guard |
|-------|------|-------|
| /splash | SplashPage | → /home if authed, /login if not |
| /login | LoginPage | → /home if authed |
| /signup | SignupPage | → /home if authed |
| /otp | OtpPage(email, isRecovery) | → /home if authed & not recovering |
| /forgot | ForgotPasswordPage | → /home if authed |
| /reset | ResetPasswordPage | Only when RecoveryState.isRecovering=true |
| /home | HomePage | → /login if not authed |

Redirect priority: Recovery > !loggedIn > loggedIn. refreshListenable merges onAuthStateChange + RecoveryState.

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

RLS uses `auth.uid()` via helper functions `auth_tenant_id()`/`auth_role_name()` in the
live project (the migration policy bodies use inline `auth.uid()` as the shipped version).

See DATABASE_SCHEMA.md for full schema reference.

## Known Issues / Dead Code

**Dead code (defined, zero callers):**
- `ServerErrorFailure` — defined but never instantiated
- `authStateProvider` (StreamProvider) — defined but no widget consumes it; router uses its own listener
- `cupertino_icons` package — in pubspec but no Cupertino widget/icon imported

**Minor:**
- `RecoveryState` lives in `core/error/auth_failure.dart` — semantically not a failure; works but misplaced
- `widget_test.dart` — smoke test, ProviderScope-wrapped; no test infrastructure beyond this
- Profile loaded once on mount (no pull-to-refresh)

## What's Next

See AUTH_COMPLETE_RUNBOOK.md for phased plan. Current phase: auth is complete and
functional. Next phases per the roadmap: POS/ERP feature modules, multi-tenant
hardening, desktop polish.
