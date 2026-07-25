# AI Companion — Scoping & Architecture Report

Status: PROPOSAL (no code written). Author pass: 2026-07-25.
Scope of this doc: how to build an in-app AI chatbot companion for Lumina POS that
(a) explains the app and its features, (b) tells the user where to find things,
(c) answers questions about the user's own live business data — grounded in the
real codebase, not a generic plan.

---

> **IMPLEMENTATION NOTE (2026-07-25):** the built version uses **Google Gemini**
> (`@google/genai`, model `gemini-2.5-flash`, secret `GEMINI_API_KEY`), not Anthropic —
> switched per owner before deploy. Everywhere this doc says "Anthropic / Claude / Opus 4.8",
> read "Gemini". The architecture is otherwise exactly as described: key server-side only in
> the `llm-proxy` edge function, read-only tools run under the caller's RLS, streaming SSE.
> Tool definitions are emitted as Gemini `functionDeclarations`; the loop uses
> `generateContentStream` + `functionResponse` parts. See DECISIONS.md (2026-07-25) for the
> authoritative record.

## 1. What we're building

A conversational assistant embedded in the app. Three jobs:

1. **App guide** — "How do I create a purchase order?", "Where do I see who owes me
   money?", "What does the reorder screen do?" → answered from a baked-in knowledge
   base of the app's real routes, features, and permission model.
2. **Data analyst** — "What were my sales today?", "Which products are below reorder
   point?", "How much does customer X owe?", "Show me this month's P&L" → answered by
   the bot **calling the app's existing report RPCs** on the user's behalf, scoped to
   their tenant by RLS.
3. **Feature explainer** — "What's the difference between a GRN and an invoice?", "What
   is a fiscal period?" → domain/ERP concept explanation, again from the knowledge base.

Explicitly **out of scope for v1**: the bot performing writes (creating sales, posting
journals, approving POs). Those are permission-gated money paths and must stay behind
explicit user action. The bot is **read + explain only** in v1. (See §9.)

---

## 2. Current state — what exists, what's missing

Established by three codebase scouts (RPC/data surface, routes/nav, AI/edge-fn infra).

### Already present (reuse, don't reinvent)
- **Supabase Edge Function pattern** — 4 functions in `supabase/functions/`, all Deno/TS
  on the `withSupabase({ auth: [...] })` wrapper. `list-sessions` / `revoke-session` are
  the **user-JWT-gated** template: verify caller, resolve tenant/role, keep secrets in
  `Deno.env`. This is exactly the shape an `llm-proxy` function needs.
- **~20 tenant-scoped, jsonb-returning read RPCs** — `dashboard_summary`, `trial_balance`,
  `profit_loss`, `balance_sheet`, `receivables_aging`, `payables_aging`, `customer_ledger`,
  `supplier_ledger`, `report_daily_sales`, `report_inventory_valuation`,
  `drilldown_low_stock`, `search_products`, etc. All `security definer`, all tenant-isolated
  internally. **These become the bot's tools.**
- **RLS multi-tenant model** — `auth_tenant_id()` / `auth_has_permission()` helpers; every
  tenant table auto-scopes on `select`. A query issued as the logged-in user can only ever
  return that user's tenant rows. This is the security backbone that makes a data-answering
  bot safe.
- **Clean-arch feature scaffold** — `lib/features/notifications/` is the smallest full
  vertical slice (domain/data/presentation, plain Riverpod, one datasource). Mirror it.
- **Realtime + helper** — `lib/core/realtime/subscribe_reload.dart`: `subscribeReload(ref,
  table, onChange)` opens an RLS-scoped Postgres-changes channel. A `chat_messages` table +
  this helper gives live message sync for free.
- **Design-system chat-adjacent widgets** — `showAppSheet` (responsive modal/sheet),
  `AppTextField` (multiline composer), `AppCard`/`AppSectionCard` (bubble surfaces),
  `AppListSkeleton` (loading), `AppInlineBanner`/`AppToast` (errors). Only a message-bubble
  list widget is net-new.
- **Full route/feature map** — 11 nav branches, ~180 routes, permission matrix
  (`<module>:<action>` keys). This IS the app-knowledge base for job #1 (see §5.1).

### Missing (net-new)
- **Any LLM** — repo-wide grep for anthropic/openai/claude/gpt/gemini/llm = zero. Greenfield
  on the model side. No LLM SDK in pubspec.
- **The `llm-proxy` edge function** — the one server-side component that holds the Anthropic
  key and runs the tool-use loop.
- **Chat persistence** — no `chat_conversations` / `chat_messages` tables yet.
- **Chat UI** — bubble list, composer panel, launcher. Reuses tokens + existing widgets.
- **Voice→chat bridge (optional)** — STT services exist (`voice_input_service`,
  `voxa_stt_service`) and today feed **search fields only**. Could feed the chat composer
  with near-zero work (they already return a transcript string).

---

## 3. The core architectural decision (security-critical)

**The Anthropic API key MUST NOT live in the Flutter app.** The app ships the Supabase
*anon/publishable* key (safe — RLS protects data). A third-party LLM key in a distributed
binary is an extractable secret that bills to us and can be abused.

Therefore: **all LLM traffic routes through a new `llm-proxy` Supabase Edge Function**, which
mirrors the existing `list-sessions` auth pattern:

```
Flutter app                    llm-proxy (Edge Function, Deno)              Anthropic API
-----------                    -------------------------------              -------------
supabase.functions             1. withSupabase({auth:["publishable"]})      Messages API
  .invoke('llm-proxy',    ──▶  2. ctx.supabase.auth.getUser() → 401 if none  (tool-use loop)
    body:{messages})           3. resolve tenant_id + permission matrix
                               4. call Claude with system prompt + tools ──▶
                               5. Claude requests a tool (e.g. dashboard_    ◀── tool_use
                                  summary) → proxy runs it via ctx.supabase
                                  (RLS-scoped as the caller!) ──────────────▶  tool_result
                               6. Claude returns final text        ◀──────────
                          ◀──  7. persist to chat_messages; return text
```

Two things make this safe and correct:
- **`Deno.env.get("ANTHROPIC_API_KEY")`** — key set out-of-band via `supabase secrets set`,
  never in the app, never in a migration, never in git. Exactly how TWILIO_*/SENDGRID keys
  are handled today.
- **Tools execute as the caller** — the proxy uses `ctx.supabase` (the caller's JWT,
  RLS-scoped), NOT `ctx.supabaseAdmin`. So even if the model "asked" for another tenant's
  data, RLS returns nothing. The model literally cannot see across tenants. This is the
  single most important property of the design.

---

## 4. How each capability is grounded

| Capability | Mechanism | Source of truth |
|---|---|---|
| "Where do I find X?" | Static app-knowledge in the **system prompt** | Route/feature map (§5.1) |
| "How do I do Y?" | Static workflow descriptions in the system prompt | Feature module map |
| "Explain concept Z" | Model's own domain knowledge + KB nudges | Claude + system prompt |
| "What is my <data>?" | **Tool call** → existing report RPC → RLS-scoped result | The ~20 read RPCs |
| "Can I access X?" | Permission matrix passed into the request context | `permissionMatrixProvider` keys |

Nothing about the user's data is pre-loaded or dumped. The bot fetches exactly what a
question needs, through the same RPCs the UI already uses, under the same RLS.

---

## 5. Component breakdown

### 5.1 The app-knowledge base (system prompt content)

This is what makes it a *companion for THIS app*, not a generic ERP chatbot. Assembled once
from the route/feature map into a compact, stable system-prompt section. Sketch:

```
You are the Lumina POS assistant. The app has these areas (nav branches), each reached
from the left rail (desktop) or bottom bar (mobile):
- Dashboard (/dashboard): KPIs, global search (Cmd/Ctrl+K), drill-downs.
- Inventory (/inventory): products, categories, brands, warehouses, stock levels,
  adjustments, transfers, counts, IMEI lookup, barcode labels, bulk import.
- Purchase (/purchasing): purchase orders → receive goods (GRN) → invoice match,
  supplier payments, reorder suggestions, returns. Suppliers CRM lives here.
- Sales (/sales/pos): POS terminal, register open/close, payments, held sales,
  sales history, returns, receipts.
- Customers (/customers): customer CRM, receivables aging, collect payment.
- Repair (/repair): repair-job kanban, intake, technician workload, history.
- Reports (/reports): inventory, product performance, aging, trends, forecast, insights.
- Accounting (/accounting): chart of accounts, journal, vouchers, expenses, banks,
  reconciliation, tax rules, fiscal periods, financial statements.
- HR (/hr): employees, attendance, leaves, payroll, shifts, clock in/out.
- Approvals (/approvals): approval queue, history, workflow config.
- Settings (/settings): profile, business, branches, payment methods, number series.
When asked "where is X", name the area and the path. Respect that a user only sees an
area if they have <module>:read permission (provided below).
```

Then a **per-request** injected line listing the user's granted permission keys, so the bot
tailors "you can/can't reach that" answers. This is small (a Set of `module:action` strings).

Keep this section **byte-stable** across requests (it's the cache prefix — see §7). The
volatile per-user permission set goes AFTER the stable block, or as a mid-conversation
`role:"system"` message, to preserve prompt caching.

### 5.2 The `llm-proxy` edge function

New: `supabase/functions/llm-proxy/index.ts` (+ maybe `tools.ts`, `prompt.ts`). Responsibilities:
- Auth-gate (`withSupabase({ auth: ["publishable"] })` + `getUser()` → 401).
- Build the request: stable system prompt + the tool definitions + the conversation history
  (sent from the app or re-hydrated from `chat_messages`).
- Run the **tool-use loop** with the Anthropic TypeScript SDK (`@anthropic-ai/sdk`), model
  `claude-opus-4-8` (see §8). Recommended: the SDK's tool-runner, but **each tool's execute
  fn calls a whitelisted RPC via `ctx.supabase.rpc(...)`** — never arbitrary SQL, never a
  mutation RPC.
- Persist user + assistant messages to `chat_messages`.
- Return the final assistant text (v1: single JSON payload via `.invoke`; streaming is a
  later enhancement — see §8).

### 5.3 Tool whitelist (the bot's hands)

Map a curated subset of the read RPCs to Claude tools. Each tool = name + description + JSON
schema mirroring the RPC args. Proposed v1 set (all read-only, all already RLS/tenant-safe):

| Tool name | Backing RPC | Answers |
|---|---|---|
| `get_dashboard_summary` | `dashboard_summary(branch?, from?, to?)` | today's sales, cash, receivables/payables, P&L snapshot |
| `list_low_stock` | `drilldown_low_stock(branch?)` | products below reorder point |
| `search_products` | `search_products(query)` | find a product by name/sku/barcode |
| `get_receivables_aging` | `receivables_aging()` | who owes us, by bucket |
| `get_payables_aging` | `payables_aging()` | who we owe, by bucket |
| `get_customer_ledger` | `customer_ledger(customer_id)` | one customer's balance/history |
| `get_supplier_ledger` | `supplier_ledger(supplier_id)` | one supplier's balance/history |
| `get_profit_loss` | `profit_loss(from, to, branch?)` | P&L for a period |
| `get_trial_balance` | `trial_balance(as_of?, branch?)` | trial balance |
| `get_balance_sheet` | `balance_sheet(as_of?, branch?)` | balance sheet |
| `get_daily_sales` | `report_daily_sales(from?, to?)` | sales trend over days |
| `get_inventory_valuation` | `report_inventory_valuation()` | stock value |
| `get_product_performance` | `report_product_performance()` | best/worst sellers |
| `find_customer` / `find_supplier` | RLS `select` on masters | resolve a name → id for the ledger tools |

Design rules for the whitelist:
- **Only `security definer` read RPCs and RLS-scoped `select`s.** No mutation RPC is ever
  registered as a tool. This is enforced by construction (the proxy has a fixed tool map).
- Tools that need an entity id (`customer_ledger`) get a companion resolver tool
  (`find_customer` → id) so the user can ask by name.
- Descriptions are prescriptive about *when* to call (Claude 4.x calls tools more
  conservatively — trigger conditions in the description matter).

### 5.4 Persistence schema (new migration)

```
chat_conversations
  id uuid pk, tenant_id uuid, user_id uuid (auth.users),
  title text, created_at, updated_at
chat_messages
  id uuid pk, conversation_id uuid fk, tenant_id uuid,
  role text check in ('user','assistant'),   -- system stays server-side, not persisted
  content text, tool_calls jsonb null, created_at
```
RLS: both tenant-scoped via `auth_tenant_id()`, and further `user_id = auth.uid()` on
conversations (a user sees only their own chats). Ship indexes + RLS in the same migration
(project convention). Additive, idempotent (`create table if not exists`, `drop policy if
exists`).

### 5.5 Flutter feature `lib/features/assistant/`

Mirror `notifications/` clean-arch:
- `domain/entities/` — `ChatMessage`, `ChatConversation`.
- `data/models/` — `*.fromJson`.
- `data/datasources/` — one `AssistantRemoteDataSource`: `functions.invoke('llm-proxy', …)`,
  plus `select` on `chat_messages` for history, plus tenant resolve (copy the notifications
  datasource idiom).
- `data/repositories/` — repo + Provider.
- `presentation/controllers/` — `AsyncNotifierProvider` for the conversation; optional
  `subscribeReload('chat_messages', …)` for live updates across devices.
- `presentation/pages/` — `AssistantPage` (full screen on mobile) and/or a `showAppSheet`
  panel (desktop). Launcher = a rail/app-bar entry point (e.g. a "sparkles" action).
- `presentation/widgets/` — the net-new `ChatBubble` + `ChatComposer` (built on
  `AppTextField`), `AppListSkeleton` while awaiting a reply, `AppInlineBanner` on error.
  All via `context.lum` tokens (no hardcoded colors — CLAUDE.md rule).

### 5.6 Entry point / routing

Simplest v1: a top-level route `/assistant` (like `/notifications`), reachable from a rail
action or the dashboard app bar. Not necessarily a nav branch (avoids shifting branch
indices). Decide with the user (§11).

---

## 6. End-to-end request flow (concrete example)

User types "which customers owe me the most?" on their phone:
1. `AssistantController` appends the user message, calls
   `functions.invoke('llm-proxy', body: {conversation_id, message})`. JWT auto-attached.
2. `llm-proxy` verifies the user, resolves tenant + permissions, loads recent history.
3. Calls Claude with system prompt + tools. Claude emits `tool_use: get_receivables_aging`.
4. Proxy runs `ctx.supabase.rpc('receivables_aging')` — RLS scopes to this tenant —
   returns the jsonb aging buckets as `tool_result`.
5. Claude composes: "Your top debtors are Acme (₨120k, 45 days overdue)…" + maybe suggests
   "you can collect from the Customers → Receivables screen."
6. Proxy persists both messages, returns the text.
7. App renders the bubble; `subscribeReload` keeps other devices in sync.

Total secrets exposed to the client: none. Cross-tenant leakage possible: none (RLS).

---

## 7. Prompt caching & cost control

- The stable system block (app-knowledge KB + tool defs) is the cache prefix. Mark it
  `cache_control: {type:"ephemeral"}`. Keep it byte-identical across requests — do NOT
  interpolate timestamps/user names into it. Put the volatile permission set + the user
  question AFTER the breakpoint.
- Cached reads cost ~0.1× — with a large KB prefix this is the main cost lever.
- Consider `claude-sonnet-5` for cost-sensitive deployments (see §8).

---

## 8. Model, streaming, realtime

- **Model**: default `claude-opus-4-8` (best reasoning, 1M context, strong tool use). For a
  high-volume, cost-sensitive rollout, `claude-sonnet-5` is the near-Opus-quality cheaper
  tier. This is a business call, not a technical one — pick per budget. (Never hardcode the
  key; the model id is the only knob in the edge function.)
- **Thinking/effort**: adaptive thinking on; `effort: "high"` is a good default for a
  reasoning-plus-tools assistant. Not user-visible.
- **Streaming**: v1 can be non-streaming — `.invoke` returns one JSON payload, and the
  codebase has no SSE handling today. A streaming UX (token-by-token) is a **later**
  enhancement requiring either SSE from the edge function or the proxy writing incremental
  rows that `subscribeReload` picks up. Recommend shipping non-streaming first (simplest
  thing that works), add streaming only if the wait feels long.
- **Realtime**: `chat_messages` + `subscribeReload` gives multi-device history sync for free,
  independent of streaming.

---

## 9. Security (must-haves, not optional)

1. **Key server-side only.** `ANTHROPIC_API_KEY` via `Deno.env` + `supabase secrets set`.
   Never in app, migration, or git. (Same discipline as the app's Twilio/SendGrid keys.)
2. **Tools run as the caller (`ctx.supabase`), never service-role.** RLS is the tenant
   firewall. The model cannot reach another tenant's data even if prompted to.
3. **Read-only tool whitelist.** No mutation RPC is registered as a tool in v1. The bot
   cannot create sales, post journals, disburse payroll, or approve anything. Writes stay
   behind explicit, permission-gated UI actions.
4. **Auth gate on every call.** `getUser()` → 401. Anonymous invocation rejected.
5. **Prompt-injection posture.** Tool *inputs* come from the model but *execution* is a fixed
   map to safe RPCs with typed args — the model can't smuggle SQL. Data returned by tools is
   treated as data, not instructions. Never let tool output escalate to a write path.
6. **Rate limiting / abuse.** Add a per-user request budget in the edge function (cheap
   counter in a table, or reuse an existing throttle idiom) so a runaway client can't rack up
   Anthropic spend. Log usage (`response.usage`) per call for cost attribution.
7. **PII / data governance.** Chat content (which may quote customer balances, salaries) is
   sent to Anthropic. Confirm this is acceptable under the tenant's data policy; the
   claude-api 30-day-retention note applies for some models. Surface this in the decision.
8. **Persisted history is tenant+user scoped** and never stores the system prompt or raw
   tool payloads beyond what's needed.

---

## 10. Phased build plan

Each phase is independently shippable and verifiable (`flutter analyze` clean + feature works
end-to-end — project's definition of done).

- **Phase 0 — Spike (backend only).** `llm-proxy` with a *fixed* 2–3 tool set
  (`dashboard_summary`, `search_products`, `receivables_aging`) + hardcoded system prompt.
  Test via `supabase functions serve` + curl with a real user JWT. Verify: auth gate, RLS
  scoping (a cashier JWT can't see another tenant), tool loop returns sane text.
  Verify: no key in client, mutation RPCs absent from the tool map.
- **Phase 1 — Persistence + minimal UI.** `chat_conversations`/`chat_messages` migration +
  RLS. `lib/features/assistant/` scaffold. Non-streaming. One `AssistantPage`, a launcher,
  bubbles, composer. History load + send. Verify end-to-end on macOS.
- **Phase 2 — Full app-knowledge base.** Assemble the complete route/feature KB into the
  system prompt; inject the per-user permission set. Expand the tool whitelist to the full
  §5.3 set. Prompt-cache the stable prefix. Verify "where is X" + data questions across
  modules.
- **Phase 3 — Polish.** Rate limit + usage logging; error/empty/loading states; realtime
  multi-device sync; optional voice→composer bridge (reuse existing STT). Optional streaming.
- **Docs.** Update PROJECT_STATE.md (+ a DECISIONS.md line) per phase — a task isn't done
  until docs reflect it.

---

## 11. Open decisions (need your call)

1. **Model tier** — Opus 4.8 (best) vs Sonnet 5 (cheaper, near-Opus). Budget-driven.
2. **Entry point** — top-level `/assistant` route + rail action (simplest), OR a floating
   launcher on every screen, OR a new nav branch (index 11)? Simplest = top-level route.
3. **Scope guard** — confirm v1 is **read + explain only** (no write actions). Recommended.
4. **Data-to-Anthropic policy** — OK to send business data (balances, salaries) to the
   Anthropic API? Needed before any real data flows.
5. **Streaming now or later** — recommend later (ship non-streaming v1).
6. **Voice** — wire existing STT into the composer in v1, or defer? Near-zero cost to include.

---

## 12. Risks & mitigations

| Risk | Mitigation |
|---|---|
| LLM key leakage | Server-side edge function only; never in app/git |
| Cross-tenant data leak | Tools run as caller under RLS; never service-role |
| Bot triggers a write / money path | Read-only tool whitelist; no mutation RPC registered |
| Runaway Anthropic cost | Per-user rate limit + usage logging in the proxy; prompt caching |
| Hallucinated app instructions | KB in system prompt = real routes; keep it in sync with router |
| PII sent off-platform | Explicit policy decision (§11.4); document retention |
| Streaming complexity | Ship non-streaming first; add SSE only if needed |

---

## 13. One-paragraph summary

Everything the bot needs on the *transport, auth, and data* side already exists: a proven
JWT-gated edge-function pattern, ~20 tenant-safe report RPCs, RLS that makes cross-tenant
leakage structurally impossible, a clean-arch feature template, realtime sync, and reusable
UI widgets. The only net-new pieces are one `llm-proxy` edge function (holding the Anthropic
key and running a read-only tool-use loop), a small chat-history schema, and a chat UI. The
app-knowledge for "where do I find X" comes straight from the existing route/feature map baked
into the system prompt; the answers about the user's own data come from the model calling the
existing RPCs under the caller's own RLS scope. Model = `claude-opus-4-8` (or `claude-sonnet-5`
for cost). Build it in phases, read-only first, key server-side always.
