# UI Reskin Playbook

How to reskin any module (or the whole app) when a design export/zip is provided (e.g. a
Claude-Design or Figma export). Derived from the LUMINA design-system reskin of the auth module
(2026-07-20 — 17 screens, full light+dark, zero backend touch). Follow this end-to-end for any
future "reskin X using this design" task. Deviate only if the task prompt says otherwise.

Applies CLAUDE.md's "Frontend/UI-only tasks — hard boundary": this whole playbook stays inside
`lib/features/*/presentation/` and `lib/core/design/`. Never touch controllers, use cases,
repositories, datasources, models, domain, router.dart redirect/routes, or supabase/.

---

## 0. Guardrails before touching anything

- Confirm the task is UI-only. If the design implies a data/flow change (new field, new screen
  needing a new route, new controller state), STOP and ask — don't silently expand scope.
- If CLAUDE.md doesn't already have the "Frontend/UI-only tasks — hard boundary" section, add it
  first (or confirm it's present). It's the contract that makes reskins safe to do fast.

## 1. Locate + inventory the design export

- Unzip into a **scratchpad** location, NOT the repo (e.g.
  `/private/tmp/claude-*/.../scratchpad/<name>_design/`). The export is reference material, not
  importable Flutter code — never `import` or copy its JS/JSX/CSS into `lib/`.
- Inventory what's inside before reading anything in depth:
  - `tokens/*.css` (or `.json`) — colors, typography, spacing, radius, elevation, motion.
  - `src/*.jsx|.tsx` — component specs (foundation/primitives) + per-screen specs.
  - `readme.md` — design philosophy, icon system, scoping rules (what's decorative vs universal —
    e.g. gradients/glassmorphism might be scoped to hero/splash only, not general chrome).
  - Brand assets (SVG logos, icon sets).
- Note line counts of screen spec files to plan read order (small files first, skip huge demo
  "harness" files that are just component playgrounds, not real screens).

## 2. Extract design tokens

Read every token file in full and map each to its Flutter destination BEFORE writing code:

| Token source | Flutter destination |
|---|---|
| colors.css | `lib/core/design/app_colors.dart` (+ a ThemeExtension if dark mode is in scope) |
| typography.css | `lib/core/design/app_typography.dart` |
| spacing.css | `lib/core/design/app_spacing.dart` |
| radius (often in spacing.css or its own file) | `lib/core/design/app_radius.dart` |
| elevation.css | `lib/core/design/app_shadows.dart` (+ a custom painter if it needs true inset shadows) |
| motion.css | `lib/core/design/app_motion.dart` |
| fonts.css | `pubspec.yaml` fonts block + `assets/fonts/` |

Write down exact values (hex codes, px scales, font weights) verbatim — don't approximate.

## 3. Gap-analyze current code against the spec

- List every existing file under `lib/core/design/` (tokens + `widgets/`).
- Read each one and diff against the extracted tokens: what's outdated (wrong palette, no dark
  mode, wrong fonts, ColorScheme.fromSeed instead of an explicit theme)?
- Read the design's primitive-component spec (usually `foundation.jsx` or similar) — it's the
  most authoritative single file for how Button/Input/Card/Scaffold/etc. should look and behave.
- From the gap list, decide the implementation order (see §5) and flag any breaking API risk
  early — e.g. an existing widget variant enum that doesn't exist in the new spec (map it, don't
  silently drop pages that use it), or an icon API mismatch (IconData vs named icon strings).

## 4. Source fonts (if the design uses custom typography)

- Try the font's official distributor first (e.g. Fontshare API for Clash Display/Satoshi) — curl
  the family zip directly, extract TTFs from the `WEB/fonts/` (or equivalent) subfolder.
- **Gotcha**: Google Fonts' `fonts.google.com/download?family=...` URL returns the web UI HTML
  page when curled, not a zip. If a font is only on Google Fonts, get it from the project's
  **GitHub releases** instead (e.g. `github.com/<foundry>/<font>/releases/download/vX/....zip`).
- Copy all required weights into `assets/fonts/`, register them under `flutter.fonts` in
  `pubspec.yaml` (replace any placeholder/commented-out font block — don't leave it stacked).

## 5. Implementation order — tokens → primitives → widgets → pages

Always in this order; each layer depends on the one before it:

1. **Tokens**: AppColors → AppSpacing → AppRadius → AppShadows → AppMotion → AppTypography.
   If dark mode is in scope, build the color layer as a `ThemeExtension` (e.g. `LumColors`) read
   via a `BuildContext` getter (e.g. `context.lum`), not just static constants.
2. **Custom painters** for anything Flutter's `BoxShadow`/`Decoration` can't natively express
   (e.g. true CSS-style inset shadows for claymorphism) — build this before any widget that needs
   it. Keep it hand-rolled; don't reach for an unmaintained shadow/shimmer package (see
   CLAUDE.md §Dependencies — `flutter_inset_box_shadow` broke the build once).
3. **Shared widgets** (`lib/core/design/widgets/`): rewrite in spec order, e.g. Button → TextField
   → Card → InlineBanner → OtpField → FormScaffold. Keep every public API (constructor params,
   enums) **unchanged** so existing feature pages keep compiling untouched.
4. **New primitives** the design needs that don't exist yet (brand glyph/wordmark, hero scaffold,
   theme toggle, checkbox, etc.) — build once in `core/design/`, reused by every page.
5. **Pages last** — reskin the widget tree only. Controller/provider/route bindings must stay
   byte-identical. For a module with many screens, fan out screen-by-screen reskins across
   parallel subagents once the shared layer is done and stable — each one only touches its own
   page file(s), each verified independently with `flutter analyze`.

## 6. Backward-compatibility pattern

- Never do a big-bang rename of a widely-used token/widget name. Instead:
  - Keep the old static class/constant available (e.g. `AppColors` stays as a light-only static
    class) for any code not yet migrated.
  - Add the new theme-aware API alongside it (e.g. `LumColors` ThemeExtension + `context.lum`).
  - For renamed scale values (e.g. `AppRadius.card` changing from 14→22), keep the **old name**
    but point it at the **new value** — call sites don't need to change, only the constant.
- This lets shared-widget rewrites land without a single call site across 12+ features breaking.

## 7. Verification

- `flutter analyze` after every file, not just at the end — catch drift immediately.
- Run on **native desktop/mobile** (`flutter run -d macos` / a simulator), not Flutter web, for
  visual checks — headless-Chrome/CanvasKit screenshot capture is unreliable (WASM init can
  exceed a scripted virtual-time-budget and yield a blank frame).
- If screenshot tooling is blocked in the agent's environment (e.g. macOS screen-recording
  permission denied), say so explicitly in the report — don't claim visual verification that
  didn't happen. Get at least one screen manually eyeballed by the user/device where possible.
- Respect OS reduce-motion for any new animation (breathing glows, shimmer, elastic pop-ins) —
  provide a static fallback.

## 8. Docs — part of "done"

- `docs/PROJECT_STATE.md`: add/update a dated "UI Redesign — <name> (IN PROGRESS / DONE)" section
  tracking layers completed (foundation/tokens, primitives, per-screen rollout) and any owed
  verification (e.g. "visual eyeball owed — agent env can't screenshot").
- `docs/DECISIONS.md`: one dated line per real decision made during the reskin (e.g. dark-mode
  strategy, claymorphism approach, font source fallback) — not a narration of every file touched.
