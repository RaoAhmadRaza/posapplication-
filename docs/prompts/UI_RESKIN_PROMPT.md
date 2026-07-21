# Universal UI reskin prompt

Paste the block below into a fresh session. Replace `<MODULE>` and `<ZIP PATH>`.
Everything after the fence is the prompt.

---

```
Reskin the <MODULE> module to match the design export at <ZIP PATH>.

PLAN FIRST. Do not write code until I approve the plan.

## 0. Read before anything else
- docs/PROJECT_STATE.md and docs/DECISIONS.md — current state and settled decisions.
  Do not re-litigate anything already decided there.
- docs/UI_REDESIGN_PLAYBOOK.md — the process you are following, step by step.
- CLAUDE.md, especially "Frontend/UI-only tasks — hard boundary".

## 1. Inventory the export
- Unzip to the session scratchpad, NEVER into the repo. The export is a visual
  spec: never import, copy or transpile its JS/JSX/CSS into lib/.
- List every file. Identify: token CSS, primitive/component specs, per-screen
  specs, screenshots, brand assets. Ignore generated runtime files, device
  frames, OS status bars and demo scaffolding — say which files you are ignoring
  and why.
- Check the design-system id/UUID against what is already implemented. If it
  matches a previous export, the tokens in lib/core/design are ALREADY DONE —
  do not touch them; this is a consumer-side reskin only. Say which case it is.

## 2. Map the current code
Report, before proposing anything:
- Every file in the module and its purpose.
- Each page's widget tree, and which design-system widgets it already uses.
- EVERY provider, controller, use case, route and permission key the module
  touches. These bindings must survive the reskin byte-identical.
- Anything shared with other features (nav chrome, app bars, badges, chips) —
  changing those changes other screens; call that out explicitly.

## 3. Reconcile design against real data — do this before planning the UI
For every value the design displays, name the field that will supply it.
Design exports are populated with invented data. Where the backend has no such
field:
- Say so plainly and propose an honest alternative (a static descriptive label,
  or a value genuinely derivable from data already in the payload).
- NEVER fabricate numbers, deltas or percentages to match the mock.
- NEVER add backend fields to satisfy a visual — that breaks the UI-only
  boundary. If you think it is genuinely warranted, stop and ask.

## 4. Ask me the scoping questions
Use AskUserQuestion. At minimum, ask about anything in this list that applies:
- Shared chrome: does the redesign change nav/app bars used by other modules?
- Dead controls: the export often contains non-functional UI (search fields,
  filters, toggles). For each: omit, ship decorative, or wire for real?
- Icons: map to the existing icon set, or add the design's icon package?
- Any section whose data source does not exist yet.
Give a recommendation with each question. Do not guess on these.

## 5. Plan
Phased, each phase ending at a verifiable `flutter analyze` checkpoint, ordered
so nothing is broken mid-way: tokens -> primitives -> shared widgets -> pages.
Include exact file paths, what goes in lib/core/design (genuinely shared) versus
module-local, a risk list, and a verification plan. Then wait for approval.

## 6. Build
- Keep every shared widget's PUBLIC API unchanged so other features keep
  compiling. Additive parameters only.
- Reuse before inventing: check lib/core/design/widgets and the module's
  existing widgets first. Justify any new dependency; verify every symbol you
  intend to use actually exists in a package BEFORE writing code against it.
- Responsive by width via LayoutBuilder/MediaQuery — never Platform.isX for
  layout. Use defaultTargetPlatform, not dart:io Platform, for OS checks.
- Theme-aware via context.lum (light + dark). Never static AppColors in new code.
- Respect OS reduce-motion for every animation.
- Keep Semantics and 44dp touch targets on everything interactive.

## 7. Known traps — check each one against your own diff before reporting done
- ClayVariant.lumen paints NO fill of its own. Pass an explicit colour or the
  element renders as shadow only. (AppButton is the correct precedent.)
- Never hand-pick a GridView childAspectRatio to hit a height. Derive it from
  the measured cell width against a documented content-height constant, or you
  get dead space that changes with every breakpoint.
- Never conditionally omit a section that shares a row with another. A collapsed
  pair silently widens its sibling and reads as a layout bug. Render the card
  with an empty state instead.
- Check whether "missing" data is actually scoped (e.g. today-only) in its SQL
  before treating an empty section as a code bug.
- Labels belong to the element they annotate. If a value label must sit on a bar
  or beside a mark, measure it — do not pin it to the container.
- Subtle gradients, insets and rings in the spec are real. If the design system
  widget cannot express one, extend it additively rather than dropping it.

## 8. Verify — and be honest about it
- `flutter analyze` after every phase. The gate is: zero NEW issues against the
  pre-existing baseline. State the baseline count.
- If tests exist, run them. If any fail, prove whether they already failed on a
  clean HEAD (use a detached worktree) before claiming they are unrelated.
- Build and RUN on native (flutter run -d macos or a simulator), not web. Check
  the log for render, overflow and unhandled exceptions.
- Try to screenshot. If the environment blocks it, SAY SO — never claim visual
  verification that did not happen, and list exactly what is unverified.
- Then ask me for screenshots of the running app and diff them against the
  reference renders yourself, section by section: fills, spacing, tile heights,
  typography, icon shapes, empty states. Expect to find real bugs here — the
  last two reskins each did.

## 9. Finish
- Update docs/PROJECT_STATE.md (keep it tight) and append one dated entry to
  docs/DECISIONS.md covering the real decisions and their rationale, including
  anything deliberately deviating from the design and why.
- Report: files changed, one line each, plus the run command and whatever
  verification is still owed.
- Do not commit or push unless I ask. When I do, split into small logical
  commits ordered so each one builds on committed code.
```
