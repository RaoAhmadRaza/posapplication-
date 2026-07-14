-- immutable, partitioned by event_date (§3.12 + §7). Parent partitioned table + a default + a helper to add months.
create table if not exists public.analytics_events (
  id uuid not null default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  event_type varchar(100) not null,
  dimensions_json jsonb not null,
  metrics_json jsonb not null,
  event_date date not null,
  created_at timestamptz not null default now(),
  primary key (id, event_date)
) partition by range (event_date);
create table if not exists public.analytics_events_default partition of public.analytics_events default;
create index if not exists idx_analytics_events_type on public.analytics_events(event_type, event_date);
create index if not exists idx_analytics_events_tenant on public.analytics_events(tenant_id, event_date);
create index if not exists idx_analytics_events_dimensions on public.analytics_events using gin (dimensions_json jsonb_path_ops);

alter table public.analytics_events enable row level security;
drop policy if exists "ae read" on public.analytics_events;
create policy "ae read" on public.analytics_events for select to authenticated using (tenant_id=public.auth_tenant_id());
revoke insert,update,delete on public.analytics_events from authenticated;   -- immutable; written by definer capture only

-- capture helper (definer) + a REFERENCE hook for sales. Broad capture across modules = Phase 2 (deferred).
create or replace function public.capture_analytics_event(p_type varchar, p_dims jsonb, p_metrics jsonb, p_date date)
returns void language sql security definer set search_path to 'public' as $$
  insert into public.analytics_events (tenant_id, event_type, dimensions_json, metrics_json, event_date)
  values (public.auth_tenant_id(), p_type, coalesce(p_dims,'{}'), coalesce(p_metrics,'{}'), coalesce(p_date, current_date));
$$;
-- Reference: emit a 'sale' event from create_sale (add ONE line to the dumped create_sale, or a lightweight
-- AFTER trigger on invoices). Documented pattern; other event types (page_view/search) follow. Deferred here.