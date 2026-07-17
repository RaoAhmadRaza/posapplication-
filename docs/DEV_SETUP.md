# Dev Setup — Lumina POS (for a second developer)

You're getting the **repo only**, not access to the production Supabase project. You'll spin up your own
free Supabase project, replay the full migration history into it, and get a fully working, independent
backend to test against. This is deliberate — see "Why not just share the Supabase project?" at the bottom
if you're wondering.

Everything below assumes macOS or Windows with Flutter already targetable (desktop + mobile). If `flutter
doctor` isn't clean yet, fix that first — nothing here will work around a broken Flutter install.

---

## 1. Prerequisites

Install these before anything else:

- **Flutter** 3.38.x (stable channel) — `flutter --version` should show `3.38.9` or close to it. This repo
  pins Dart SDK `^3.10.8` in `pubspec.yaml`; a much older Flutter won't resolve dependencies.
- **Supabase CLI** — `brew install supabase/tap/supabase` (macOS) or see
  https://supabase.com/docs/guides/cli/getting-started for other platforms. Version 2.x.
- **A free Supabase account** — https://supabase.com, sign up if you don't have one.
- **Xcode** (macOS builds) / **Android Studio + an SDK** (Android builds) — whichever platform you're
  actually testing on. Run `flutter doctor` and resolve every ✗ for your target platform before continuing.
- **Git** access to the repo (however it's being shared with you — GitHub invite, zip, etc.)

---

## 2. Get the code

```bash
git clone <the repo URL you were given>
cd pos_app
flutter pub get
```

If `flutter pub get` fails, stop here and report the exact error — don't try to work around it by changing
`pubspec.yaml` yourself. (There's a known pinned pre-release dependency, `file_picker`, explained in
§7 below — that one's expected and fine.)

---

## 3. Create your own Supabase project

1. Go to https://supabase.com/dashboard → **New project**.
2. Pick any name (e.g. `lumina-pos-dev-<yourname>`), any region close to you, set a database password
   (save it — you may need it later, though the CLI flow below doesn't require typing it interactively
   every time).
3. Wait for provisioning to finish (~2 minutes).
4. From the project's dashboard, grab two things (**Settings → API**):
   - **Project URL** (looks like `https://xxxxxxxxxxxx.supabase.co`)
   - **anon / public key** (a long JWT starting `eyJ...`) — NOT the `service_role` key, never use that
     one client-side.

---

## 4. Link the CLI to your project and push every migration

From the repo root:

```bash
supabase login          # opens a browser, authorizes the CLI once
supabase link --project-ref <your-project-ref>
```

`<your-project-ref>` is the subdomain part of your Project URL (e.g. if the URL is
`https://abcdefghijkl.supabase.co`, the ref is `abcdefghijkl`).

This will ask to overwrite the local `supabase/config.toml` project_id — say yes. That file currently
points at the shared dev's project; linking re-points it at yours locally (don't commit that change back
unless asked to).

Then push every migration in order:

```bash
supabase db push
```

This replays the **entire** migration history (`supabase/migrations/*.sql`, currently 100+ files) into your
fresh database — schema, RLS policies, seed functions, RPCs, the works. It'll prompt you to confirm the list
of migrations; say yes. This takes a minute or two. If any migration fails partway, stop and report the exact
error with the migration filename — don't try to hand-fix it in the SQL editor (see §8).

---

## 5. Bootstrap the 7 scheduled jobs (optional, but do it if you're testing sync/notifications/reports)

```bash
supabase db push
```

already applied `supabase/migrations/20260716181222_cron_bootstrap.sql`, which registers all 7 `pg_cron`
jobs (MV refresh, approvals escalation, reorder recommendations, report scheduling, notification detectors,
provisioning drift monitor, sync outbox drain). Nothing extra to do — just know they're now running on your
project too, on the same schedules as prod.

---

## 6. Point the app at your project

Edit `lib/core/env.dart`:

```dart
class Env {
  static const String supabaseUrl = 'https://YOUR-PROJECT-REF.supabase.co';
  static const String supabaseAnonKey = 'YOUR-ANON-KEY';
}
```

Both values are safe to put in source — the anon key is meant to be public (Row Level Security on every
table is what actually protects data, not key secrecy). **Do not commit this change** if you're pushing
back to the shared repo; keep it local, or work on a branch you don't merge.

---

## 7. Run the app

```bash
flutter run -d macos      # or -d chrome, or an Android emulator/device id from `flutter devices`
```

The Android release build needs one known thing: `file_picker` is pinned to `12.0.0-beta.7` in
`pubspec.yaml` (not a typo — see `docs/DECISIONS.md`, 2026-07-16 entries on file_picker, for the full
story). Leave it as-is; every stable version conflicts with other dependencies in a way that's been
investigated and isn't fixable by bumping/pinning something else.

For a debug run this doesn't matter; for `flutter build apk --release` it does — expect it to work as
pinned.

---

## 8. Create your first test tenant

There's no seed data in a fresh project — you start completely empty. Sign up through the app itself:

1. Launch the app, go to the sign-up screen.
2. Enter an email + password. You'll get an OTP code — Supabase's free tier sends this via its own shared
   email service by default, no SMTP config needed. **Gotcha**: that shared service is rate-limited (a
   handful of emails per hour) — if OTPs stop arriving, that's why; wait or check Supabase dashboard →
   Authentication → Users to manually confirm the account instead.
3. On first sign-up, a database trigger (`handle_new_user`) automatically creates your tenant and runs
   `provision_tenant()` — chart of accounts, number series, tax rules, a default branch/warehouse, payment
   methods, everything. You should land in a fully working, empty POS. Full detail on what gets seeded is
   in `docs/PROJECT_STATE.md` under "Tenant Provisioning."
4. From there: add a product or two (Inventory), then do a POS sale to sanity check the whole path.

---

## 9. Deploying Edge Functions (only if you're testing notifications/session-revoke)

`supabase/functions/` has three functions: `notification-sender`, `list-sessions`, `revoke-session`. They
aren't deployed automatically by `db push`. If you need them:

```bash
supabase functions deploy notification-sender
supabase functions deploy list-sessions
supabase functions deploy revoke-session
```

`notification-sender` needs provider secrets (Twilio/SendGrid/FCM) to actually send anything — without
them it's deployed but inert, which is also the current state on prod. Don't bother setting those up unless
you're specifically testing SMS/email/push delivery; the rest of the app doesn't depend on it.

---

## 10. Ground rules — read this before touching the Supabase dashboard

**Never hand-edit the database through the Supabase SQL editor.** Every schema change, every RPC change,
every cron job — all of it goes through a migration file:

```bash
supabase migration new <short_description>
# write your SQL into the generated file under supabase/migrations/
supabase db push
```

This isn't a style preference. Most of what got fixed in this codebase recently (see `docs/DECISIONS.md`,
every entry from 2026-07-16) existed *because* things got typed into the SQL editor by hand over time and
never made it into a migration file — meaning rebuilding the database from the repo alone silently produced
a broken or incomplete system. If you're testing on your own project, this matters less for prod safety,
but it still matters for you: it's the only way your changes are reproducible, reviewable, or portable back
to the team.

If you do need to poke at data directly for debugging, that's fine — just don't leave schema/function/cron
changes sitting only in the dashboard.

---

## 11. Where things actually live (orientation)

- `docs/PROJECT_STATE.md` — current state of every feature, what's done, what's known-broken. Read this
  first, it's the source of truth for "is X built."
- `docs/DECISIONS.md` — append-only log of every non-obvious decision and why, in date order. If something
  looks weird (a pinned pre-release dependency, a disabled toggle, a missing feature), search this file for
  the date/keyword before assuming it's a bug.
- `supabase/migrations/` — the entire schema and backend logic, in order. This is the actual source of
  truth for the database, not any diagram or spec doc.
- `supabase/functions/` — Edge Functions (server-side logic that needs a secret key, e.g. sending
  notifications).
- `lib/features/<name>/` — one folder per feature, each split into `domain/` (business logic, no Flutter
  imports), `data/` (Supabase calls, one datasource per feature), `presentation/` (pages/controllers/widgets).
- `lib/router.dart` — single source of truth for what route maps to what page. If you're trying to find a
  screen, grep here first, not by guessing folder names — some pages don't live where you'd expect (e.g.
  `dashboard_page.dart` and the top-level `settings_page.dart` both live under `lib/features/auth/`).

---

## Why not just share the Supabase project?

Short version: two people with dashboard access to one shared database is how the exact bugs fixed in this
codebase on 2026-07-16 happened in the first place (hand-typed SQL editor changes that never became
migrations, cron jobs that existed live but nowhere in the repo, a tenant provisioned mid-stream that
permanently missed schema updates issued after it). An independent project per developer means your testing
can't corrupt anyone else's data, your schema experiments can't drift from the migration history, and you
get to exercise the exact fresh-signup path a real new customer would hit — which is actually a *better*
test than poking at existing seeded data.
