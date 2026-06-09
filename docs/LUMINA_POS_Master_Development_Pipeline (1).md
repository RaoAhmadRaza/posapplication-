LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

LUMINA POS / STOCK BRIDGE ERP
COMPLETE MASTER DEVELOPMENT PIPELINE

Senior Software Architect  ·  CTO Execution Blueprint  ·  30-Day AI-Assisted Delivery
Confidential — Internal Engineering Document

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 1

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

Table of Contents

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 2

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

1. Complete Development Strategy

1.1 Overall Development Methodology

This project demands a Domain-Driven, AI-Amplified Agile approach. Standard Scrum cannot survive the
constraints — the surface area is too large and the interdependencies too deep for sequential delivery. The
chosen methodology is Vertical Slice Delivery with Parallel Domain Tracks.

Each domain (Sales, Inventory, Accounting, CRM, HR, Repairs, Sync) is developed in parallel vertical slices that
are independently runnable and testable. Integration gates replace traditional sprint reviews — a domain slice
only moves to production when it successfully integrates with the shared data bus, event system, and sync
engine.

1.2 Execution Philosophy

Philosophy: Ship Correct Foundations. Iterate Everything Else. Never Scaffold Broken
Abstractions.

•  Architecture is non-negotiable: Clean Architecture, DDD domain boundaries, and the sync engine are

locked in Week 1. No shortcuts here — every day of architectural debt in an offline-first, multi-tenant
system costs 3x to repair.

•  UI is fast-follower: Design tokens, theme system, and a component library are set up in Day 2. Every

screen after that is assembly of existing components, not custom UI engineering.

•  Business logic owns correctness: The accounting engine, inventory deduction engine, and sync conflict

resolver must be formally unit-tested before any frontend consumes them.

•  AI accelerates assembly, not architecture: Use AI agents to generate boilerplate, CRUD screens,

repository implementations, and test fixtures. Never use AI to design domain boundaries, financial logic,
or sync resolution strategies.

1.3 How to Reduce Development Time Using AI

Area

AI Acceleration Strategy

Backend API scaffolding  Claude / Cursor: Generate NestJS controllers, DTOs, service stubs, and

validation layers from a schema definition. Estimated 70% time reduction on
CRUD endpoints.

Flutter screen
generation

Database schema

Cursor / Lovable: Generate full screen scaffolds from wireframes or description
prompts. Reduces initial screen build time from ~4h to ~45min.

ChatGPT-4o / Claude: Generate full PostgreSQL DDL with indexes, FK
constraints, audit columns, and RLS policies from domain entity specs.

State management
boilerplate

Cursor: Generate Riverpod providers, notifiers, and state models from entity
definitions.

Test fixture generation

Claude: Generate 80%+ of unit test cases for repositories, services, and
domain logic from function signatures.

API integration code

GitHub Copilot: Generate REST client code, request/response models, and
error handling from OpenAPI specs.

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 3

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

Documentation

Claude: Generate inline docs, API reference docs, and architecture decision
records continuously as code is written.

1.4 Parallel Development Opportunities

The following work streams can run in parallel without blocking each other, enabling a team of 2-4 engineers (or a
solo dev using multiple AI agents) to multiply effective throughput:

Track

Parallel Work Streams

Sync Point

Track A

Auth Domain + Device Management + RBAC engine  Week 1 Day 5

Track B

Database schema + Migrations + Seed data

Week 1 Day 5

Track C

Component library + Design tokens + Theme system  Week 1 Day 7

Track D

Sync engine architecture + Offline queue design

Week 2 Day 3

Track E

POS Sales screens + Cart engine + Pricing engine

Week 2 Day 5

Track F

Inventory engine + Stock deduction logic

Week 2 Day 5

Track G

Accounting engine + Journal/Ledger foundation

Week 2 Day 7

1.5 Critical-Path Dependencies

⚠ CRITICAL PATH: Auth → RBAC → Sync Engine → Domain Modules → UI Assembly →
Integration Testing

•  Authentication + Device Authorization must ship first. Every other module depends on JWT context,

tenant isolation, and branch-scoped sessions.

•  Database schema must be stable before any repository layer is written. Schema changes cascade into

DTOs, validators, migrations, and sync logic.

•  The sync engine architecture (conflict resolver, queue format, delta protocol) must be designed and

reviewed before any offline-capable module begins.

•  The accounting event bus (ledger posting events) must be defined before Sales, Purchase, or Payment

modules emit financial transactions.

•  The RBAC permission matrix must be codified before any UI is built — role-aware UI rendering depends

on a stable permission contract.

1.6 Architectural Bottleneck Prevention

•  Use a shared domain event bus (TypeScript typed) from Day 1. All cross-domain side effects (inventory

deduction on sale, ledger posting on payment) go through events, never direct service calls.

•  Define a canonical SyncRecord interface on Day 2. Every offline-capable entity implements it. This

prevents n-different sync implementations later.

•  Create a BaseRepository<T> abstract class with built-in soft delete, audit timestamps, tenant isolation,

•

and optimistic locking. Every repository extends it.
Lock the API response envelope (data, meta, errors, pagination) before any endpoint is written.
Inconsistent API contracts kill frontend development velocity.

•  Establish a single error handling strategy (NestJS exception filters + Flutter error interceptors) before any

domain module ships.

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 4

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

1.7 Minimizing Technical Debt at Speed

•  Generate, never write, all boilerplate. If you are manually typing a CRUD repository, you are creating drift

between modules. Use code generation.

•  Write integration tests for every API endpoint before writing the frontend. Catches contract issues before

they cascade.

•  All financial mutations (sale, payment, adjustment) must be wrapped in database transactions with

rollback. No exceptions, no speed shortcuts.

•  Enforce linting and architecture rules via ESLint + dart_analyze from Day 1. Removing 3 months of lint

debt is slower than enabling it on Day 1.

•  Every screen must consume from a repository interface, never directly from an API client. This enables

mocking, offline switching, and refactoring.

1.8 Sprint Philosophy

Use 4-day micro-sprints rather than 2-week sprints. At this velocity, a 2-week sprint is too long — feedback loops
must be 4 days maximum.

Phase

Day 1-2

Day 3

Day 4

Activity

Scaffold + implement core logic for the domain module

Wire frontend, write integration tests, resolve API contracts

Bug fix, code review (AI-assisted), merge to staging

Sprint gate

All integration tests pass, all API contracts verified, UI renders on real device

1.9 MVP vs Production Decisions

Rule: MVP = Core Happy Path. Production = Complete Error Handling, Offline, and Security
Layers.

For the 30-day timeline, every module ships with: full happy-path functionality, basic error states, and the
sync/offline capability if it is on the critical path for POS operations. The following are explicitly deferred to
post-launch:

•  AI recommendation widgets (forecasting, smart reorder) — infrastructure ready, ML inference deferred
•  Multi-language / localization — architecture ready, translation strings deferred
•  Advanced analytics drilldowns — basic reporting ships, advanced pivot tables deferred
•  Kubernetes / multi-region infrastructure — single-region Docker deployment ships
•  Biometric login on non-flagship devices — JWT + PIN ships universally

1.10 Risk Mitigation & Fallback Planning

Risk

Mitigation

Fallback

Sync engine complexity
delays timeline

Dedicate 20% of Week 1 & 2 to sync
exclusively

Ship without real-time sync;
manual refresh mode

Accounting engine
correctness

10 formal unit tests per accounting
operation

Disable financial posting;
log-only mode until verified

Offline conflict edge cases

Implement last-write-wins with conflict log
first

Prompt user to resolve
conflicts manually

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 5

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

Hardware integration failures

Abstract printer/scanner behind
interfaces; mock first

Ship without printer; PDF
export as fallback

AI-generated code quality

All AI-generated business logic reviewed
+ tested

Rewrite AI output if test
coverage < 80%

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 6

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

2. Module-Wise Development Pipeline

The following 16 modules are derived from the domain architecture. Each is specified with full technical depth.
Modules are ordered by criticality within the dependency graph.

Module 01: Authentication, Device Authorization & RBAC

Attribute

Priority

Complexity

Value

🔴 CRITICAL

High

Estimated Time (AI-Assisted)

3 days

Estimated Time (Manual)

8 days

Objective

Establish the foundational identity, access control, and device trust layer that all other modules depend on.
Includes JWT-based auth, MFA/TOTP, biometric login, device fingerprinting, branch-scoped sessions, and a fully
dynamic RBAC permission matrix.

Core Features

•  Email, username, PIN, and biometric login
•  QR code-based quick login for cashier role-switching
•  MFA / TOTP with authenticator app + SMS fallback
•  Device fingerprinting and hardware binding
•  Device authorization workflow (register, approve, revoke)
•  Branch-scoped session isolation
•  Dynamic RBAC: role → module → action → branch scope
•  Failed login protection with exponential backoff
•  Session monitoring and remote session invalidation
•  Audit logging for all auth events
•  Password recovery via email OTP with expiring links
•  Trusted device management

Backend Requirements

•  POST /auth/login, /auth/refresh, /auth/logout, /auth/mfa/verify
•  POST /devices/register, GET /devices, DELETE /devices/:id/revoke
•  GET /auth/permissions — returns full permission matrix for user+branch
•  Redis: JWT refresh token store with TTL, device trust cache
•  Argon2id password hashing; AES-256 encrypted local session store
•  NestJS Guards: JwtAuthGuard, PermissionGuard(module, action), BranchGuard
•  Rate limiter service: per-IP and per-user with sliding window
•  DeviceFingerprint service: collects OS, hardware ID, MAC-like identifiers
•  Audit service: every auth event writes to immutable audit_logs table

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 7

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

•  BullMQ queue: async OTP delivery, email dispatch

Frontend Requirements

•  Splash → EnvironmentCheck → DeviceAuth → Login → MFA → WorkspaceInit flow
•  PIN pad widget with haptic feedback (desktop + mobile)
•  Biometric auth trigger widget (Flutter local_auth plugin)
•  QR scanner widget for quick cashier login
•  Role/permission provider (Riverpod): AuthStateNotifier holds full permission matrix
•  Permission-aware widget: PermissionGate(module, action, child) — hides UI for unauthorized
•  Device management screen: list, approve, revoke devices
•  Session monitor screen: show active sessions, remote kill

Database Design Requirements

•  Table: users (id, tenant_id, name, email, password_hash, pin_hash, role_id, status, created_at,

updated_at, deleted_at)

•  Table: roles (id, tenant_id, name, description, is_system_role)
•  Table: permissions (id, role_id, module, action, branch_scope: ALL|OWN_BRANCH, granted: bool)
•  Table: devices (id, tenant_id, user_id, device_name, fingerprint_hash, branch_id, trust_level, authorized:

bool, last_seen_at)

•  Table: sessions (id, user_id, device_id, token_hash, ip, expires_at, revoked_at)
•  Table: audit_logs (id, tenant_id, user_id, device_id, action, entity, entity_id, diff_json, created_at) — NO

soft delete, immutable

•  Table: mfa_configs (id, user_id, totp_secret_encrypted, backup_codes_json, enabled)
•

Indexes: users(email), users(tenant_id, status), sessions(token_hash), audit_logs(user_id, created_at),
devices(fingerprint_hash)

•  Row-Level Security: tenant_id isolation on all tables

Security Requirements

•  SSL pinning on Flutter HTTP client — rejects non-pinned certificates
•  AES-256 encryption for locally stored PIN hash and session token
•  Device fingerprint hashed with SHA-256 + salt before storage
•  All password operations use Argon2id with tuned memory cost
•  Suspicious login detection: new device + new location triggers MFA challenge
•  Audit logs are append-only — no UPDATE or DELETE permitted via ORM

Integrations

•  Firebase Auth (optional) — or self-hosted JWT only for full control
•  Twilio / Vonage: SMS OTP delivery
•  SendGrid: email OTP and recovery links
•  Flutter local_auth: biometric integration

Dependencies

•  None — this is the root module

AI Acceleration Opportunities

•  AI can generate: all NestJS controller/service/DTO boilerplate from interface specs
•  AI can generate: Riverpod AuthStateNotifier boilerplate and permission matrix provider
•  AI can generate: Flutter PIN pad and QR scanner widget shells

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 8

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

•  Manual required: Argon2id config tuning, device fingerprint algorithm, session revocation edge cases
•  Manual required: RBAC permission matrix design and all permission scope rules

Module 02: Core Infrastructure: Database, Sync Engine & Event Bus

Attribute

Priority

Complexity

Value

🔴 CRITICAL

Extreme

Estimated Time (AI-Assisted)

5 days

Estimated Time (Manual)

15 days

Objective

Establish the foundational data infrastructure including PostgreSQL schema with RLS, the offline-first sync engine
(bidirectional delta sync, conflict resolution, queue replay), the typed domain event bus, Redis caching layer, and
BullMQ job queues. This module is the architectural backbone — no domain module can function correctly without
it.

Core Features

•  Multi-tenant PostgreSQL with RLS policies and tenant isolation
•  Base entity classes: soft delete, audit timestamps, version counters
•  Delta sync protocol: client sends local_version, server returns changeset
•  Bidirectional sync with conflict staging and resolution workflow
•  Offline queue (Drift/Isar on Flutter): persist operations, replay on reconnect
•  Typed domain event bus: events are strongly typed, async, logged
•  BullMQ job queues: notifications, sync workers, email dispatch, report generation
•  Redis cache: permission matrix, product catalog snapshot, exchange rates, config
•  Database migration framework (TypeORM/Prisma Migrate) with rollback support
•  Centralized error handling: typed error codes, structured error responses
•  Health check endpoints: /health/db, /health/redis, /health/queues

Backend Requirements

•  SyncController: POST /sync/push (client → server), GET /sync/pull?since=&branch= (server → client)
•  SyncConflictService: version-based conflict detection, last-write-wins default, manual override queue
•  EventBusService: publish(DomainEvent), subscribe(EventType, handler) — uses Redis pub/sub internally
•  BaseRepository<T>: findById, findMany, create, update, softDelete, withTenant, withAudit
•  CacheService: get(key), set(key, value, ttl), invalidate(pattern), warmup(strategy)
•  QueueService: enqueue(queue, job, priority), process(queue, handler), retry, dead-letter handling
•  MigrationService: run, rollback, status, seed
•  All domain events must include: eventId, eventType, tenantId, branchId, actorId, timestamp, payload

Frontend Requirements

•  SyncStatusWidget: shows sync state (synced, pending, conflict, offline) in persistent app bar

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 9

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

•  OfflineQueueManager: Drift database on device, typed pending operation store
•  ConnectivityMonitor: streams connectivity events, triggers sync on reconnect
•  ConflictResolutionDialog: shows conflicted records, lets user choose version
•  SyncProgressSheet: shows sync progress, queue depth, last sync time
•  Riverpod: ConnectivityProvider, SyncStateProvider, OfflineQueueProvider

Database Design Requirements

•  Every domain table: id (UUID), tenant_id, branch_id, created_at, updated_at, deleted_at, version (int),

created_by, updated_by

•  Table: sync_log (id, tenant_id, device_id, entity, entity_id, operation, synced_at, conflict_flag)
•  Table: sync_conflicts (id, tenant_id, entity, entity_id, local_version_json, server_version_json,

resolved_by, resolved_at)

•  Table: domain_events (id, tenant_id, event_type, payload_json, actor_id, published_at, processed_at)
•  Table: job_queue_log (id, queue_name, job_id, status, error_json, created_at, processed_at)
•  PostgreSQL partitioning on domain_events and audit_logs by created_at (monthly ranges)
•  Composite indexes: (tenant_id, entity, updated_at) for delta sync queries
•  Materialized views for dashboard KPIs with scheduled refresh

Security Requirements

•  All sync endpoints require valid JWT + device fingerprint match
•  Sync payload encryption: AES-256-GCM in transit (beyond TLS)
•  Tenant isolation enforced at RLS level — sync queries cannot leak cross-tenant
•  Event bus messages signed with HMAC to prevent spoofing
•  Queue payloads sanitized; no raw user input in job payloads

Integrations

•  Redis (Upstash or self-hosted): event bus, cache, rate limiting
•  BullMQ: job queue engine
•
Isar / Drift: Flutter local database
•  PostgreSQL 15+: primary database

Dependencies

•  Module 01 (Auth)

AI Acceleration Opportunities

•  AI can generate: full PostgreSQL DDL from entity specifications
•  AI can generate: BaseRepository implementation with TypeORM/Prisma
•  AI can generate: BullMQ queue setup, processor boilerplate, dead-letter handlers
•  Manual required: sync conflict resolution logic, delta protocol design, RLS policies
•  Manual required: event ordering guarantees, sync queue prioritization rules
•  Manual required: review all generated migration files before applying to any database

Module 03: POS Sales Engine & Invoice System

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 10

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

Attribute

Priority

Complexity

Value

🔴 CRITICAL

High

Estimated Time (AI-Assisted)

4 days

Estimated Time (Manual)

12 days

Objective

The primary revenue-generating workflow. Includes the full POS cart engine, barcode scanning, multi-tier pricing,
discount/tax calculation, multi-modal payment processing, invoice generation with thermal printing, credit sale
management, and real-time inventory deduction with ledger posting.

Core Features

•  Product search by barcode, SKU, IMEI, name, category — <100ms latency
•  Cart engine: add/remove/update qty, line-item discounts, cart-level discounts
•  Multi-tier pricing: retail, wholesale, quantity break, last price, custom
•  Tax engine: configurable tax slabs, inclusive/exclusive tax modes
•  Real-time profit calculation per line item and cart total
•  Multi-modal payment: cash, bank transfer, split payment, credit/partial payment
•  Change calculation and denomination breakdown
•
Invoice generation: PDF and thermal print format
•  Credit sale workflow: customer ledger debit, receivable tracking
•  Return/refund workflow with inventory restock and ledger reversal
•  Hold and resume sale sessions
•  Offline billing: full POS works offline, syncs when reconnected
•  Quick cash sale (no customer required)
•
•  Cashier session: open/close with float, cash drawer reconciliation
•  Barcode scanner hardware integration

IMEI-level sale tracking

Backend Requirements

•  POST /invoices — creates sale invoice (atomic: stock deduction + ledger posting in one transaction)
•  GET /products/search?q=&barcode=&branch= — full-text + barcode search with Redis cache
•  GET /products/:id/pricing?customer_id=&qty= — pricing engine returns applicable tier
•  POST /payments — record payment, update invoice balance, post to customer ledger
•  POST /invoices/:id/return — reverse invoice, restock inventory, reverse ledger entries
•  GET /sessions/cashier — current cashier session state, float, running total
•  POST /sessions/cashier/close — reconcile session, generate session report
•  PricingEngine service: customer tier, quantity breaks, last price lookup, manual override
•  TaxEngine service: configurable tax slabs, round-half-up mode, inclusive/exclusive switch
•
InvoiceNumberService: sequential, branch-prefixed, gap-safe invoice numbering
•  PrintService: generates ZPL/ESC-POS commands and PDF receipt simultaneously
•  Domain events: InvoiceCreated, PaymentReceived, InvoiceReturned, CashierSessionClosed

Frontend Requirements

•  POS main screen: 3-panel layout (product search | cart | payment/customer)

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 11

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

•  Barcode scanner widget: continuous scan mode, beep feedback, IMEI validation
•  Product search panel: instant search with debounce 150ms, category filter chips
•  Cart widget: virtualized list, swipe-to-delete, inline qty editor
•  Pricing badge widget: shows original vs applied price with tier label
•  Payment modal: cash, bank, split — with animated amount input
•  Receipt preview widget: before print confirmation
•  Hold sale list: shows parked sales with restore action
•  Cashier session widget: persistent header showing float, total, session time
•  Offline badge: shows when operating in offline mode
•  Keyboard shortcuts map: F1=new sale, F2=search, F4=hold, F8=payment, F10=print

Database Design Requirements

•  Table: invoices (id, tenant_id, branch_id, invoice_number, customer_id, cashier_id, session_id, status,
subtotal, discount_total, tax_total, grand_total, paid_amount, balance, sale_type, notes, created_at,
updated_at, deleted_at, version)

•  Table: invoice_items (id, invoice_id, product_id, imei_id, qty, unit_price, cost_price, discount_pct, tax_pct,

line_total, profit)

•  Table: payments (id, tenant_id, invoice_id, method, amount, reference, bank_account_id, created_at)
•  Table: cashier_sessions (id, tenant_id, branch_id, cashier_id, opening_float, closing_float, status,

opened_at, closed_at)

•  Table: held_sales (id, tenant_id, branch_id, cashier_id, cart_json, label, created_at)
•

Indexes: invoices(branch_id, created_at), invoices(customer_id), invoices(invoice_number),
invoice_items(product_id)

•  Trigger: after INSERT on invoices → emit InvoiceCreated event → subtract stock, post to ledger

Security Requirements

Invoice is immutable once paid — only additions (payments, returns) allowed, no edits

•
•  All invoice mutations require valid cashier session token
•  Discount override above threshold requires manager PIN authorization
•  Payment processing logged with device fingerprint
•  Offline invoices use temporary IDs (UUID v7) that resolve on sync

Integrations

•  Thermal printer: ESC/POS command library (flutter_pos_printer_platform)
•  Barcode scanner: USB HID and Bluetooth HID input stream
•  PDF generation: pdf package on Flutter, puppeteer on server
•  Payment gateway: extensible interface — initial integration with cash/bank only

Dependencies

•  Module 01 (Auth)
•  Module 02 (Sync Engine)
•  Module 05 (Inventory Engine)
•  Module 07 (Accounting Engine)

AI Acceleration Opportunities

•  AI can generate: full cart state machine (Riverpod CartNotifier) with add/remove/update
•  AI can generate: all NestJS invoice CRUD endpoints and DTOs
•  AI can generate: pricing tier lookup service boilerplate

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 12

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

•  Manual required: atomic transaction wrapping (invoice + stock + ledger in one DB transaction)
•  Manual required: offline invoice ID resolution strategy and sync conflict handling for concurrent cashiers
•  Manual required: ESC/POS receipt template design and printer command sequences

Module 04: Purchase Management & Supplier Operations

Attribute

Priority

Complexity

Value

🔴 CRITICAL

High

Estimated Time (AI-Assisted)

3 days

Estimated Time (Manual)

9 days

Objective

Full purchase lifecycle: purchase orders, GRN (goods receipt), supplier invoice matching, multi-currency
purchase, IMEI/serial tracking on receipt, supplier payments and ledger, purchase returns, and automated reorder
triggers.

Core Features

IMEI/serial number capture on goods receipt

•  Purchase order creation with multi-item, multi-currency support
•  Goods receipt note (GRN) with line-item qty and quality validation
•  Purchase invoice matching (3-way: PO → GRN → Invoice)
•
•  Supplier payment recording with bank/cash and partial payment
•  Purchase returns with stock deduction and ledger reversal
•  Automated reorder triggers from inventory module
•
Landed cost allocation across PO lines
•  Supplier ledger and payables aging report
•  Draft → Submitted → Approved → Received → Invoiced → Closed workflow
•  Approval workflow for POs above threshold

Backend Requirements

•  Full CRUD for POs, GRNs, purchase invoices with approval state machine
•  POST /purchase-orders/:id/receive — GRN creation, triggers stock receipt + landed cost calc
•  POST /purchase-invoices/:id/pay — supplier payment, posts to payables ledger
•  POST /purchase-orders/:id/return — purchase return, reverses stock and ledger
•  Domain events: PurchaseOrderCreated, GRNReceived, SupplierPaid, PurchaseReturned
•  ApprovalWorkflow service: generic, configurable approval chain used by PO and other modules
•

LandedCostService: distributes freight/insurance/duty across PO lines by weight or value

Frontend Requirements

•  Purchase order form: multi-line item editor with inline product search

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 13

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

•  GRN screen: scan barcodes to receive items, IMEI capture widget
•  Purchase invoice matching screen: side-by-side PO / GRN / invoice comparison
•  Approval flow screen: approval history timeline, approve/reject action
•  Supplier ledger screen: transaction timeline, balance, aging
•  Reorder suggestion widget: pulls from inventory module's low-stock events

Database Design Requirements

•  Table: purchase_orders (id, tenant_id, branch_id, supplier_id, status, order_date, expected_date,

currency, exchange_rate, subtotal, tax, landed_cost, grand_total)

•  Table: purchase_order_items (id, po_id, product_id, qty_ordered, qty_received, unit_cost, tax_pct,

line_total)

•  Table: grns (id, tenant_id, po_id, received_by, received_at, notes)
•  Table: grn_items (id, grn_id, po_item_id, qty_received, imei_ids_json)
•  Table: purchase_invoices (id, tenant_id, po_id, grn_id, supplier_invoice_number, amount, status)
•  Table: supplier_payments (id, tenant_id, supplier_id, invoice_id, method, amount, reference, paid_at)
•

Indexes: purchase_orders(supplier_id, status), purchase_orders(branch_id, created_at)

Security Requirements

•  PO approval above threshold requires approver role authorization
•  GRN receipt is immutable once confirmed — corrections via purchase return only
•  Supplier payment requires valid bank account or cash account reference

Integrations

•  Supplier master (CRM module)
•
Inventory engine (Module 05)
•  Accounting engine (Module 07)

Dependencies

•  Module 01
•  Module 02
•  Module 05
•  Module 07

AI Acceleration Opportunities

•  AI can generate: PO/GRN CRUD endpoints and form screens
•  AI can generate: approval workflow state machine boilerplate
•  Manual required: 3-way matching logic, landed cost calculation, IMEI batch import

Module 05: Inventory Engine, IMEI Lifecycle & Warehouse Management

Attribute

Priority

Complexity

Value

🔴 CRITICAL

Extreme

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 14

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

Estimated Time (AI-Assisted)

5 days

Estimated Time (Manual)

16 days

Objective

The core inventory intelligence system: perpetual inventory, multi-location stock, IMEI/serial lifecycle tracking,
stock transfers between branches/warehouses, inventory adjustments, stock counts, scrap management,
valuation (FIFO/LIFO/Weighted Average), and reorder intelligence.

Core Features

IMEI lifecycle: purchase receipt → sale → return → transfer → scrap

•  Real-time perpetual inventory with instant stock deduction on sale
•  Multi-location stock: per branch, per warehouse, per shelf
•
•  Stock transfers between branches with in-transit state
•  Stock adjustments with reason codes and approval requirements
•  Physical stock count reconciliation workflow
Inventory valuation: FIFO, LIFO, Weighted Average per product
•
•
Low stock alerts with configurable reorder points
•  Reorder quantity suggestions based on sales velocity
•  Scrap/write-off workflow with accounting impact
•  Batch/lot tracking (for electronics, expiry items)
•  Stock aging report
•
•  Reserved stock for pending orders

Inventory snapshot for period-end closing

Backend Requirements

•  StockLedger service: every stock movement writes an immutable stock_ledger record
•  GET /inventory/:product_id/balance?branch= — real-time stock with reserved quantity
•  POST /stock-transfers — creates transfer, deducts from source, credits on confirmation
•  POST /stock-adjustments — adjustment with reason, posts to adjustment ledger
•  POST /stock-counts — initiate count, compare to system qty, generate variance report
•  GET /inventory/reorder-suggestions — returns products below reorder point with suggested qty
IMEI service: track full lifecycle, validate uniqueness, flag duplicates
•
•  ValuationEngine service: calculates moving average cost on every receipt
•  Domain events: StockDeducted, StockReceived, StockTransferred, StockAdjusted, LowStockAlert

Frontend Requirements

Inventory dashboard: per-product stock by location, aging, valuation
IMEI lookup screen: enter IMEI, see full lifecycle history

•
•
•  Stock transfer form: source branch, destination, items, quantities
•  Stock count screen: barcode scan mode, compare expected vs counted
•  Reorder suggestions list with one-tap PO creation
•
•  Product inventory card: current stock, reserved, in-transit, cost

Low stock alert banner in dashboard

Database Design Requirements

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 15

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

•  Table: stock_balance (id, tenant_id, branch_id, warehouse_id, product_id, qty_on_hand, qty_reserved,

qty_in_transit, avg_cost, last_updated) — materialized, updated by triggers

•  Table: stock_ledger (id, tenant_id, product_id, branch_id, operation_type, qty_change, cost_per_unit,

reference_id, reference_type, created_at) — IMMUTABLE, append-only

•  Table: imei_records (id, tenant_id, imei, product_id, status:

AVAILABLE|SOLD|RETURNED|TRANSFERRED|SCRAPPED, branch_id, source_type, source_id,
created_at, updated_at)

•  Table: stock_transfers (id, tenant_id, from_branch_id, to_branch_id, status, created_by, confirmed_by,

transferred_at)

•  Table: stock_transfer_items (id, transfer_id, product_id, imei_id, qty)
•  Table: stock_adjustments (id, tenant_id, branch_id, product_id, adj_qty, reason_code, approved_by,

created_at)

•  Table: stock_counts (id, tenant_id, branch_id, status, started_at, completed_at)
•

Indexes: stock_balance(tenant_id, branch_id, product_id) UNIQUE, imei_records(imei) UNIQUE,
stock_ledger(product_id, branch_id, created_at)

Security Requirements

stock_ledger is immutable — application enforces append-only, no ORM update/delete

•
•  Stock adjustments above threshold require manager approval via ApprovalWorkflow
•
•  Branch isolation: stock balances scoped to tenant + branch in all queries

IMEI uniqueness enforced at database level with unique index

Integrations

•  Barcode scanner
•  Purchase module (stock receipt)
•  Sales module (stock deduction)
•  Accounting (COGS posting)

Dependencies

•  Module 01
•  Module 02
•  Module 07 (Accounting)

AI Acceleration Opportunities

•  AI can generate: StockLedger repository with all operation types
•  AI can generate: IMEI CRUD and lifecycle state machine
•  AI can generate: Flutter stock count screen with barcode scan loop
•  Manual required: FIFO/Weighted Average cost calculation logic (financial accuracy critical)
•  Manual required: Stock transfer in-transit resolution and conflict handling
•  Manual required: Concurrent stock deduction race condition prevention (optimistic locking)

Module 06: CRM — Customer & Supplier Management

Attribute

Value

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 16

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

Priority

Complexity

🟡 HIGH

Medium

Estimated Time (AI-Assisted)

2 days

Estimated Time (Manual)

6 days

Objective

Unified customer and supplier management: profiles, contact details, credit limits, payment terms, ledger
balances, receivables/payables aging, loyalty points, customer groups, and communication history.

Core Features

•  Customer and supplier master records with full contact details
•  Customer credit limit and credit terms configuration
•  Customer ledger: receivables balance, payment history, aging
•  Supplier ledger: payables balance, payment history, aging
•  Customer groups and pricing tier assignment
•
•  Communication log: notes, calls, follow-up tasks
•  Bulk import/export of customers via CSV
•  Customer statement generation (PDF/Excel)
•  Duplicate detection on phone/email
•  Customer activity timeline

Loyalty points: earn on sale, redeem on next purchase

Backend Requirements

•  Full CRUD for customers and suppliers with validation
•  GET /customers/:id/ledger — account balance, transaction history
•  GET /customers/:id/statement?from=&to= — formatted statement
•  GET /customers/aging — receivables aging buckets (0-30, 31-60, 61-90, 90+)
•  POST /customers/:id/loyalty/redeem — loyalty point redemption with invoice link
•  Bulk import endpoint with validation and error report

Frontend Requirements

•  Customer list with search, filter by group/type/balance
•  Customer profile screen: details, ledger, transactions, loyalty, notes
•  Supplier profile screen: details, ledger, payables
•  Aging report screen with drill-down
•  Quick customer creation modal in POS (inline, without leaving sale)

Database Design Requirements

•  Table: customers (id, tenant_id, name, phone, email, address, group_id, credit_limit, credit_terms,

loyalty_points, status, created_at)

•  Table: suppliers (id, tenant_id, name, phone, email, address, payment_terms, status, created_at)
•  Table: customer_groups (id, tenant_id, name, pricing_tier, discount_pct)
•  Table: ledger_accounts (id, tenant_id, entity_type: CUSTOMER|SUPPLIER, entity_id, balance,

created_at)

•  Table: communication_logs (id, tenant_id, entity_id, entity_type, type, content, created_by, created_at)

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 17

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

•

Indexes: customers(tenant_id, phone), customers(tenant_id, name), ledger_accounts(entity_id)

Security Requirements

•  Credit limit enforcement at POS: system warns/blocks sales exceeding credit limit
•  Customer data accessible only within tenant isolation
•  Soft delete on customers with balance preservation for audit

Integrations

•  SMS/WhatsApp notification for statements (optional)
•  PDF generator for statements

Dependencies

•  Module 01
•  Module 02

AI Acceleration Opportunities

•  AI can generate: all customer/supplier CRUD, profile screens, and ledger display
•  AI can generate: aging report SQL queries
•  Manual required: loyalty point rules engine, credit limit enforcement logic

Module 07: Accounting Engine — Double-Entry, Ledger & Financial
Integrity

Attribute

Priority

Complexity

Value

🔴 CRITICAL

Extreme

Estimated Time (AI-Assisted)

5 days

Estimated Time (Manual)

18 days

Objective

Enterprise-grade double-entry accounting: chart of accounts, journal engine, ledger engine, voucher engine, bank
reconciliation, multi-branch finance, trial balance, P&L, balance sheet, and full audit-safe financial trail. Every
transaction in the system must generate correct accounting entries.

Core Features

Journal vouchers: payment, receipt, contra, journal entries

•  Chart of accounts: Assets, Liabilities, Equity, Revenue, Expenses — fully configurable
•
•  Double-entry enforcement: every debit has a corresponding credit, balanced transactions only
•  Automatic journal posting: sale invoice, purchase invoice, payment, return all auto-post
•  Bank accounts management and bank reconciliation
•  Cash book and bank book reports

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 18

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

•  Trial balance, P&L, balance sheet generation
•  Multi-branch consolidation reports
•  Expense management with category allocation
•  Account receivable and payable sub-ledgers
•  Period closing with journal freeze
•  Audit-safe reversal: no deletion of journal entries, only counter-entries
•  Opening balance import

Backend Requirements

JournalEngine service: postJournal(debitEntries[], creditEntries[]) — validates balance, atomically writes

•
•  All domain events (InvoiceCreated, PaymentReceived, etc.) consumed by JournalEngine
•  GET /reports/trial-balance?date= — computed from ledger_entries
•  GET /reports/profit-loss?from=&to=&branch= — revenue minus expenses
•  GET /reports/balance-sheet?date= — assets, liabilities, equity
•  GET /accounts/:id/ledger — full account transaction history
•  POST /vouchers — manual journal voucher with approval
•  BankReconciliation service: match bank statement items to ledger entries
•  PeriodClose service: freeze past periods, prevent backdated entries

Frontend Requirements

•  Chart of accounts tree: collapsible, searchable, with balance display
•  Voucher entry screen: debit/credit rows, account picker, narration
Ledger screen: filterable by account, date, branch
•
•  Trial balance report with branch/consolidated toggle
•  P&L report: current period vs prior period comparison
•  Balance sheet: asset/liability/equity sections
•  Bank reconciliation screen: side-by-side bank statement vs ledger
•  Expense entry quick form

Database Design Requirements

•  Table: accounts (id, tenant_id, code, name, type: ASSET|LIABILITY|EQUITY|REVENUE|EXPENSE,

parent_id, is_system, branch_id)

•  Table: journal_entries (id, tenant_id, entry_number, reference_id, reference_type, description, posted_by,

period_id, created_at) — IMMUTABLE

•  Table: journal_lines (id, journal_entry_id, account_id, debit, credit, created_at) — IMMUTABLE
•  Table: bank_accounts (id, tenant_id, branch_id, account_name, bank_name, account_number,

current_balance)

•  Table: bank_reconciliations (id, bank_account_id, statement_date, closing_balance, reconciled_by,

reconciled_at)

•  Table: fiscal_periods (id, tenant_id, start_date, end_date, status: OPEN|CLOSED)
•  Table: expense_categories (id, tenant_id, name, account_id)
•  Constraint: journal_entries — sum of all journal_lines must equal zero (debit = credit)
•
•

journal_entries and journal_lines: NO soft delete, NO updates, append-only
Indexes: journal_lines(account_id, journal_entry_id), journal_entries(tenant_id, created_at)

Security Requirements

Journal entries are immutable — delete/update operations blocked at DB constraint level

•
•  Double-entry validation in service layer before any DB write

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 19

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

•  Period closing restricts backdated entries — enforced at API and DB level
•  Financial reports read from ledger only — no denormalized summary tables that could be manipulated
•  All journal postings require authenticated user ID and are audit-logged

Integrations

•  Tax engine
•  Currency exchange rates (if multi-currency)

Dependencies

•  Module 01
•  Module 02
•  Module 03 (Sales events)
•  Module 04 (Purchase events)
•  Module 05 (Inventory events)

AI Acceleration Opportunities

•  AI can generate: chart of accounts CRUD, voucher entry form, ledger display screen
•  AI can generate: trial balance SQL query structure
•  Manual required: JournalEngine double-entry validation logic — this is financial accuracy, no AI shortcuts
•  Manual required: all auto-posting mappings (which accounts to debit/credit for each domain event)
•  Manual required: period closing rules and backdating prevention
•  Manual required: bank reconciliation matching algorithm

Module 08: HR Management, Payroll & Attendance

Attribute

Priority

Complexity

Value

🟡 HIGH

Medium

Estimated Time (AI-Assisted)

3 days

Estimated Time (Manual)

9 days

Objective

Employee management, role and shift assignment, attendance tracking with biometric/manual, leave
management, payroll calculation with deductions, salary disbursement, advance salary, and HR document
management.

Core Features

•  Employee profiles: personal, contact, documents, role assignment
•  Shift management: define shifts, assign to employees, branch-level schedules
•  Attendance: biometric check-in/out, manual override, GPS tag (mobile)
•

Leave types: annual, sick, unpaid — with approval workflow

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 20

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

Leave balance tracking per employee per year

•
•  Payroll calculation: basic + allowances - deductions - advances
•  Salary disbursement with bank transfer integration
•  Advance salary: disbursement, recovery deduction schedule
•  Overtime calculation
•  Payslip generation (PDF)
•  Employee performance notes and warnings
•  Termination workflow with final settlement calculation

Backend Requirements

•  Full CRUD for employees, departments, shifts, attendance, leave, payroll
•  POST /attendance/checkin|checkout — records time with device + GPS
•  POST /payroll/calculate — generates payroll for period (batch operation)
•  POST /payroll/disburse — marks salaries as paid, posts to ledger
•  Domain events: SalaryDisbursed (→ ledger posting), AttendanceMarked
•  PayrollCalculationService: handles all deduction/addition rules

Frontend Requirements

•  Employee list with quick search, role/department filter
•  Employee profile screen with tabbed sections
•  Attendance sheet: monthly grid view, color-coded status
•
•  Payroll run screen: review calculations before disbursement
•  Payslip PDF preview modal

Leave request and approval screen

Database Design Requirements

•  Table: employees (id, tenant_id, branch_id, name, designation, department, joining_date, salary_type,

base_salary, status)

•  Table: shifts (id, tenant_id, name, start_time, end_time, grace_minutes)
•  Table: attendance (id, employee_id, date, check_in, check_out, status, overtime_hours, notes)
•  Table: leaves (id, employee_id, type, from_date, to_date, status, approved_by)
•  Table: payroll_runs (id, tenant_id, period, status, run_by, run_at)
•  Table: payroll_items (id, run_id, employee_id, basic, allowances_json, deductions_json, net_salary,

status)

•  Table: salary_advances (id, employee_id, amount, disbursed_at, recovery_schedule_json, balance)

Security Requirements

•  Payroll disbursement requires manager/HR role authorization
•  Attendance data is auditable — soft edit only with reason
•  Employee documents stored encrypted

Integrations

•  Biometric device integration
•  Bank transfer API (future)
•  PDF generator for payslips

Dependencies

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 21

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

•  Module 01
•  Module 02
•  Module 07 (salary posting to ledger)

AI Acceleration Opportunities

•  AI can generate: employee CRUD, attendance sheet widget, leave form
•  AI can generate: payroll calculation engine skeleton from rules spec
•  Manual required: payroll formula validation, final settlement edge cases

Module 09: Repair Management System

Attribute

Priority

Complexity

Value

🟡 HIGH

Medium

Estimated Time (AI-Assisted)

2 days

Estimated Time (Manual)

7 days

Objective

End-to-end repair job management for electronics/device repair shops: intake, diagnosis, parts assignment, job
status workflow, cost estimation, customer notification, and repair invoice generation.

Core Features

•  Repair job intake: device details, reported issue, customer handover
•  Technician assignment with workload view
•  Status workflow: Received → Diagnosed → In Repair → Quality Check → Ready → Delivered
•  Parts consumption from inventory (deducts stock)
•  Repair cost estimation and approval by customer
•  Customer notifications at status milestones
•  Repair invoice generation on delivery
•  Warranty claim tracking
•  Technician performance report
•  Barcode/QR label for repair job tracking
•  Bulk status updates

Backend Requirements

•  Full CRUD for repair jobs with status state machine
•  POST /repairs/:id/assign-technician
•  POST /repairs/:id/use-parts — deducts parts from inventory
•  POST /repairs/:id/close — generates repair invoice, posts to ledger
•  Domain events: RepairStatusChanged (→ customer notification), RepairClosed (→ invoice + ledger)

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 22

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

Frontend Requirements

•  Repair intake form: device details, issue description, customer signature capture
•  Repair kanban board: columns per status, drag-to-update (desktop)
•  Repair detail screen: full history, parts, cost estimate, notes
•  Technician workload view
•  Repair job QR label print widget

Database Design Requirements

•  Table: repair_jobs (id, tenant_id, branch_id, customer_id, device_type, device_model, serial_no,
reported_issue, technician_id, status, estimated_cost, final_cost, received_at, delivered_at)

•  Table: repair_parts (id, repair_id, product_id, qty, unit_cost)
•  Table: repair_status_history (id, repair_id, old_status, new_status, changed_by, changed_at, notes)
•

Index: repair_jobs(branch_id, status), repair_jobs(customer_id)

Security Requirements

•  Parts deduction requires inventory write permission
•  Customer signature stored as encrypted blob

Integrations

Inventory (parts deduction)

•
•  Sales (repair invoice)
•  Accounting (posting)
•  Notification system

Dependencies

•  Module 01
•  Module 02
•  Module 03
•  Module 05

AI Acceleration Opportunities

•  AI can generate: full repair job CRUD, status state machine, kanban board widget
•  AI can generate: parts usage form with product search
•  Manual required: parts cost allocation to repair job, warranty logic

Module 10: Reporting Engine & Analytics Dashboard

Attribute

Priority

Complexity

Value

🟡 HIGH

High

Estimated Time (AI-Assisted)

3 days

Estimated Time (Manual)

10 days

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 23

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

Objective

Comprehensive reporting suite: operational reports, financial reports, inventory reports, HR reports, and an
executive analytics dashboard with KPI widgets, trend charts, and drilldown capabilities.

Core Features

•  Executive dashboard: today's sales, profit, receivables, payables, stock value
•  Sales reports: by product, customer, cashier, branch, period
•  Purchase reports: by supplier, product, period
•
Inventory reports: stock valuation, movement, aging, low stock
•  Financial reports: trial balance, P&L, balance sheet, cash flow
•  HR reports: attendance summary, payroll register
•  Repair reports: jobs by status, technician performance
•  Scheduled report generation (daily/weekly/monthly email)
•  Export to Excel and PDF
•  Custom date range filters and branch filters
•  Drilldown: click a summary to see underlying transactions
•  Comparison reports: current vs prior period

Backend Requirements

•  All reports served from materialized views or pre-aggregated tables for performance
•  GET /reports/* — all report endpoints with consistent filter parameters
•  POST /reports/schedule — creates scheduled report job
•  ReportExportService: Excel (ExcelJS) and PDF (Puppeteer) generation
•  Analytics pipeline: BullMQ worker processes nightly aggregation jobs
•  Caching: Redis cache for frequently accessed dashboard metrics (TTL 60s)

Frontend Requirements

•  Dashboard home screen with configurable KPI card grid
•  Chart widgets: line chart (sales trend), bar chart (product performance), pie chart (payment methods)
•  Report viewer screen: tabular data with pagination and sort
•  Date range picker with preset options (today, this week, this month, custom)
•  Export button on all reports
•  Drilldown navigation: tap summary → open detail list

Database Design Requirements

•  Table: report_schedules (id, tenant_id, report_type, frequency, filters_json, recipients_json, last_run_at)
•  Materialized views: mv_daily_sales_summary, mv_inventory_valuation, mv_account_balances
•  Analytics events table: analytics_events (id, tenant_id, event_type, dimensions_json, metrics_json,

event_date)

•  Refresh strategy: materialized views refreshed every 15 min by background worker

Security Requirements

•  Reports scoped to user's branch access level
•  Financial reports require accounting_view permission
•  Exported files are temporary S3 links with 24h expiry

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 24

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

Integrations

•  Excel export (ExcelJS)
•  PDF export (Puppeteer/pdf package)
•  Email delivery (SendGrid)

Dependencies

•  Module 02
•  Module 03
•  Module 04
•  Module 05
•  Module 07

AI Acceleration Opportunities

•  AI can generate: all report endpoint boilerplate and SQL query structures
•  AI can generate: chart widget components (fl_chart integration)
•  AI can generate: Excel export templates
•  Manual required: materialized view refresh strategy, complex aggregation SQL

Modules 11–16: Supporting Domain Modules

The following modules are specified at a high level. Each follows the same architectural pattern as modules
01–10.

Domain

Priority

AI Time

Key Deliverables

Mo
dul
e

11

Notification System

HIGH

1.5 days

12

Settings & Configuration

HIGH

2 days

13

14

Device & Hardware
Management

HIGH

2 days

File & Document
Management

MEDIUM

1.5 days

15

Approvals & Workflow
Engine

HIGH

1.5 days

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 25

Push notifications, in-app alerts, email/SMS
dispatch, notification preferences,
read/unread tracking, notification templates

Tenant setup, branch management, tax
configuration, payment method config,
printer config, number series, user
preferences, theme

Printer manager, barcode scanner config,
biometric device integration, device health
monitor, hot-plug detection, fallback routing

File upload to S3/Supabase Storage,
document versioning, OCR extraction,
watermarking, preview generation,
audit-safe archival

Generic multi-level approval chains,
configurable thresholds, approval
delegation, escalation timers, approval audit
trail

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

16

AI Features & Smart
Suggestions

LOW
(V1.1)

3 days

Demand forecasting, reorder suggestions,
anomaly detection, smart search ranking,
customer insights (Phase 2)

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 26

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

3. Recommended Development Order

The following sequence is optimized for dependency resolution, risk front-loading, and parallel development.
Modules are grouped into phases that can be executed concurrently.

Phase

Modules

Duration

Parallel Opportunity

Phase 0:
Foundations

Phase 1: Core
Engines

Phase 2:
Revenue Core

Phase 3:
Operations

Phase 4:
Intelligence

Phase 5: Polish &
Ship

Auth + RBAC (M01), DB
Schema + Infra (M02),
Component Library +
Design System

Week 1, Days 1–5  Auth and DB schema can proceed in

parallel. Component library starts
Day 2.

Sync Engine (M02b),
Inventory Engine (M05),
Accounting Engine (M07)

Week 1 D5 –
Week 2 D5

Inventory and Accounting engines
are independent; run in parallel after
DB schema is stable.

POS Sales (M03),
Purchase (M04), CRM
(M06)

HR/Attendance (M08),
Repair Management
(M09), Approvals (M15)

Reporting (M10),
Notifications (M11),
Settings (M12), Device
Mgmt (M13)

Integration testing, bug
fixes, performance,
deployment pipeline

Week 2 D1 –
Week 2 D7

Sales and Purchase can start once
Inventory + Accounting engines have
stable interfaces.

Week 3 D1 –
Week 3 D5

All three are relatively independent
after core engines exist.

Week 3 D3 –
Week 4 D3

Reporting depends on all domain
data; start after Phase 2 is stable.

Week 4 D3 –
Week 4 D7

All engineers on integration; no new
features.

GOLDEN RULE: Never start a UI screen until its backend API endpoint has a passing
integration test. This rule alone prevents 60% of rework.

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 27

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

4. Complete System Architecture

4.1 Frontend Architecture (Flutter)

Layer

Pattern

Decision

Feature-First Modular Clean Architecture

State Management

Riverpod 2.x — AsyncNotifier for data, Notifier for UI state, StateProvider for
simple flags

Navigation

go_router with deep-link support and role-aware redirect guards

DI

Riverpod providers as DI container; no external DI library needed

Offline Layer

Drift (SQLite) — all entities have local table mirrors; SyncRepository pattern

Network Layer

Dio with interceptors: JWT refresh, retry, error normalization, connectivity check

Component Library

Custom design system: AppTheme, AppColors, AppTypography, AppSpacing
— all design tokens centralized

Platform

Performance

Flutter Desktop (Windows primary), Flutter Mobile (Android), adaptive layouts
via LayoutBuilder

ListView.builder for all lists, RepaintBoundary on heavy widgets, isolate-based
data processing

4.2 Backend Architecture (NestJS + TypeScript)

Layer

Decision

Framework

NestJS — modular, decorator-based, TypeScript native

Architecture Style

Modular Monolith with domain-separated modules — microservice-extractable

API Style

ORM

REST with OpenAPI/Swagger auto-documentation; WebSockets for real-time

TypeORM or Prisma — both viable; Prisma preferred for type safety and
migration tooling

Queue System

BullMQ + Redis — all async operations (notifications, sync, reports, email) go
through queues

Real-time

Validation

Socket.io for WebSocket: live dashboard updates, sync status, notification push

class-validator + class-transformer on all DTOs; custom validators for business
rules

Error Handling

Global NestJS exception filters; typed error codes with i18n error messages

Logging

Winston + Pino — structured JSON logs; correlation IDs on every request

Multi-tenancy

Tenant ID injected via JWT claims; TypeORM repository extended with tenant
filter

4.3 Database Architecture

Component

Decision

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 28

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

Primary DB

PostgreSQL 15+ — ACID, partitioning, RLS, full-text search, JSONB

Cache

Redis 7 — session store, permission cache, queue backend, pub/sub event bus

Local (Client)

Drift (SQLite) on Flutter — full offline capability with typed schema

File Storage

Supabase Storage or AWS S3 — all user uploads, generated PDFs, exports

Migrations

Backups

Prisma Migrate or TypeORM migrations — versioned, rollback-capable, CI-run

Automated daily pg_dump to S3 with 30-day retention; point-in-time recovery
enabled

Partitioning

audit_logs, domain_events, stock_ledger partitioned by created_at monthly

Full-text Search

PostgreSQL GIN indexes + tsvector columns on products, customers — avoids
Elasticsearch dependency

Connection Pooling

PgBouncer in transaction mode — handles high concurrency from multiple app
instances

4.4 Authentication Architecture

•  Access tokens: JWT RS256, 15-minute TTL, contains: sub, tenant_id, branch_id, device_id, role_id,

session_id

•  Refresh tokens: opaque 256-bit random, stored hashed in Redis, 7-day TTL, rotating on use
•  Device tokens: long-lived device registration tokens stored in secure encrypted storage on client
•  Permission matrix: loaded on login, cached in Redis per user+branch, invalidated on role change
•  MFA: TOTP (speakeasy library), backup codes hashed with Argon2, SMS via Twilio
•  SSL pinning: Flutter http_certificate_pinning pins against server cert SHA-256

4.5 Offline-First & Sync Architecture

The sync architecture uses a Vector Clock-inspired approach simplified for practical use:

•  Each entity has a version integer incremented on every mutation
•  Client tracks last_sync_version per entity type per branch
•  Pull sync: GET /sync/pull?entity=&since_version=&branch_id= returns all records changed after version
•  Push sync: POST /sync/push sends batch of local mutations; server validates, resolves conflicts, returns

accepted/rejected/conflicted

•  Conflict resolution: default last-write-wins by updated_at; configurable per entity type
•  Offline queue: Drift table pending_operations(id, entity, operation, payload_json, local_id, created_at,

retries, status)

•  Queue replay: ConnectivityMonitor triggers queue flush on reconnect; exponential backoff on failure
•  Temporary IDs: UUID v7 (time-ordered) used for offline-created records; resolved to server IDs on sync

confirmation

4.6 Event-Driven Architecture

All cross-domain side effects are mediated through the typed domain event bus, never direct service calls:

•  Event bus: Redis pub/sub with BullMQ for persistence guarantee on critical events
•  Event contract: { eventId: UUID, type: string, tenantId, branchId, actorId, timestamp, payload: T }
•  Subscribers: JournalEngine subscribes to InvoiceCreated, PaymentReceived, etc.
•  Subscribers: InventoryEngine subscribes to InvoiceCreated (deduct stock), GRNReceived (add stock)
•  Subscribers: NotificationService subscribes to all status-change events

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 29

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

•  Subscribers: AnalyticsService subscribes to all business events for KPI aggregation
•  Failed events: dead-letter queue with retry logic; critical events (financial) require acknowledgment

4.7 Deployment Architecture

Layer

Container

Decision

Docker Compose (development + staging); single-server Docker for initial
production

Reverse Proxy

Nginx with rate limiting, SSL termination, and static file serving

CI/CD

Secrets

Monitoring

Logging

Scaling

GitHub Actions: test → build → push Docker image → deploy to staging →
manual gate → production

Environment variables via .env files in development; Vault or AWS Secrets
Manager in production

Sentry (error tracking), Prometheus + Grafana (metrics), Uptime Robot
(availability)

Structured JSON logs → stdout → collected by Grafana Loki or CloudWatch

Initial: single VPS with vertical scaling; horizontal scaling via Docker Swarm
when needed

Flutter Distribution

Windows: MSIX packager for enterprise distribution; Android: APK for sideload;
Google Play for managed rollout

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 30

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

5 & 6. AI Toolchain & Complete Development Stack

Tool

Role

Mandator
y?

Tier

Best Use in This Project

Cursor

AI coding IDE

Mandator
y

Pro
($20/mo)

Claude
(Anthropic)

Architecture +
logic reasoning

Mandator
y

Pro
($20/mo)

NestJS endpoint
scaffolding, Riverpod
provider generation,
repository boilerplate,
refactoring across large
codebase

Architecture decisions, sync
protocol design, accounting
journal logic, complex SQL,
code review, documentation

ChatGPT-4o

Code generation
+ SQL

Recomm
ended

Plus
($20/mo)

Database schema
generation, complex SQL
queries, test fixture
creation, quick prototyping

GitHub
Copilot

Inline completion

Recomm
ended

Pro
($10/mo)

Autocomplete repetitive
Flutter/Dart patterns, DTO
generation, test stubs

Lovable / Bolt  UI scaffold
generation

Recomm
ended

Starter
($25/mo)

Rapid Flutter screen
skeleton generation from
wireframe descriptions

Supabase

Backend-as-a-ser
vice

Optional

Free → Pro  Can replace custom NestJS
for simpler modules; use for
file storage regardless

Firebase

Notifications +
Auth fallback

Recomm
ended

Spark (free)

FCM for push notifications,
optional Auth provider

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 31

Limitation
s

Hallucinati
ons in
complex
logic;
never trust
financial/s
ync code
without
review

Context
window
limits on
very large
codebase
s; use with
project
files

Less
reliable
than
Claude for
architectur
e
reasoning

Can
reinforce
bad
patterns;
disable for
critical
logic files

Output
requires
heavy
cleanup
for
production
; good for
first 60%

Less
control
than
custom
NestJS for
complex
business
logic

Vendor
lock-in
risk; use

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

Postman

API development
+ testing

Mandator
y

Free

Linear

Project
management

Recomm
ended

Free

API contract definition,
automated test collections,
mock server for frontend
dev before backend is
ready

Sprint tracking, module
progress, blocker
management

Figma

UI design +
prototyping

Recomm
ended

Free /
Starter

Screen designs, component
library documentation,
developer handoff

Docker

Containerization

Mandator
y

Free

GitHub
Actions

CI/CD automation  Mandator

y

Free (2000
min/mo)

Sentry

Error monitoring

Mandator
y

Free (5k
errors/mo)

Prometheus
+ Grafana

Metrics +
dashboards

Recomm
ended

Free
(self-hosted)

Consistent dev/staging/prod
environments, PostgreSQL
+ Redis local setup, CI/CD
pipeline

Automated test runs on PR,
Docker image builds,
staging deployment, Flutter
build pipeline

Production crash tracking
for both Flutter and NestJS,
sync error visibility,
performance monitoring

API latency, queue depth,
sync health, database
connection pool monitoring

behind
abstractio
n layer

Limited for
complex
async/We
bSocket
testing

Overkill for
solo;
replace
with
Notion if
preferred

Figma-to-
Flutter
requires
manual
translation
; use as
reference
only

Learning
curve for
Docker
Compose
networkin
g

Build
minutes
can be
exhausted
; cache
aggressiv
ely

Volume
costs at
scale; filter
noise
early

Setup
overhead;
use cloud
alternative
if
time-const
rained

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 32

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

7. Team Structure Simulation

For the 30-day timeline, the optimal real team is 3–4 engineers. Below is the full team simulation with AI
replacement analysis.

Role

Responsibilities

Lead Architect /
Backend

Architecture design, sync engine,
accounting engine, event bus,
database schema, security

Backend Engineer

Flutter Engineer

NestJS module development, API
endpoints, services, queue
workers, migrations

All Flutter screens, component
library, state management, offline
layer, hardware integration

DevOps Engineer

QA Engineer

Docker setup, GitHub Actions
CI/CD, Nginx config, monitoring
stack, deployment

Test planning, integration test
authoring, device testing,
regression testing

AI
Replaces?

30%

60%

50%

40%

50%

UI/UX Designer

Screen designs, component specs,
user flow validation

45%

Human Required For

Sync conflict logic, financial
transaction integrity, security
architecture, all critical design
decisions

Complex business logic
validation, performance
optimization, security audits

Platform-specific
printer/scanner integration,
performance tuning, complex
state machines

Production infrastructure
security, backup validation,
incident response

Real device POS testing, printer
hardware testing, offline
scenario testing

Business workflow UX
decisions, usability testing,
edge case UI design

Product Manager

Requirements clarification,
prioritization, stakeholder
communication

20%

All business logic clarifications,
priority calls, scope
management

Solo AI-Assisted Development Model: One senior engineer + Cursor + Claude + GitHub Copilot
can deliver 70% of the above output. The remaining 30% requires focused manual engineering
on: sync engine, accounting engine, financial transactions, and hardware integration.

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 33

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

8. Testing & Quality Assurance Pipeline

8.1 Testing Layers

Layer

Unit Tests
(Backend)

Coverage
Target

80% on
business logic
services

Tooling

Automated?  Critical Areas

Jest +
TypeScript

Yes — CI
runs on every
PR

JournalEngine,
InventoryEngine, PricingEngine,
SyncConflictResolver

Unit Tests (Flutter)  70% on

flutter_test

Yes — CI

CartNotifier, OfflineQueue,
SyncRepository,
PermissionGate

Supertest +
Jest

Yes — CI

All invoice endpoints, all
financial mutation endpoints

Integration Tests
(API)

domain/data
layers

100% happy
path, 80% error
paths

Widget Tests
(Flutter)

Key screens
only

flutter_test
WidgetTester

Yes — CI

POS screen, cart widget,
payment modal, login flow

Sync/Offline Tests  Core sync
scenarios

Custom test
harness

Semi-automa
ted

Jest — formal
assertions

Yes — CI

Manual +
device lab

Manual

Offline → reconnect → sync,
conflict creation + resolution,
queue replay

Double-entry balance, journal
immutability, period close
enforcement

ESC/POS receipt format,
barcode scan accuracy, printer
fallback

k6 or Artillery

Semi-automa
ted

POS endpoint throughput, sync
endpoint under load

OWASP ZAP +
manual

Partial

All permission boundaries, SQL
injection on filter params, JWT
forgery

Sentry +
Prometheus

Automated
alerting

Error rate spikes, sync queue
depth, slow query detection

Financial Integrity
Tests

Hardware Tests

Load Tests

Security Tests

Production
Monitoring

100%
accounting
operations

Printer,
scanner,
biometric

1000
concurrent
invoices

RBAC,
injection, auth
bypass

Continuous

8.2 What AI Can Validate

•  AI (Claude/Cursor) can generate: 80% of unit test cases from function signatures — review all generated

tests before trusting

•  AI can review: code diffs for common anti-patterns, missing null checks, unhandled promise rejections
•  AI can generate: Postman test collections from OpenAPI specs
•  AI cannot validate: real hardware behavior, offline edge cases, financial calculation correctness at scale,

concurrent conflict scenarios

8.3 Non-Negotiable Manual Tests Before Production

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 34

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

1.  Full POS sale cycle on real Windows device with thermal printer: barcode → cart → payment → receipt

print

2.  Offline sale: disconnect network, complete 5 invoices, reconnect, verify all sync correctly
3.  Concurrent sale test: 2 devices sell same last unit simultaneously — verify stock goes negative or is

correctly blocked

4.  Full accounting cycle: sale → payment → return → verify trial balance is always balanced
5.  Permission boundary test: log in as cashier, attempt unauthorized actions (pricing override, refund,

settings access)

6.  Sync conflict test: same record modified offline on 2 devices simultaneously — verify resolution and no

data loss

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 35

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

9. Deployment & Release Strategy

9.1 Environment Strategy

Environment

Description

Local (dev)

Staging

Production

Docker Compose: PostgreSQL + Redis + NestJS + Flutter hot-reload. Every engineer
has identical environment.

VPS (2 vCPU / 4GB RAM): mirrors production config. All feature branches deploy here
automatically via CI.

VPS (4 vCPU / 8GB RAM initially): Docker Compose with Nginx reverse proxy.
Upgradeable to Docker Swarm.

9.2 CI/CD Pipeline (GitHub Actions)

7.  On PR: run backend tests (Jest) + Flutter tests + lint + type-check
8.  On merge to main: build Docker image, push to registry (GHCR), deploy to staging automatically
9.  On manual trigger (release tag): deploy to production after smoke test confirmation
10.  Database migrations run as part of deployment — Prisma migrate deploy (idempotent, CI-safe)
11.  Flutter builds: GitHub Actions builds MSIX (Windows) and APK (Android) on release tags
12.  Rollback: keep last 3 Docker image tags; rollback = redeploy prior tag + migration rollback if needed

9.3 Flutter Distribution Strategy

Platform

Strategy

Windows Desktop  MSIX package signed with self-signed cert (enterprise distribution) or Microsoft Store

(future). Auto-update via custom update server checking version endpoint.

Android

APK sideloading for B2B clients initially. Google Play Internal Track for managed
rollout. Flutter version check on startup.

Update Strategy

App checks /api/version on launch. If server version > client version, shows
mandatory/optional update dialog. Critical updates block the app until updated.

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 36

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

10. Risk Analysis

Risk

Severity  Probabil

Mitigation

Fallback

Sync engine complexity
exceeds timeline

Critical

High

ity

Accounting engine
produces incorrect
entries

Concurrent stock
deduction creates
negative inventory

Critical

Medium

Critical

High

AI-generated code has
subtle bugs in business
logic

High

High

Hardware integration
(printer/scanner) fails on
target devices

High

Medium

Database migration fails
on production
deployment

High

Low

Security vulnerability in
auth or RBAC
implementation

Critical

Low

Data loss during sync
conflict resolution

Critical

Low

Dedicate Week 1 D4-5 to
sync architecture design
only. Implement simplest
correct version
(last-write-wins) first.

Ship with online-only
mode for non-POS
modules; POS offline
sync as Phase 2

100% unit test coverage on
JournalEngine. Formal
assertions: sum(debits) =
sum(credits) on every test.

Disable auto-posting;
manual journal entry
mode until engine is
verified

Optimistic locking (version
check) on stock_balance.
PostgreSQL SELECT FOR
UPDATE on deduction.

Never use AI-generated
code for financial logic,
sync resolution, or security
without full manual review +
tests.

Abstract behind interface;
test on real devices in
Week 3. Printer plugin
known to have Windows
quirks.

Test all migrations on
staging with production
data copy. Use Prisma's
dry-run before applying.

against module pipeline.
Cut scope (AI features,
advanced reports) before
cutting core.

Penetration test auth
endpoints in Week 3.
OWASP ZAP scan before
production.

All conflicted versions are
stored in sync_conflicts
before resolution. No data
is deleted, only
superseded.

Allow negative stock with
alert; retrospective
adjustment workflow

Rewrite any
AI-generated service
that fails its test suite

PDF receipt download
as printer fallback;
manual barcode entry as
scanner fallback

Rollback migration;
restore from backup;
hotfix migration script

Extend timeline by 1
week on non-critical
modules; core POS
ships on time regardless

Take production offline;
hotfix; mandatory re-auth
for all sessions

Manual conflict review
screen; restore from
conflict log

30-day timeline slippage
on critical modules

High

Medium  Daily progress check

Performance degradation
under load (POS latency
> 100ms)

High

Medium  Redis cache for product
search. Indexed queries
validated by EXPLAIN
ANALYZE before shipping.

Add Redis query result
cache; add database
read replica if needed

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 37

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

11. Final 30-Day Execution Roadmap

Week 1: Foundations — Architecture, Infrastructure & Auth

Day  Focus

Deliverables

Integration Milestone

D1

Project setup

D2

Database schema

D3

Auth backend

D4

Auth frontend +
component library

D5

Sync engine

D6

Infrastructure
hardening

D7

Buffer + review

Monorepo init (Turborepo), Flutter
project structure (feature-first), NestJS
app factory, Docker Compose (PG +
Redis), GitHub repo + Actions scaffold,
.env strategy, design token file

Full PostgreSQL DDL (all 16 domain
tables), TypeORM/Prisma schema file,
initial migration run, seed script,
BaseEntity class, RLS policies draft

NestJS Auth module: login, refresh,
logout, MFA, device registration, RBAC
guards, permission matrix API, Redis
session store

Flutter auth screens (login, PIN, MFA),
AppTheme + design tokens, first 20
reusable components (AppButton,
AppInput, AppCard, etc.), Riverpod
auth provider

SyncController (push/pull),
SyncConflictService, Drift offline
schema on Flutter, ConnectivityMonitor,
SyncStatusWidget, domain event bus
setup, BullMQ queue workers

Health check endpoints, centralized
error handling, logging (Winston), rate
limiting, SSL setup, Sentry integration,
staging deployment

Architecture review, fix blockers from
D1-D6, performance baseline test,
documentation pass

Dev environment running on all
machines

Database migrations passing in
CI

Auth API: all endpoints return
correct responses in Postman

Login flow working end-to-end
on device

Push/pull sync working between
Flutter and NestJS

Staging environment live and
accessible

All Week 1 deliverables passing
CI

Expected Blockers

•  Docker networking issues between NestJS and PostgreSQL containers — allocate 2h buffer
•  Flutter local_auth plugin may require platform-specific setup on Windows — test early
•  RLS policy design may uncover schema gaps — have schema review session on D2 EOD

AI Usage Strategy

•  Use Claude for: database schema generation from domain entity specs, NestJS module boilerplate
•  Use Cursor for: TypeORM entity classes, Riverpod provider boilerplate, Flutter screen skeletons
•  Manual only: RLS policy logic, sync conflict resolution algorithm, JWT security configuration

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 38

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

Week 2: Core Engines — Inventory, Accounting & POS Sales

Day  Focus

Deliverables

Integration Milestone

D8

Inventory Engine

D9

Accounting Engine

D10  POS backend

D11  POS frontend

StockLedger service, stock_balance
triggers, IMEI lifecycle service, stock
deduction with optimistic locking,
StockBalance Riverpod provider

JournalEngine (double-entry),
auto-posting event consumers
(InvoiceCreated → ledger), chart of
accounts CRUD, trial balance query,
period management

Inventory deduction API tested
with concurrent requests

Journal entries: sum(debit) =
sum(credit) verified in all unit
tests

Invoice CRUD (atomic: stock + ledger
in one TX), pricing engine, tax engine,
cashier session management, payment
recording, invoice number service

Full POS sale cycle passing
integration test: product → cart
→ invoice → stock deducted →
ledger posted

POS main screen (3-panel), cart
widget, barcode scanner integration,
payment modal, hold/resume, receipt
preview, keyboard shortcuts

POS screen functional on
Windows — complete a sale
end-to-end

D12  Purchase Management  PO/GRN CRUD, purchase invoice

matching, supplier payment, landed
cost, IMEI receipt capture, PO approval
workflow hook

Customer/supplier CRUD, ledger
accounts, credit limit enforcement in
POS, customer groups, bulk import,
aging query

Integration test suite for Week 2
modules, fix bugs found, POS offline
test (disconnect network, complete
sales, reconnect, verify sync)

D13  CRM

D14  Buffer + integration

testing

Expected Blockers

GRN receipt: stock increases,
ledger posts, IMEI records
created

Customer balance visible in
POS, credit limit blocks
oversold

All Week 2 API endpoints
passing integration tests

•  Concurrent stock deduction: optimistic locking implementation may need 2 iterations — test with load tool
Journal auto-posting: mapping of domain events to account codes requires business logic review —
•
prepare accounting config document before D9

•  POS scanner integration on Windows: test with real USB barcode scanner on D11, not emulated input

AI Usage Strategy

•  Use Claude for: accounting journal mapping logic review, inventory FIFO cost calculation
•  Use Cursor for: NestJS POS controller + service boilerplate, Flutter cart state machine
•  Use Copilot for: DTO classes, repository method signatures, test fixtures
•  Manual only: atomic transaction wrapping (invoice + stock + ledger), double-entry validation rule

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 39

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

Week 3: Operations — HR, Repairs, Reporting & Notifications

Day  Focus

Deliverables

Integration Milestone

D15  HR & Attendance

D16  Repair Management

D17  Approval Workflow

Engine

D18  Reporting Engine

D19  Notification System

D20  Settings &

Configuration

D21  Hardware integration +

security audit

Expected Blockers

Employee CRUD, shift management,
attendance recording, leave workflow,
payroll calculation engine, payslip
generation

Repair job CRUD, status state
machine, parts consumption (inventory
deduction), repair invoice generation,
technician assignment

Payroll run generates correct
net salary with all deductions;
ledger posts salary expense

Repair job: intake → parts used
→ close → invoice generated
→ stock deducted

Generic multi-level ApprovalWorkflow
service wired to: PO above threshold,
stock adjustments, discount override,
payroll disbursement

Approval chain: PO created →
notified approver →
approved/rejected → state
updated

Materialized views for KPIs, dashboard
aggregation API,
sales/inventory/financial reports, Excel
export (ExcelJS), PDF export, report
scheduler job

FCM push integration, in-app
notification feed, notification templates,
WebSocket delivery for real-time alerts,
read/unread tracking

Tenant setup, branch management, tax
config, payment method config, printer
settings, number series config, user
preferences

Thermal printer full test (Windows +
Android), barcode scanner multi-device
test, biometric test, OWASP auth scan,
RBAC permission boundary test

Dashboard loads in <2s; sales
report exports to Excel correctly

Push notification delivered on
repair status change; in-app
alert shown on low stock

Settings changes take effect
immediately across all
connected devices

All hardware passing on target
devices; no RBAC permission
leaks found

•  Payroll formula edge cases (advance recovery, partial months) — get business requirements clarified

before D15

•  Materialized view refresh timing: test with real data volume to ensure <2s dashboard load
•  FCM setup requires Firebase project config — set up Firebase project on D14 to avoid D19 blocker

AI Usage Strategy

•  Use Claude for: complex SQL for materialized views, approval workflow state machine design review
•  Use Cursor for: all CRUD boilerplate for HR/Repair modules, notification template generation
•  Use ChatGPT-4o for: ExcelJS export template generation from report column specs

Week 4: Polish, Integration Testing & Production Deployment

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 40

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

Day  Focus

Deliverables

Integration Milestone

D22  Full integration sweep

D23  Performance
optimization

D24  Offline + sync stress

test

D25  Security + compliance

review

D26  Production

environment setup

D27  CI/CD pipeline

finalization + Flutter
builds

D28
-30

UAT + documentation
+ launch

End-to-end workflow test: sale →
inventory → ledger → dashboard.
Purchase → stock → payables. Repair
→ parts → invoice. Fix all cross-module
bugs.

EXPLAIN ANALYZE on all slow
queries, add missing indexes, product
search Redis cache tuning, Flutter
frame rate profiling (DevTools), list
virtualization fixes

Simulate 2-hour offline operation, 200
offline invoices, reconnect, verify
complete sync accuracy. Conflict
resolution test with 2 concurrent
devices.

RBAC full matrix test (all roles × all
modules × all actions), SQL injection
scan, XSS scan on web-facing APIs,
encrypted storage verification, SSL cert
check

Production VPS provisioning, Nginx
config, SSL (Let's Encrypt), production
Docker Compose, production
PostgreSQL with backups, production
secrets, smoke test

GitHub Actions: full pipeline for
backend + Flutter MSIX + Flutter APK.
Release tagging strategy. Rollback
procedure documented and tested.

User acceptance testing with real
business workflows, operator training
documentation, API documentation
(Swagger auto-generated), deployment
runbook, monitoring dashboards
configured, production launch

All critical user journeys pass
without errors on staging

POS product search <100ms;
dashboard load <2s; app
maintains 60fps

Zero data loss on offline→sync
cycle; conflicts logged and
resolvable

All permission boundaries
enforced; no injection
vulnerabilities found

Production server live with
health checks passing

Release pipeline produces
deployable artifacts on git tag

System live in production with
monitoring active; first real
transaction processed

Expected Blockers

•  UAT may surface business logic edge cases in accounting or pricing — keep D29 as buffer for critical

fixes

•  Production SSL certificate provisioning can have DNS propagation delays — start on D25 not D26
•  Windows MSIX signing may require additional setup time — test MSIX build pipeline on D22 not D27

AI Usage Strategy

•  Use Claude for: final code review pass on all financial and sync modules
•  Use Cursor for: documentation generation, Swagger annotations, deployment script generation
•  No new feature development in Week 4 — AI usage restricted to bug investigation and docs

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 41

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 42

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

11b. Corrected Realistic Timeline Estimates

⚠ CRITICAL CORRECTION: The initial 28–32 day solo estimate was optimistic. The following
table reflects realistic production timelines accounting for sync correctness, accounting edge
cases, printer/device chaos, RBAC edge cases, offline replay corruption, migration safety, and
deployment stabilization.

Scenario

1 elite engineer + full
AI stack

Realistic
Timeline

8–12 weeks

High
confidence

Confidence

Key Risk Drivers

Sync correctness alone can consume 2+ weeks.
Accounting edge cases: 1–2 weeks.
Printer/hardware chaos: 3–5 days. RBAC edge
case coverage: 3–4 days. Offline replay
corruption debugging: 3–5 days. Migration safety
iterations: 2–3 days. Deployment stabilization:
3–5 days.

Parallel domain tracks eliminate sequential
bottlenecks. Sync + accounting still block
everything downstream — front-load these.
Week 1 is still architecture-only regardless of
team size.

2 strong engineers +
AI

5–8 weeks

High
confidence

3–4 engineers + AI

4–6 weeks

Medium
confidence

Coordination overhead increases at 4 engineers.
Domain ownership must be strictly assigned to
avoid merge conflicts and architectural drift.
Daily sync meetings mandatory.

MVP only (POS +
Inventory + basic
Accounting)

3–4 weeks (2
engineers)

High
confidence

Deliberately cut: Repairs, HR, AI features,
advanced reports, multi-branch consolidation,
full RBAC matrix. POS bills, stock deducts, basic
ledger posts. Ship this first.

The 6 Components That Always Exceed Estimates

Component

Estimated  Realistic

Why It Takes Longer

Sync engine correctness

3 days

8–12 days

Accounting auto-posting

2 days

5–8 days

RBAC matrix

1 day

3–5 days

Offline replay corruption

1 day

3–6 days

Edge cases multiply: concurrent edits, partial sync
failures, ID resolution, backward compatibility,
corruption recovery, queue ordering guarantees

Every domain event needs a verified debit/credit
mapping. A single incorrect mapping corrupts the
trial balance silently. Each mapping needs a
dedicated test.

Permission edge cases: branch-scoped vs global,
temporary escalation, inherited permissions,
module-level vs action-level conflicts, UI rendering
vs API enforcement alignment

Queue replay with UUID resolution, duplicate
detection, partial sync recovery, and clock skew
handling are all deceptively complex

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 43

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

Printer/hardware
integration

2 days

4–7 days

Migration safety

0.5 days

2–4 days

Windows USB/Bluetooth enumeration, driver
quirks, ESC/POS dialect differences between
printer models, connection state management,
fallback routing

Backward-compatible migrations for offline clients
that may be 1–3 versions behind require
additive-only schema changes and versioned sync
payload contracts

STRATEGIC RECOMMENDATION: Ship a 3-module MVP (POS Sales + Inventory + Basic
Accounting) in 3–4 weeks. Use real-world production data to expose the edge cases that no
spec document can predict. Iterate from there.

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 44

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

12. Architectural Gap Resolutions

The following 10 sections address critical architectural gaps identified in the initial blueprint. Each section provides
a concrete, implementable solution, not just a recommendation.

12.1 Shared Domain Contract Package

Problem: Without a shared contract package, DTO drift, enum mismatches, and event schema
inconsistencies will appear across NestJS, Flutter, and queue workers within the first 2 weeks
of parallel development.

Solution: A monorepo packages/contracts package is the canonical source of truth for all cross-boundary types. It
is consumed by all apps — NestJS imports it as a TypeScript module, Flutter consumes a generated Dart
equivalent via build_runner or manual sync.

Monorepo Structure

Path

apps/api/

Purpose

NestJS backend application

apps/desktop/

Flutter Windows desktop application

apps/mobile/

Flutter Android application

packages/contracts/

SHARED: DTOs, event contracts, enums, API types, permission constants,
error codes, sync payload schemas

packages/ui/

Shared Flutter widget library (design system, components)

packages/domain/

Shared business logic: validators, calculators, state machines (Dart)

packages/utils/

Shared utilities: date formatting, currency, number formatting

packages/config/

Shared configuration schemas, environment variable contracts

docs/adr/

Architecture Decision Records

docs/domain-events.md

Domain Event Registry

packages/contracts/ Contents

•

•

•

•

•
•

enums/: InvoiceStatus, PaymentMethod, UserRole, SyncOperation, StockMovementType,
ApprovalStatus, RepairStatus — all shared enums defined once
dtos/: CreateInvoiceDto, CreateCustomerDto, SyncPushPayload, SyncPullResponse — TypeScript
interfaces shared between API and type-generation
events/: InvoiceCreatedEvent, StockDeductedEvent, PaymentReceivedEvent, SyncConflictEvent —
typed event contracts with payload schemas
errors/: ErrorCode enum (ERR_INVENTORY_NEGATIVE, ERR_LEDGER_IMBALANCE, etc.),
ErrorResponse interface
permissions/: ModulePermission enum, ActionPermission enum, PermissionMatrix type
sync/: SyncRecord interface, SyncPayloadV1 schema, SyncPayloadVersion enum

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 45

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

Flutter Consumption Strategy

•  Option A (preferred): Maintain a parallel packages/contracts_dart/ with manually mirrored Dart

equivalents. Enforce parity via a lint script that compares TypeScript and Dart enum values on every CI
run.

•  Option B: Use json_serializable + a TypeScript-to-Dart code generator (dart_from_json) to auto-generate

Dart models from TypeScript interfaces on every contracts package change.

•  Whichever option: Dart contracts live in packages/contracts_dart/, imported by both desktop and mobile

apps.

•  CRITICAL: Any change to packages/contracts/ must pass a contracts diff review step in CI before merge

— this prevents silent breakage of the Flutter clients.

12.2 API Versioning & Contract Evolution Strategy

Problem: Offline-first clients may be 1–3 versions behind the server. A non-versioned API will
break older clients silently after every deployment — catastrophic for a POS system that must
remain operational during updates.

URL Versioning

•  All API routes prefixed: /api/v1/* — enforced via NestJS global prefix and versioning module
•  New breaking changes → /api/v2/* — v1 supported for minimum 60 days after v2 launch
•  Non-breaking changes (new optional fields, new endpoints) → same version, additive only
•  Deprecation header: X-API-Deprecated: true added to v1 responses once v2 exists

Sync Payload Versioning

•  Every sync payload includes: { schemaVersion: 'v1', ... }
•  Server supports reading schemaVersion v1 and v2 simultaneously during transition
•  SyncPayloadMigratorService: upgrades v1 payloads to v2 format on server before processing
•  Client includes its app version in every sync request header: X-App-Version: 1.4.2
•  Server can reject clients below minimum supported version: responds with 426 Upgrade Required +

download URL

Event Schema Versioning

•  Domain events include: { eventVersion: 1, eventType: 'invoice.created', payload: {...} }
•  Event consumers check eventVersion before processing — unknown versions go to dead-letter queue
•  New event payload fields are always optional — existing consumers ignore unknown fields (additive-only

rule)

Database Migration Compatibility

•  All migrations are additive-only for the first 6 months: add columns (nullable), add tables, add indexes —

never drop or rename

•  Column renames: add new column, dual-write for one version cycle, deprecate old column, remove in

next cycle

•  The sync engine always reads by column name — positional queries are forbidden
•  Migration safety CI check: run automated test against a simulated v1 client → v2 server scenario

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 46

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

12.3 Formal Domain Bounded Context Map

Rule: A domain context owns its data. Other contexts query via published events or exposed
read APIs. No context directly writes to another context's tables.

Bounded
Context

Sales Context

Inventory Context

Accounting
Context

Owns

Publishes Events

invoices,
invoice_items,
payments,
cashier_sessions,
held_sales

stock_balance,
stock_ledger,
imei_records,
stock_transfers,
stock_adjustments

journal_entries,
journal_lines,
accounts,
bank_accounts,
fiscal_periods

InvoiceCreated,
InvoiceReturned,
PaymentReceived,
CashierSessionClosed

StockDeducted,
StockReceived,
StockTransferred,
LowStockAlert, IMEISold

JournalPosted,
PeriodClosed,
BankReconciled

Consumes
Events

CustomerCreditLi
mit (CRM),
ProductPrice
(Inventory),
StockAvailable
(Inventory)

InvoiceCreated
(deduct),
GRNReceived
(add),
StockTransferCon
firmed

InvoiceCreated,
PaymentReceived
, GRNReceived,
SalaryDisbursed,
StockAdjusted

Purchase Context

purchase_orders,
grns,
purchase_invoices,
supplier_payments

PurchaseOrderCreated,
GRNReceived,
SupplierPaid

InventoryLowStoc
k (trigger reorder),
SupplierLedger
(CRM)

CRM Context

HR Context

customers,
suppliers,
customer_groups,
ledger_accounts,
communication_logs

employees, shifts,
attendance, leaves,
payroll_runs,
payroll_items

CustomerCreated,
CreditLimitChanged,
LoyaltyEarned

InvoiceCreated
(loyalty earn),
PaymentReceived
(balance update)

SalaryDisbursed,
AttendanceMarked,
LeaveApproved

None
(self-contained)

Repair Context

repair_jobs,
repair_parts,
repair_status_histor
y

RepairClosed,
RepairStatusChanged,
PartsConsumed

CustomerProfile
(CRM),
StockAvailable
(Inventory)

Forbidden
Dependencies

Must NOT write
to
stock_balance
or
journal_entries
directly

Must NOT write
to accounting
tables. Reads
product master
from Product
Context.

Must NOT read
invoice line
items directly
— only
receives event
payloads

Must NOT write
to
stock_balance
— publishes
GRNReceived
for Inventory
Context to
handle

Must NOT
contain
business logic
for pricing or
inventory

Must NOT
access
financial
accounts
directly —
publishes
SalaryDisburse
d event

Must NOT write
directly to
invoices —
publishes
RepairClosed
for Sales
Context to
create invoice

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 47

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

Notification
Context

Sync Context

Auth Context

notifications,
notification_template
s,
notification_preferen
ces

sync_log,
sync_conflicts,
pending_operations

users, roles,
permissions,
devices, sessions,
audit_logs

None

ALL domain
status-change
events

SyncCompleted,
ConflictDetected

UserRoleChanged,
DeviceRevoked

None

None

Read-only
consumer.
Never writes
business data.

Infrastructure
layer only — no
business logic

Cross-cutting
concern — all
contexts
depend on
Auth for identity
only

12.4 Business Observability & Distributed Tracing Strategy

Problem: Sentry + Prometheus catch technical errors. But for an ERP system, you need to
trace business operations: what happened to invoice INV-2024-001 across every system it
touched.

Correlation ID Architecture

•  Every client request generates a correlationId (UUID v7) on the Flutter side before the API call
•

correlationId travels in the X-Correlation-ID HTTP header through: API → queue jobs → event handlers
→ database writes → sync operations

•  Every log line, event, journal entry, and stock movement record stores the correlationId
•  This enables: query all_logs WHERE correlation_id = 'xyz' → see complete trace of one business

operation

Business Operation Trace Model

Trace Type

What Gets Linked

Invoice lifecycle trace

correlationId links: invoice created → stock deduction → journal posted →
receipt printed → sync queued → sync confirmed

Sync replay trace

Ledger event trace

syncBatchId links: offline operations queued → pushed → conflict detected
→ resolved → confirmed → client notified

journalEntryId links: source event (InvoiceCreated) → journal lines created
→ account balances updated → trial balance affected

Stock movement trace

stockLedgerId links: source operation (sale/purchase/adjustment) →
balance update → alert triggered (if low stock) → reorder suggested

Observability Implementation

•  Use OpenTelemetry SDK (Node.js + Dart) — vendor-neutral, exportable to Jaeger, Grafana Tempo, or

Datadog

•  Custom BusinessEventLogger: logs structured JSON { correlationId, operationType, entityId, tenantId,

branchId, actorId, duration_ms, success, metadata }

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 48

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

•  Grafana dashboard: Business Operations Health — shows invoice creation rate, sync success rate, stock

deduction errors, ledger balance drift alerts

•  Alert rules: sync queue depth > 500 items, accounting imbalance detection, >5% invoice creation errors in

5 minutes

12.5 Centralized State Machine Architecture

Problem: Without a standard, each stateful workflow (repairs, approvals, invoices, transfers,
payroll, sync conflicts) will be implemented differently — some as if/else chains, some as
switch statements, some as database flags. This creates inconsistent audit trails and
untestable transition logic.

Chosen Standard: XState-Inspired Typed State Machines

Both NestJS (TypeScript) and Flutter (Dart) will use the same state machine pattern. No external library required
— implement a lightweight WorkflowEngine in packages/domain/.

State Machine Contract (TypeScript + Dart mirrored)

•  Every stateful workflow defines: StateMachineDefinition<StateEnum, EventEnum>
•  Definition includes: initial state, valid transitions (from: State, event: Event, to: State), guards (conditions

that must be met), side effects (events to emit on transition)

•  WorkflowEngine.transition(entity, event, actor): validates guard, executes transition, records history, emits

side effect events — all atomically

•  Every state transition is recorded in a workflow_history table: entity_type, entity_id, from_state, to_state,

event, actor_id, guard_result, timestamp

Standardized Workflow Definitions

Workflow

States

Key Transitions

Key Guards

Invoice

DRAFT →
CONFIRMED →
PARTIALLY_PAID →
PAID → RETURNED
→ VOID

Confirm (stock check), Pay
(amount validation), Return
(within policy), Void (manager
only)

Stock available before
confirm; payment amount > 0;
return within 30 days

Purchase Order  DRAFT →

SUBMITTED →
APPROVED →
PARTIALLY_RECEIVE
D → RECEIVED →
INVOICED →
CLOSED

PENDING →
APPROVED →
REJECTED →
ESCALATED →
EXPIRED

Approval
Request

Submit, Approve (threshold
guard), Receive (GRN
creation), Invoice (3-way
match)

Approval required above
threshold; GRN qty <= PO
qty

Approve/Reject (approver role
guard), Escalate
(timer-based), Expire (TTL
guard)

Only assigned approver role;
cannot self-approve; TTL
enforcement

Stock Transfer

DRAFT →
IN_TRANSIT →
PARTIALLY_RECEIVE

Dispatch (source deduction),
Receive (destination credit),
Cancel (if in-transit, reversal)

Source stock >= transfer qty;
destination branch exists

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 49

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

Repair Job

Sync Conflict

D → RECEIVED →
CANCELLED

RECEIVED →
DIAGNOSED →
IN_REPAIR → QC →
READY →
DELIVERED →
WARRANTY_CLAIM

DETECTED →
PENDING_REVIEW →
AUTO_RESOLVED →
MANUALLY_RESOLV
ED → CLOSED

Assign technician, Use parts
(stock check), Complete QC,
Notify customer, Deliver

Parts available before use;
customer approval for cost
estimate

Auto-resolve (last-write-wins),
Flag for manual
(business-critical entities),
User resolves, Close

Auto-resolve blocked for:
invoices, journal entries,
stock adjustments

12.6 Analytics Read Model & Reporting Scalability Strategy

Problem: Materialized views on the OLTP database will degrade under concurrent write load.
Refreshing materialized views while processing 1,000+ invoices/day causes lock contention
and dashboard latency spikes.

Phase 1 (Now): Optimized OLTP Analytics

•  Materialized views with CONCURRENTLY refresh — non-blocking, can run while writes proceed
•  Separate analytics user with read-only credentials — cannot accidentally trigger write locks
•  Redis cache layer in front of all dashboard API endpoints: TTL 60 seconds for summary metrics, 300

seconds for trend charts

•  Background worker refreshes materialized views every 5 minutes via BullMQ scheduled job — never on

user request

•  Performance budget: dashboard API endpoint must return in <500ms from Redis cache; <3s from

materialized view

Phase 2 (Post-MVP): Event-Sourced Analytics Pipeline

•  All domain events written to a domain_events table (already in schema) with full payload
•  Analytics worker consumes domain_events and projects into analytics_facts tables: fact_sales,

fact_stock_movements, fact_payments

•  Analytics facts tables are write-optimized (append-only, partitioned by date, no FK constraints)
•  Reports query fact tables, not OLTP tables — complete isolation

Phase 3 (Scale): Dedicated Analytics Database

•  Export domain_events stream to TimescaleDB or ClickHouse via pg_logical replication or Debezium CDC
•  All complex analytics, drilldowns, and forecasting queries run against dedicated read replica
•  Zero impact on OLTP performance
•  Architecture is forward-compatible: the domain_events table exists from Day 1, so Phase 2 and 3 are

additive, not rearchitecting

12.7 Tenant Customization & Extensibility Model

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 50

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

Problem: Enterprise POS clients always require custom fields, custom invoice layouts,
dynamic tax rules, configurable approval chains, and custom workflows. Without a formal
extensibility model, every customization becomes a one-off code change.

Config Registry

•  Table: tenant_configs (id, tenant_id, config_key, config_value_json, module, updated_by, updated_at)
•  ConfigRegistryService: get(tenantId, key, defaultValue) — typed accessor with fallback to system defaults
•  All module-level business rules (approval thresholds, credit limit defaults, tax rates, invoice numbering

format) stored in tenant_configs, not hardcoded

Custom Fields (Metadata-Driven Forms)

•  Table: custom_field_definitions (id, tenant_id, entity_type, field_key, field_label, field_type:

TEXT|NUMBER|DATE|SELECT|BOOLEAN, required, options_json, sort_order)

•  Table: custom_field_values (id, entity_type, entity_id, field_key, value_text, value_number, value_date)
•  Flutter: CustomFieldsForm widget renders dynamic forms from field definitions — no hardcoded fields
•  Custom field values synced as part of their parent entity's sync record

Custom Invoice Layouts

•  Table: invoice_templates (id, tenant_id, name, template_type: THERMAL|A4|A5, layout_json, is_default)
•
•  Template JSON schema defines: logo position, column layout, which fields show, footer text, tax display

InvoicePrintService selects template by tenant + invoice type — renders accordingly

format

Configurable Approval Chains

•  Table: approval_chain_configs (id, tenant_id, workflow_type, threshold_amount, levels_json,

•

escalation_ttl_hours)
levels_json: [{ level: 1, required_role: 'MANAGER', min_approvers: 1 }, { level: 2, required_role:
'DIRECTOR', min_approvers: 1 }]

•  ApprovalWorkflowService reads chain config from database — fully configurable per tenant without code

changes

12.8 Migration Safety Strategy for Offline-First Systems

Problem: In an offline-first system with multiple client devices, schema migrations cannot
assume all clients are on the latest version. An old client can push sync payloads referencing
columns that no longer exist, or missing columns that are now required.

The Additive-Only Migration Rule

•  For the first 12 months: ALL database migrations must be purely additive: new tables, new nullable

columns, new indexes — never drop, rename, or add NOT NULL to existing columns

•  Exception: dropping tables/columns is permitted only after: (a) column deprecated for 2 release cycles,

(b) all clients confirmed on new version via version check endpoint

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 51

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

Sync Compatibility Matrix

•  Server maintains a minimum_client_version config value — any client below this version has sync

blocked and receives 426 with upgrade instructions

•  Server maintains a sync_schema_version integer — every sync request includes the client's

sync_schema_version

•  SyncPayloadMigratorService upgrades old payloads to current schema before processing
•  Client migration on update: when Flutter app updates, it runs a local Drift migration before the first sync —

ensures local schema matches server expectations

Migration CI Validation

•  CI step: apply new migration against a copy of the production database (restored from last backup)
•  CI step: run simulated v(n-1) client sync against v(n) server — verify no payload rejection errors
•  CI step: run backward compatibility test — v(n) server must correctly process v(n-1) sync payloads
•  Any migration that fails the backward compatibility test is blocked from merge

12.9 Enforced Performance Budget System

Defining performance targets is not enough. Performance budgets must be enforced in CI — a
budget regression blocks a merge, not just triggers a warning.

Performance Budget Table

Component

Budget

Measurement Method

CI Enforcement

POS product search
(cached)

POS product search
(cold)

< 80ms p95

< 200ms p95

Invoice creation (single)

< 500ms p95

k6 load test: 50 concurrent
searches

k6: first request after Redis
flush

k6: full invoice creation with
stock + ledger

Fail CI if p95 > 100ms

Fail CI if p95 > 300ms

Fail CI if p95 > 800ms

Invoice creation
(concurrent)

< 1s p95 at 50
concurrent

k6: 50 concurrent invoice
creation

Fail CI if p95 > 2s

Dashboard load (cached)  < 500ms

Sync pull (1000 records)

< 3s

Supertest: dashboard API
response time

Fail CI if > 800ms

k6: pull sync with 1000-record
delta

Fail CI if > 5s

Flutter frame rate (POS
screen)

Flutter app startup (cold)

60fps sustained  Flutter DevTools widget build

time < 16ms

< 3s to
interactive

Manual measurement on
target device

Manual check; flag if >
16ms builds detected

Manual gate before release

API response payload
size

< 50KB per
response

Supertest: measure
Content-Length header

Warn CI if > 100KB; fail if >
500KB

DB query (any single
query)

< 100ms

PostgreSQL slow query log
threshold: 100ms

Alert if slow query log
entries appear in CI test
suite

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 52

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

CI Performance Pipeline

k6 load test script runs in CI against staging environment on every merge to main

•
•  Threshold configuration in k6 script maps directly to the budget table above
•  PostgreSQL slow query log enabled in staging — CI fails if any new slow queries appear after a PR
•  Flutter DevTools performance trace generated on CI for the POS screen — widget build times logged
•  Performance regression alerts: Grafana alerts when p95 latency exceeds 150% of the established

baseline

12.10 Formal Centralized Error Code System

A centralized error code system shared across frontend, backend, logs, and monitoring is essential for debugging,
user communication, and support workflows. Error codes live in packages/contracts/errors/.

Error Code

Domain

ERR_AUTH_INVALID_CR
EDENTIALS

Auth

HTTP
Statu
s

401

ERR_AUTH_DEVICE_UNA
UTHORIZED

Auth

403

ERR_AUTH_SESSION_EX
PIRED

Auth

401

ERR_AUTH_MFA_REQUI
RED

Auth

403

User Message

Internal Action

Invalid username or
password.

Log failed attempt;
increment rate limit counter

This device is not
authorized. Contact
your administrator.

Your session has
expired. Please log in
again.

Multi-factor
authentication is
required.

Log device attempt; alert
admin if repeated

Clear local session;
redirect to login

Redirect to MFA screen

ERR_PERMISSION_DENI
ED

RBAC

403

You do not have
permission to perform
this action.

Log permission violation
with actor + action +
resource

ERR_INVENTORY_INSUF
FICIENT_STOCK

Inventory

422

Insufficient stock for
this product.

ERR_INVENTORY_NEGAT
IVE_STOCK

Inventory

422

ERR_INVENTORY_IMEI_D
UPLICATE

Inventory

422

This operation would
result in negative
stock.

This IMEI is already
registered in the
system.

Show available qty;
suggest alternative or
backorder

Block operation; require
adjustment workflow

Show existing IMEI record;
flag for review

ERR_INVENTORY_IMEI_A
LREADY_SOLD

Inventory

422

This IMEI has already
been sold.

Show sale history for that
IMEI

ERR_ACCOUNTING_LED
GER_IMBALANCE

Accounting  500

ERR_ACCOUNTING_PERI
OD_CLOSED

Accounting  422

A financial posting
error occurred.
Transaction rolled
back.

CRITICAL ALERT: Page
on-call; log full journal
attempt; do NOT retry
automatically

This accounting period
is closed. Backdated
entries are not allowed.

Show period close date;
suggest journal in current
period

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 53

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

ERR_ACCOUNTING_DOU
BLE_ENTRY_VIOLATION

Accounting  422

ERR_SYNC_CONFLICT

Sync

409

ERR_SYNC_VERSION_IN
COMPATIBLE

Sync

426

ERR_SYNC_QUEUE_OVE
RFLOW

Sync

429

Journal entry debits
and credits do not
balance.

Log attempted entry; return
diff amount to caller

A sync conflict was
detected. Please
review and resolve.

Create sync_conflict
record; notify user; do NOT
auto-apply

Please update the
application to continue
syncing.

Block sync; provide
download URL

Sync queue is full.
Please wait and try
again.

Alert ops; increase queue
capacity if persistent

ERR_VALIDATION_REQUI
RED_FIELD

Validation

400

Required field missing:
{fieldName}

Return field name in error
details

ERR_APPROVAL_REQUI
RED

Approval

403

This action requires
manager approval.

Trigger approval request
workflow; notify approver

ERR_APPROVAL_SELF_A
PPROVAL

Approval

403

You cannot approve
your own request.

Block action; log attempt

Implementation

•  TypeScript: ErrorCode enum exported from packages/contracts/errors/error-codes.ts
•  NestJS: CustomExceptionFilter maps ErrorCode → HTTP status + structured response: { error: { code,

message, details } }

•  Flutter: AppException class wraps error codes; ErrorHandler widget renders user-facing messages from

localized error map
Logging: every error log includes the ErrorCode — enables Grafana alerts keyed to specific error codes

•
•  Monitoring: Sentry tags every exception with its ErrorCode — enables error rate dashboards per code

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 54

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

13. Critical Architectural Additions

13.1 Monorepo Architecture (Turborepo)

A Turborepo monorepo is not optional for this system — it is the foundation that makes AI-assisted development
reliable and prevents type drift across 3 apps and 5+ packages.

Why Turborepo Specifically

•
Incremental builds: only rebuilds packages that changed — critical for fast CI when you have 3 apps
•  Task pipelines: turborepo knows that building apps/api depends on packages/contracts — rebuilds in

correct order automatically

•  Remote caching: Vercel remote cache means CI doesn't rebuild unchanged packages — 70% faster CI

runs

•  Workspace awareness: npm/yarn/pnpm workspaces + Turborepo = one node_modules, shared

dependency deduplication

Initial Turborepo Setup

Configuration

Implementation

turbo.json pipeline

build depends on ^build (dependencies first), test depends on build, lint runs
independently

packages/contracts/
build

tsc compiles TypeScript to dist/ — both apps/api and any type-generation
consume from dist/

Dart contract sync

turbo task: generate:dart — runs a custom script that converts
packages/contracts/dist/ to Dart models in packages/contracts_dart/lib/

Shared ESLint config

packages/config/eslint/ — one ESLint config consumed by all TypeScript
packages and apps

Shared tsconfig

packages/config/tsconfig/ — base tsconfig.json extended by all TypeScript apps
with path aliases

13.2 Domain Event Registry (docs/domain-events.md)

The Domain Event Registry is a living document maintained in the monorepo at docs/domain-events.md. It is the
authoritative reference for every event in the system — who publishes it, who consumes it, what the payload looks
like, and what the retry and criticality rules are.

Event Type

Publisher

Consumers

invoice.created

Sales Context

Inventory (deduct
stock), Accounting
(post journal),
Notification (receipt),
Analytics (KPI update)

Payload (key
fields)

Critical
ity

Retry
Policy

invoiceId,
tenantId,
branchId,
customerId,
items[],
totalAmount,
correlationId

CRITIC
AL

Retry 3x
with
exponenti
al backoff;
dead-letter
after 3
failures;

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 55

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

payment.received  Sales Context

Accounting (post to
receivables), CRM
(update customer
balance), Notification
(payment confirmation)

paymentId,
invoiceId, method,
amount,
customerId,
correlationId

stock.deducted

Inventory
Context

Accounting (COGS
posting), Analytics
(stock movement KPI)

stock.low_alert

Inventory
Context

Notification (alert
manager), Purchase
(suggest reorder)

grn.received

Purchase
Context

approval.required

Approval
Context

Inventory (add stock),
Accounting (post to
payables), CRM
(update supplier
balance)

Notification (notify
approver), Workflow
(set pending state)

repair.status_chan
ged

Repair
Context

Notification (customer
SMS/push)

salary.disbursed

HR Context

Accounting (salary
expense posting)

sync.conflict_dete
cted

Sync Context

Notification (alert user),
Workflow (set manual
review state)

CRITIC
AL

CRITIC
AL

HIGH

productId, qty,
branchId,
costPerUnit,
sourceInvoiceId,
correlationId

productId,
branchId,
currentQty,
reorderPoint,
correlationId

grnId, poId,
supplierId, items[],
landedCost,
correlationId

CRITIC
AL

HIGH

MEDIU
M

CRITIC
AL

HIGH

requestId,
workflowType,
requestorId,
approverId,
thresholdAmount,
correlationId

repairId,
customerId,
oldStatus,
newStatus,
technicianId,
correlationId

payrollRunId,
employeeId,
netSalary, period,
correlationId

conflictId,
entityType,
entityId, deviceId,
correlationId

ALERT
ops

Retry 3x;
dead-letter
; ALERT
ops

Retry 3x;
dead-letter
; ALERT
ops

Retry 2x;
discard if
still failing;
log
warning

Retry 3x;
dead-letter
; ALERT
ops

Retry 3x;
escalate if
no
approval
in TTL

Retry 2x;
log if fails;
non-blocki
ng

Retry 3x;
dead-letter
; ALERT
ops

No retry
— conflict
requires
human
action

Retry 5x; if
fails, force
re-login for
affected
user

user.role_change
d

Auth Context

RBAC cache
invalidation (all
sessions for that user)

HIGH

userId, oldRoleId,
newRoleId,
changedBy,
correlationId

Event Registry Governance Rules

•  Any new event type must be added to domain-events.md BEFORE the code is merged — PR without

registry entry is rejected in CI review

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 56

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

•  Event payload changes must be backward-compatible (additive-only) — breaking changes require a new

event version (e.g., invoice.created.v2)

•  Criticality CRITICAL means: the event consumer's failure must be alerted immediately, not just logged
•  All CRITICAL events go through BullMQ with persistence — not fire-and-forget Redis pub/sub

13.3 Architecture Decision Records (docs/adr/)

ADRs prevent future architectural chaos by documenting why decisions were made, not just what was decided.
Each ADR is a short Markdown file in docs/adr/.

Decision

Rationale Summary

Consequences

ADR
Numb
er

ADR-
001

Modular Monolith over
Microservices

ADR-
002

PostgreSQL as
primary database

ADR-
003

Redis for event bus
and cache

ADR-
004

Drift (SQLite) for
Flutter offline storage

ADR-
005

Riverpod over BLoC
for state management

ADR-
006

Last-write-wins as
default sync conflict
resolution

System is too interconnected for
microservices at this stage.
Distributed transactions (stock +
accounting in one operation)
require coordination overhead that
outweighs microservice benefits.
Monolith is faster to ship, easier to
refactor, and can be split later.

ACID transactions required for
financial integrity. Double-entry
accounting needs atomic multi-row
writes. RLS for tenant isolation.
Full-text search avoids
Elasticsearch dependency. Proven
at scale for ERP workloads.

BullMQ requires Redis. Permission
cache and product search cache
both benefit from Redis. Avoiding a
separate message broker (Kafka)
reduces infrastructure complexity
at this scale.

Drift provides type-safe Dart code
generation, migration support, and
reactive streams. Superior to Isar
for schema migration tooling —
critical for an offline-first system
with evolving schema.

Riverpod's compile-time safety,
provider overriding (for testing),
and AsyncNotifier pattern fit this
app's data-heavy screens better
than BLoC's event/state verbosity.
Easier to reason about with AI
assistance.

For a POS system, most conflicts
are benign (product name update,
customer address update).
Last-write-wins handles 95% of
cases automatically. Manual
resolution reserved for financial
entities.

Single deployment unit. All
modules share DB connection
pool. Future extraction requires
anti-corruption layers.

Single DB is a scaling bottleneck
at extreme volume. Mitigated with
read replicas and materialized
views.

Redis is a single point of failure for
event delivery. Mitigated with
Redis Sentinel for HA in
production.

Larger app bundle than Isar. Drift
migrations must be maintained in
sync with server-side migrations.

Team must learn Riverpod 2.x
patterns. Less community
examples than BLoC for complex
scenarios.

Financial conflicts (invoices,
journal entries) are explicitly
excluded from last-write-wins and
require manual resolution.

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 57

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

ADR-
007

TypeScript for NestJS
over Go

ADR-
008

Optimistic locking for
concurrent stock
deduction

NestJS provides faster
development velocity, richer
ecosystem for CRUD-heavy ERP
operations, and better AI code
generation support. Go's
performance advantage only
matters at extreme concurrency
that this system won't reach
initially.

Pessimistic locking (SELECT FOR
UPDATE) blocks concurrent POS
terminals. Optimistic locking
(version check + retry) allows
parallel sales while protecting
integrity — better UX under normal
load.

Node.js single-thread model
requires careful CPU-bound
operation handling — offload to
worker threads or queues.

Requires retry logic on version
conflict. Under extreme concurrent
load (flash sale), retry storms
possible — mitigated with jitter.

13.4 Test Data Strategy

Missing test data is one of the most common causes of performance issues appearing too
late. A synthetic enterprise dataset that mirrors real-world scale must exist in Week 1, not
Week 4.

Test Dataset Tiers

Tier

Description

Tier 1: Unit test fixtures  Minimal in-memory fixtures: 3–5 products, 2 customers, 1 branch. Generated by

factory functions in test/factories/. Used in all unit tests.

Tier 2: Integration test
seed

Realistic dataset: 100 products, 50 customers, 5 suppliers, 3 branches, 2
warehouses, 500 historical invoices, 1000 stock ledger entries. Seeded via npm
run seed:integration. Used in all API integration tests.

Tier 3: Performance
test dataset

Enterprise-scale: 10,000 products, 5,000 customers, 1,000 suppliers, 10
branches, 100,000 invoices (1 year), 500,000 stock ledger entries, 200,000
journal entries. Seeded via npm run seed:performance. Used only in k6 load
tests.

Tier 4: Offline conflict
fixtures

Specifically crafted sync conflict scenarios: 2 devices editing same customer
simultaneously, 2 cashiers selling last unit concurrently, offline invoices created
with same product at conflicting prices. Used in sync integration tests.

Tier 5: Corruption
recovery fixtures

Intentionally malformed sync payloads: missing required fields, invalid UUIDs,
circular references, truncated JSON. Used to test error handling and graceful
degradation.

Test Data Generation

•  All test data generated by @faker-js/faker (TypeScript) and faker (Dart) — never manually written JSON

fixtures

•  Factory pattern: CustomerFactory.create(overrides?), InvoiceFactory.createWithItems(itemCount),

StockLedgerFactory.createHistory(days, product) — composable, parameterized

•  Performance dataset generation runs in parallel via worker threads — seeding 100,000 invoices should

take < 2 minutes

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 58

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

•  Seed scripts are idempotent: running twice produces the same dataset, no duplicate errors
•  CI uses Tier 2 seed on every test run — database is reset and reseeded between test suites
•  Tier 3 performance dataset is generated once and stored in S3 — loaded via pg_restore, not regenerated

each time

Offline Conflict Fixture Scenarios (Must Test Before Production)

13.  Concurrent last-unit sale: Device A and Device B both read stock = 1, both create invoices offline, both

sync — one must succeed, one must fail with ERR_INVENTORY_INSUFFICIENT_STOCK

14.  Customer update conflict: Device A updates customer phone offline, Device B updates same customer
email offline, both sync — result must be: both phone AND email updated (merge, not overwrite)
15.  Invoice payment race: Server processes payment for INV-001, offline device also creates payment for

same invoice — duplicate payment must be detected and rejected

16.  Journal imbalance injection: Artificially inject an event that would cause JournalEngine to create an

imbalanced entry — verify it fails with ERR_ACCOUNTING_DOUBLE_ENTRY_VIOLATION and rolls
back

17.  Clock skew conflict: Offline device with 30-minute clock skew syncs — verify updated_at comparison

handles skew correctly without corrupting newer data

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 59

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

Final Architecture Decision Record & Summary

This document represents the complete, gap-resolved master execution blueprint for LUMINA
POS / Stock Bridge ERP. Every architectural decision is driven by the four non-negotiables:
financial integrity, offline resilience, multi-tenant security isolation, and long-term
maintainability.

Attribute

Value

Total Estimated Timeline (1
engineer + AI)

Total Estimated Timeline (2
engineers + AI)

MVP Timeline (POS + Inventory +
Basic Accounting)

AI Acceleration Multiplier

8–12 weeks to full production

5–8 weeks to full production

3–4 weeks (2 engineers) — RECOMMENDED first milestone

3–4x on assembly; 1x on architecture, sync, financial logic,
hardware

Recommended Launch Config

NestJS API + PostgreSQL + Redis; Flutter Desktop (Windows) +
Mobile (Android); single VPS initially

Monorepo Tool

Turborepo with pnpm workspaces

Contract Governance

packages/contracts/ as single source of truth; CI enforces parity

API Versioning

State Machine Standard

Error Code System

/api/v1 from Day 1; additive-only changes; minimum_client_version
enforcement

Typed WorkflowEngine in packages/domain/; all stateful workflows
use it

Centralized ErrorCode enum in packages/contracts/errors/; shared
across all layers

Performance Enforcement

k6 budgets enforced in CI; slow query log in staging; Flutter
DevTools in release gate

Observability

Post-Launch Priority 1

Post-Launch Priority 2

correlationId on every operation; OpenTelemetry;
BusinessEventLogger; Grafana dashboards

Sync edge case monitoring; accounting balance daily reconciliation
check; performance baseline establishment

Analytics read model (fact tables); AI features; multi-language;
Kubernetes migration planning

Critical Success Metric (Month 1)

Zero financial discrepancies; zero data loss on sync; POS operates
fully offline for 8+ hours

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 60

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

12. Implementation Discoveries & Security

12.1 What Is Still Naturally Undefined (And Should Be)

These are implementation-phase discoveries, not planning failures:

Area

Why It's Not Fully Defined Yet

Exact UI behavior

Evolves during usability testing

Final printer abstraction quirks

Hardware-specific

Sync heuristics

Refined with real data

Advanced analytics schemas

Depend on production usage

Performance bottlenecks

Only visible under load

Tenant-specific workflows

Emerge from real customers

Reporting formats

Business-driven iteration

AI recommendation quality

Requires real datasets

Those are expected unknowns.

12.2 The Only Major Thing Still Missing

There is only ONE major enterprise layer still not deeply specified:

FORMAL SECURITY ARCHITECTURE DOCUMENT

You have:

•  RBAC
JWT
•
•  RLS
•  Encryption
•  OWASP testing

But not a full:

•  Threat model
•  Attack surface map
•  Secrets rotation policy
•  Key management lifecycle
•  Audit retention policy
•
Incident response process
•  Tenant isolation penetration plan
•  Rate-limit strategy matrix

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 61

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

•  Device trust lifecycle
•  Backup restoration verification strategy

That is usually a separate security document anyway.

So this is not a flaw — just the next architectural document.

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 62

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

13. Enterprise Security Architecture & Operational Security
Governance

13.1 Security Architecture Objectives

The security architecture of LUMINA POS / Stock Bridge ERP is designed around five non-negotiable principles:

18.  Multi-tenant isolation
19.  Financial data integrity
20.  Device trust enforcement
21.  Offline-safe security resilience
22.  Full operational auditability

The platform must remain secure under:

offline operation
concurrent multi-device usage
branch-level operational segregation
hostile network environments
credential compromise attempts

•
•
•
•
•
•  malicious insider behavior
•

partial infrastructure outages

The security model follows:

•  Zero Trust principles
•  Defense in Depth
•
•
•  Secure-by-Default infrastructure

Least Privilege Access
Immutable Auditability

13.2 Threat Model

Threat Category

Example Threat

Severity  Mitigation Strategy

Credential
Compromise

Password theft / phishing

Critical

MFA, Argon2id, suspicious login detection,
rotating refresh tokens

Device Theft

Stolen cashier tablet

Critical

Device binding, remote revocation,
session invalidation, encrypted local
storage

Tenant Data
Leakage

Cross-tenant query
exposure

Critical

PostgreSQL RLS, tenant-aware
repositories, mandatory tenant context

Offline Tampering

Local DB modification

Critical

API Abuse

Brute force or scraping

High

AES-256 encrypted local DB, signed sync
payloads, integrity verification

Rate limiting, IP throttling, WAF, anomaly
scoring

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 63

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

Session Hijacking

Token interception

Critical

Event Bus Spoofing

Fake domain events

High

Privilege Escalation

Insider Threat

Backup
Compromise

Unauthorized admin
access

Unauthorized financial
edits

Critical

Critical

Stolen database backup

High

Supply Chain Risk

Malicious dependency

High

TLS, SSL pinning, rotating refresh tokens,
short-lived JWT

HMAC signing, internal-only event
channels

RBAC guards, immutable audit logs,
permission diff tracking

Approval workflows, immutable journals,
audit correlation tracing

Encrypted backups, key rotation,
access-controlled storage

Dependency scanning, lockfile
enforcement, SAST pipeline

Sync Replay Attacks  Duplicate sync replay

High

Idempotency keys, sync version validation,
nonce validation

Malware on
Endpoint

Keylogging or memory
scraping

Medium  Device trust scoring, session expiration,

anomaly detection

13.3 Attack Surface Map

External Attack Surfaces

23.  Public REST API
24.  Authentication endpoints
25.  Sync endpoints
26.  File upload endpoints
27.  Export/download endpoints
28.  Notification webhooks
29.  Mobile/Desktop applications
30.  QR authentication workflows
31.  Email recovery workflows
32.  Third-party integrations

Internal Attack Surfaces

33.  Redis cache layer
34.  BullMQ workers
35.  Event bus infrastructure
36.  PostgreSQL database
37.  CI/CD pipelines
38.  Docker host
39.  Internal admin tools
40.  Monitoring dashboards
41.  Backup storage infrastructure
42.  Secrets management infrastructure

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 64

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

Security Boundaries

Boundary

Client → API

Protection Layer

TLS + SSL pinning + JWT

API → Database

Private network + least privilege DB role

API → Redis

Authenticated internal connection

Workers → Event Bus

Signed event envelopes

Database → Backups

AES-256 encrypted snapshots

Admin Actions

MFA + audit logging + approval workflows

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 65

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

13.4 Authentication & Session Security

Authentication Standards

43.  JWT RS256 access tokens
44.  15-minute access token TTL
45.  Rotating refresh tokens
46.  Refresh token revocation tracking
47.  Device-scoped sessions
48.  Branch-scoped session isolation
49.  Mandatory MFA for privileged roles
50.  Argon2id password hashing
51.  Biometric login support (client-side only)
52.  Suspicious login escalation workflow

Session Security Requirements

53.  Sessions tied to device fingerprint
54.  Remote session invalidation supported
55.  Idle timeout enforcement
56.  Concurrent session monitoring
57.  Geo-location anomaly detection
58.  Session risk scoring
59.  Automatic re-authentication after privilege elevation
60.  Token replay detection
61.  Session activity heartbeat validation
62.  Revoked session blacklist cache in Redis

Device Trust Lifecycle

Device State

Description

Pending

Trusted

Device registered but awaiting approval

Approved operational device

Restricted

Limited-access device requiring MFA

Suspicious

Device flagged by anomaly engine

Revoked

Expired

Device permanently blocked

Device trust expired due to inactivity

Device Trust Rules

63.  New device registration requires admin approval
64.  Device fingerprint mismatch forces re-authentication
65.  Revoked devices cannot reuse prior session tokens
66.  High-risk actions require trusted device state
67.  Device inactivity >90 days expires trust automatically

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 66

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

68.  Hardware changes increase device risk score
69.  Offline sessions expire after configurable threshold

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 67

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

13.5 Authorization & RBAC Governance

Authorization Principles

70.  Default deny access model
71.  Role → module → action → branch scope hierarchy
72.  Every request evaluated against permission matrix
73.  Branch isolation enforced independently of UI visibility
74.  Financial actions require elevated permissions
75.  Critical operations require dual authorization support

Protected Operations

The following operations must always generate immutable audit logs:

76.  Permission changes
77.  Role assignment changes
78.  Invoice cancellation
79.  Journal reversal
80.  Inventory adjustment
81.  Refund approval
82.  Device approval/revocation
83.  Export/download of sensitive data
84.  Tax configuration changes
85.  User account suspension

Permission Governance

86.  System roles are immutable
87.  Permission changes require justification note
88.  Permission diff history retained permanently
89.  Branch-scoped permissions enforced server-side
90.  Emergency override actions require elevated audit severity

13.6 Secrets Management & Key Lifecycle

Secrets Storage Strategy

Environment

Development

Staging

Production

Strategy

.env files excluded from git

Docker secrets or Vault

Vault or AWS Secrets Manager

Managed Secrets

91.  JWT private keys
92.  Database credentials

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 68

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

93.  Redis credentials
94.  SMTP credentials
95.  SMS provider credentials
96.  API integration keys
97.  Backup encryption keys
98.  Event bus signing keys
99.  TLS certificates
100.

Sentry/Grafana credentials

Key Rotation Policy

Secret Type

JWT signing keys

Database passwords

Redis credentials

API keys

Backup encryption keys

Rotation Interval

90 days

60 days

60 days

90 days

180 days

TLS certificates

Automatic renewal before expiry

Key Security Requirements

101.  No secrets stored in source control
102.  No plaintext credentials in logs
103.
104.
105.

Secret access fully audited
Production secrets accessible only via least privilege IAM
Emergency key revocation procedure documented

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 69

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

13.7 Data Protection & Encryption Standards

Encryption Requirements

Data Type

API traffic

Local offline database

Refresh tokens

Passwords

Backup archives

Event payload signing

Encryption Standard

TLS 1.3

AES-256

SHA-256 hash + salt

Argon2id

AES-256-GCM

HMAC SHA-256

Sensitive config values

AES-256

Sensitive Data Classification

Critical

•
•
•
•

financial journals
payment data
authentication secrets
tenant records

High

•
•
•
•

employee information
inventory valuation
customer balances
audit trails

Medium

•
•
•

analytics aggregates
operational metrics
cached catalogs

Data Retention Rules

Data Type

Audit logs

Financial journals

Session logs

Security incidents

Sync logs

Backup archives

Retention Policy

Permanent

Permanent

180 days

3 years

90 days

30 daily + 12 monthly snapshots

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 70

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

13.8 Auditability & Compliance Controls

Audit Log Requirements

Audit logs must be:

•
•
•
•
•
•
•
•
•
•

append-only
immutable
timestamped
actor-aware
tenant-aware
device-aware
correlation-aware
exportable
searchable
retention-protected

Mandatory Audit Fields

106.
107.
108.
109.
110.
111. entity
112.
113.
114.
115.
116.
117.
118.

correlation_id
tenant_id
branch_id
actor_id
device_id

entity_id
action
before_state
after_state
ip_address
timestamp
risk_level

Compliance Objectives

The platform architecture should remain compatible with:

•  GDPR principles
•  SOC2 operational controls
•  PCI-aware payment isolation principles
•

local tax authority auditability requirements

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 71

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

13.9 API Security Standards

API Protection Requirements

Idempotency protection on financial endpoints

Branch context validation
Tenant isolation validation

119.  Mandatory JWT validation middleware
120.
121.
122.  Request schema validation
123.
124.  Correlation ID injection
125.
126.  Request size limits
127.  Upload MIME validation
128.

Structured error responses

Pagination enforcement on large queries

Rate Limiting Matrix

Endpoint Category

Limit

Login endpoints

OTP endpoints

Sync endpoints

Export endpoints

Reporting endpoints

Public webhooks

API Security Controls

5 requests/minute/IP

3 requests/5 minutes

60 requests/minute/device

10 requests/hour/user

30 requests/minute/user

Signature validated + throttled

129.  Helmet.js secure headers
130.  CORS whitelist enforcement
131.  OWASP-safe validation pipeline
132.
133.
134.  CSRF mitigation where applicable
135.

File upload malware scanning

SQL injection prevention via ORM parameterization
XSS sanitization for user-generated content

13.10 Infrastructure & Network Security

Infrastructure Requirements

Internal-only database exposure
Firewall-restricted production ports

136.  Docker container isolation
137.
138.
139.  Nginx reverse proxy hardening
140.
141.

Fail2Ban for brute-force protection
Automatic security patching schedule

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 72

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

142.  Read-only production filesystem where possible
143.  Non-root containers
144.
Infrastructure health monitoring
145.  DDoS-aware reverse proxy configuration

Production Network Rules

Service

PostgreSQL

Redis

BullMQ dashboard

Grafana

Sentry

NestJS API

Exposure

Internal only

Internal only

VPN/admin-only

MFA-protected

Restricted admin access

Public HTTPS only

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 73

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

13.11 Backup, Recovery & Disaster Resilience

Backup Strategy

146.  Nightly PostgreSQL full backup
147.  WAL archiving enabled
148.  Redis persistence snapshots
149.
150.
151.
152.  Monthly cold storage archive

Encrypted offsite backup replication
Backup integrity verification jobs
Point-in-time recovery support

Recovery Objectives

Objective

Target

RPO (Recovery Point Objective)

<15 minutes

RTO (Recovery Time Objective)

<2 hours

Critical financial data loss

Zero tolerated

Backup Verification Requirements

153.  Weekly restore test in staging
154.  Monthly disaster recovery simulation
155.
Backup checksum validation
156.  Recovery procedure documentation
157.

Audit logging for all restore operations

13.12 Incident Response & Security Operations

Incident Severity Levels

Severity

Description

P1

P2

P3

P4

Active breach or financial compromise

Critical production vulnerability

Suspicious activity requiring investigation

Minor operational security issue

Incident Response Workflow

Verification

158.  Detection
159.
160.  Containment
161.  Root cause analysis
162.  Mitigation

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 74

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

163.  Recovery
164.
165.

Postmortem documentation
Permanent remediation

Mandatory Security Responses

Event

Multiple failed logins

Stolen device report

Automatic Response

Temporary account lock

Session revocation + device blacklist

Token replay detected

Force re-authentication

Privilege escalation anomaly

Admin alert + audit escalation

Suspicious sync payload

Reject sync + quarantine device

Security Monitoring Stack

Sentry

Prometheus
Loki

166.
167.  Grafana
168.
169.
170.  OpenTelemetry
171.  Uptime Robot
172.  OWASP ZAP
173.  Dependency vulnerability scanners

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 75

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

13.13 Security Testing Strategy

Mandatory Security Testing

Tenant isolation verification
Sync replay attack testing

174.  OWASP Top 10 validation
175.  RBAC penetration testing
176.
177.
178.  Offline tampering simulation
179.
180.
181.
182.  Dependency vulnerability scanning
Backup restoration testing
183.

Load testing under hostile conditions
SQL injection testing
XSS validation testing

Security CI/CD Gates

Pipeline Stage

Pull Request

Staging Deploy

Security Validation

ESLint security rules + dependency scan

OWASP ZAP baseline scan

Production Release

Manual approval + smoke security verification

Penetration Testing Schedule

Internal penetration testing before launch

184.
185.  Quarterly vulnerability review
186.
187.

Annual external penetration assessment
Immediate re-testing after critical auth changes

13.14 Final Security Decision Record

This security architecture is designed to ensure that LUMINA POS remains:

financially trustworthy
operationally resilient
audit-safe
offline-secure

•
•
•
•
•  multi-tenant isolated
•

enterprise-deployable

Security-sensitive domains including:

authentication
financial posting
synchronization

•
•
•
•  RBAC
•

tenant isolation

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 76

LUMINA POS — MASTER DEVELOPMENT PIPELINE CONFIDENTIAL

•

auditability

must never rely solely on AI-generated implementations without:

188.  manual engineering review
integration testing
189.
adversarial testing
190.
production validation
191.
rollback verification
192.

The security posture prioritizes:

193.
194.
195.
196.

correctness over speed
traceability over convenience
isolation over implicit trust
resilience over optimistic assumptions

— END OF ENTERPRISE SECURITY ARCHITECTURE ADDENDUM —

Stock Bridge ERP / LUMINA POS  ·  Internal Engineering DocumentPage 77

