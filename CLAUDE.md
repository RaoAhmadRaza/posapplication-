# CLAUDE.md — Lumina POS

Mode: caveman terse (see caveman skill). Full tech accuracy, zero fluff.
Normal prose ONLY for: code, comments, commits, PRs, security warnings, destructive-op
confirms, multi-step command order.

Scope of any task is set by the PROMPT, not this file. This file = durable conventions +
behavioral guardrails + lessons learned. No feature is permanently off-limits — the project is
built out fully over time, one vertical slice at a time.

---

## Working principles — read before every task
Behavioral guardrails. Bias toward caution over speed; for trivial tasks, use judgment.
These override nothing in the project sections below — they govern *how* you approach the work.

1. **Think before coding.** Don't assume, don't hide confusion, surface tradeoffs.
   - State assumptions explicitly. Uncertain → ask.
   - Multiple valid interpretations → present them, don't pick silently.
   - Simpler approach exists → say so, push back when warranted.
   - Unclear → stop, name what's confusing, ask.
   - NOTE: a sharp clarifying question is exempt from the no-preamble / terseness rule below —
     surfacing real ambiguity is always allowed and preferred over guessing wrong.

2. **Simplicity first.** Minimum code that solves the problem, nothing speculative.
   - No features beyond what was asked.
   - No abstractions for single-use code.
   - No "flexibility" / configurability that wasn't requested.
   - No error handling for impossible scenarios.
   - 200 lines that could be 50 → rewrite. Test: would a senior eng call this overcomplicated?
   - Reinforces §Dependencies: a few lines of own code > an unmaintained package.

3. **Surgical changes.** Touch only what the task needs; every changed line traces to the prompt.
   - Don't "improve" adjacent code, comments, or formatting.
   - Don't refactor what isn't broken. Match existing style even if you'd do it differently.
   - Notice unrelated dead code → mention it, don't delete it (unless asked).
   - Remove ONLY the orphans your change created (imports / vars / functions now unused).
   - Mirrors §Migrations: additive, no gratuitous DROP / RENAME.

4. **Goal-driven execution.** Turn the task into verifiable success criteria; loop until met.
   - This project's verification = `flutter analyze` clean + feature verified end to end.
     No formal test suite yet. Where a test exists (or you add one), use reproduce-then-fix:
     write a failing test that captures the bug/requirement, then make it pass.
   - "Add validation" → decide invalid inputs, exercise them, confirm they're rejected.
   - "Fix the bug" → reproduce it first, then confirm the fix kills the repro.
   - Multi-step task → state a brief plan with a verify check per step:
     ```
     1. [step] → verify: [check]
     2. [step] → verify: [check]
     3. [step] → verify: [check]
     ```
   - Strong criteria let you loop solo; weak criteria ("make it work") force re-clarification.

---

## Project
POS + ERP, multi-tenant SaaS. Flutter front (Windows + macOS + mobile). Supabase back
(Postgres + Auth + Storage). Built incrementally: working vertical slices over broad scaffold.

## Stack
- Flutter / Dart
- Riverpod — plain providers (NotifierProvider/Provider/StreamProvider), NO codegen / build_runner unless asked
- go_router
- supabase_flutter — app talks directly to Supabase (auth + DB + storage). No custom server;
  server-side or secret logic goes in a Supabase Edge Function.
- PostgreSQL (Supabase)

## Docs & context — read FIRST, every session
1. docs/PROJECT_STATE.md — source of truth for "where are we": build state, architecture,
   done features, known issues, what's next.
2. docs/DECISIONS.md — append-only log of decisions + why. Do NOT re-litigate settled ones.
Spec/reference (read ONLY the relevant section; never implement wholesale):
- DATABASE_SCHEMA.md (full schema), APP_WORKFLOW___Screens.md (screens/flows),
  LUMINA_POS_Master_Development_Pipeline__1_.md (module roadmap).
  NOTE: the Pipeline doc assumes an abandoned NestJS/Redis stack — Supabase supersedes its
  backend specifics (see DECISIONS.md). Treat it as feature intent, not implementation.

## Keep docs current — part of "done"
After EVERY task:
- Update the affected section of docs/PROJECT_STATE.md to match reality (files, feature status,
  issues). Keep it under 250 lines — trim stale detail, don't append endlessly.
- If the task made a decision (stack/schema/pattern/scope), append ONE dated line to docs/DECISIONS.md.
A task is NOT done until the docs reflect it.

## Architecture — clean architecture; mirror it per feature
Dependency chain (one direction, never backwards):
```
page → controller (Notifier) → use case → repository (abstract) → repository impl
     → remote datasource → supabase
```
- domain: entities, value objects, abstract repository, thin use cases (one call each)
- data: json models, ONE remote datasource holding ALL supabase calls for the feature,
  repository impl that maps SupabaseException/AuthException → typed failures
- presentation: controllers expose AsyncValue / a small custom state (NO UI in controllers);
  pages consume providers; reusable widgets hold no business logic
New feature = new lib/features/<f>/ mirroring domain/data/presentation. Reuse existing patterns
and widgets — inspect before writing (see §Working principles 2–3: reuse over invent, surgical).

## Structure
```
lib/
  main.dart            # init Supabase + platform-guarded desktop setup, runApp(ProviderScope)
  app.dart             # MaterialApp.router + light theme
  router.dart          # go_router + auth redirect (single source of truth)
  core/
    env.dart supabase.dart
    design/            # tokens (colors/typography/spacing/radius/shadows) + theme + shared widgets
    responsive/ error/ services/ widgets/
  features/<f>/
    domain/ (entities, value_objects, repositories, usecases)
    data/   (models, datasources, repositories)
    presentation/ (controllers, pages, widgets)
supabase/
  migrations/          # ordered, additive, idempotent .sql — the schema lives HERE, not just the cloud
  functions/           # Edge Functions (server-side / service_role logic)
```

## Backend & auth model
- Auth = Supabase Auth (auth.users) owns credentials, sessions, JWT, refresh. public.users is a
  PROFILE row, PK id → FK auth.users(id). Never store passwords in public.users.
- New users are provisioned by the handle_new_user trigger (tenant + roles + branch + permissions
  + assignment); Demo Store fixed UUIDs are the fallback tenant.
- Multi-tenant isolation via RLS using SQL helpers auth_tenant_id() and auth_role_name() — NOT the
  schema doc's SET LOCAL app.current_tenant_id pattern.
- RBAC: role → permissions(module, action, branch_scope, granted). App loads the matrix on login;
  gate UI with PermissionGate(module, action).

## Migrations
- Path supabase/migrations/. Create with `supabase migration new <name>` (timestamped, ordered).
- Idempotent: create ... if not exists, on conflict do nothing, drop policy if exists before
  create policy, guard enum creation with a DO/exception block.
- Additive — avoid DROP / RENAME / new NOT NULL on live columns; write a forward migration instead.
- Ship the table's indexes + RLS policies in the same migration. RLS via auth.uid()/helpers.

## Design system — clean iOS, light mode only
- Use lib/core/design tokens (AppColors / AppTypography / AppSpacing / AppRadius / AppShadows).
  No hardcoded colors, sizes, or radii in widgets.
- Aesthetic: clean native iOS, light mode only, accent #007AFF, SF typography, hairline
  separators, restrained shadows. No darkTheme, no gradients / neumorphism / glow.
- Reuse design-system components (AppButton, AppTextField, AppCard, AppOtpField, AppInlineBanner,
  ResponsiveFormScaffold). Build new shared components there, not inline in pages.
- Responsive: use LayoutBuilder / MediaQuery by width — never Platform.isX for layout (desktop
  windows resize). Full-screen backgrounds fill the body root, not a content-sized box.

## Routing
- go_router redirect is the SINGLE source of truth for auth/session navigation. Never navigate
  manually after an auth-state change — change state and let the redirect decide.
- refreshListenable merges supabase.auth.onAuthStateChange + flow flags (e.g. RecoveryState).
- Read login state synchronously via supabase.auth.currentSession; never gate the redirect on a
  loading async value, and ensure every route (incl. /splash) resolves under each auth state.

## Dependencies
- Justify every new package in the report. Prefer a few lines of own code over an unmaintained
  package for small visual effects (lesson: flutter_inset_box_shadow broke the build via a removed
  API). See §Working principles 2.
- Desktop-only plugins (window_manager, etc.) MUST be platform-guarded in main()
  (`!kIsWeb && defaultTargetPlatform == macOS/windows/linux`) or they crash iOS/Android at launch.

## Security
- anon / publishable key in the app = fine (RLS protects data). service_role key in the app = NEVER —
  put any service_role logic behind a Supabase Edge Function that verifies the caller's JWT.
- RLS on every table that holds tenant data; policies tenant-scoped via auth_tenant_id().
- audit_logs and other immutable tables: revoke update/delete from anon/authenticated.

## Commands
```bash
flutter pub get
flutter pub add <pkg>
flutter analyze            # run after EVERY change; fix before reporting done
flutter run                # -d macos | -d windows | -d chrome | <emulator>
supabase migration new <name>     # new ordered migration file
supabase db push                  # apply migrations to the linked project
supabase functions deploy <name>  # deploy an Edge Function
```

## Workflow — every task
1. Read PROJECT_STATE.md + DECISIONS.md (+ the relevant spec section). Check available skills; use if fit.
2. Plan terse; confirm the slice; inspect existing files; reuse patterns + widgets.
   State assumptions; ambiguity or multiple interpretations → ask BEFORE coding (§Working principles 1).
   Scope stays surgical — every changed line traces to the prompt (§3).
3. Write code (normal prose inside code, comments minimal). Simplest thing that works (§2).
4. `flutter analyze` → fix. Verify the feature end to end against your success criteria (§4).
5. Update docs; report: files changed + 1-line why each + run command.

## Subagents — if runtime supports
Delegate independent/parallel work, keep main context lean:
- generate migration files for a feature
- scaffold all pages of one feature in parallel
- doc/API lookup → return a summary only, never raw pages into main context
Main thread = integrate + verify. Never dump raw subagent output into the main context.

## Token economy
- Caveman terse for all chat/explanation. Drop articles, filler, hedging, pleasantries.
- No preamble ("Sure, I'll…"), no postamble, no restating the prompt.
  EXCEPTION: clarifying questions that surface real ambiguity (§Working principles 1) — always allowed.
- Report format: files changed + 1-line why each + run command. Nothing else.
- Don't paste whole files back — snippets/diffs only, unless asked.
- Resume normal prose where ambiguity or safety demands (see Mode line).

## Definition of done
`flutter analyze` clean + feature verified end to end + migrations committed under
supabase/migrations/ + docs/PROJECT_STATE.md and docs/DECISIONS.md updated + changed files listed.