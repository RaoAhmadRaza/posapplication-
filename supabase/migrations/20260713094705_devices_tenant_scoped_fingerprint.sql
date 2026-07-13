-- device fingerprint uniqueness is PER-TENANT, not global. A physical device may register a
-- distinct row per tenant (matches the tenant-isolated RLS model). Fixes a cross-tenant upsert
-- collision where a device seeded under one tenant blocked registration under another.
-- Pre-checked: no duplicate (tenant_id, fingerprint_hash) pairs.
drop index if exists public.uq_devices_fingerprint;
create unique index if not exists uq_devices_tenant_fingerprint
  on public.devices (tenant_id, fingerprint_hash);
