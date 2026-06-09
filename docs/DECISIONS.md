# DECISIONS — Lumina POS

Append-only log. Oldest at top, newest at bottom.

---

2026-06-09 — Backend = Supabase (Postgres + Auth + Storage), not self-hosted Node/NestJS — solo dev, speed, Firebase background; the Pipeline's NestJS/Redis/Argon2id/BullMQ specs are superseded.

2026-06-09 — Auth = Supabase Auth owns credentials/sessions/JWT; public.users is a profile (id FK auth.users); NO password stored in public.users.

2026-06-09 — Signup provisioning via handle_new_user trigger: business_name → new tenant + ADMIN/CASHIER roles + Main branch + permission matrix + branch assignment; Demo Store (fixed UUIDs) = fallback.

2026-06-09 — Email verification via custom SMTP (Supabase gates template editing behind SMTP); OTP codes via `{{ .Token }}`; verifyOTP type signup/recovery.

2026-06-09 — go_router redirect is the SINGLE source of truth for auth navigation; never navigate manually after auth; RecoveryState forces /reset during recovery.

2026-06-09 — RLS = Supabase-style via auth_tenant_id()/auth_role_name(); NOT the schema doc's SET LOCAL app.current_tenant_id pattern.

2026-06-09 — UI = clean native iOS, light mode only, accent #007AFF; the claymorphic attempt was abandoned.

2026-06-09 — Schema version-controlled in supabase/migrations/ (0001 init, 0002 signup_provisioning) — previously lived only in the cloud.

2026-06-09 — Prefer dependency-free code for tiny visual effects (flutter_inset_box_shadow was abandoned, broke the build via removed hashValues()).

2026-06-09 — Desktop-only plugins (e.g. window_manager) MUST be platform-guarded in main() or mobile crashes at launch.

2026-06-09 — Flagged paid/server-side: SMS MFA (paid provider), remote session kill (Edge Function with service_role), suspicious-login/anomaly engine (later).
