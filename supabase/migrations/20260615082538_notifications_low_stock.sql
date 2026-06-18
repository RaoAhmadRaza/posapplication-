-- <timestamp>_notifications_low_stock.sql
do $$ begin create type notification_channel_enum  as enum ('IN_APP','PUSH','SMS','EMAIL','WHATSAPP'); exception when duplicate_object then null; end $$;
do $$ begin create type notification_priority_enum as enum ('LOW','NORMAL','HIGH','URGENT'); exception when duplicate_object then null; end $$;
do $$ begin create type notification_status_enum   as enum ('PENDING','SENT','DELIVERED','READ','FAILED'); exception when duplicate_object then null; end $$;

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  user_id uuid not null references public.users(id),
  title varchar(255) not null,
  body text not null,
  channel notification_channel_enum not null default 'IN_APP',
  priority notification_priority_enum not null default 'NORMAL',
  status notification_status_enum not null default 'PENDING',
  action_url varchar(500), action_type varchar(50), action_id uuid,
  read_at timestamptz, sent_at timestamptz, delivered_at timestamptz,
  failed_reason text, metadata jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_notifications_user   on public.notifications(user_id, created_at);
create index if not exists idx_notifications_unread on public.notifications(user_id) where read_at is null;
create index if not exists idx_notifications_tenant on public.notifications(tenant_id, created_at);

create table if not exists public.notification_preferences (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id),
  event_type varchar(100) not null,
  channels jsonb not null default '["IN_APP"]'::jsonb,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists uq_notification_prefs on public.notification_preferences(user_id, event_type);

alter table public.notifications enable row level security;
drop policy if exists "notif read" on public.notifications;
create policy "notif read" on public.notifications for select to authenticated using (user_id = auth.uid());
drop policy if exists "notif update own" on public.notifications;   -- mark-as-read
create policy "notif update own" on public.notifications for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
revoke insert, delete on public.notifications from anon, authenticated;  -- only the trigger/RPC inserts

alter table public.notification_preferences enable row level security;
drop policy if exists "notifpref own" on public.notification_preferences;
create policy "notifpref own" on public.notification_preferences for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- low-stock generator: after a stock_balance update, if on-hand crossed at/below the effective reorder point,
-- notify every ADMIN of the tenant (one row each), deduped to avoid spamming on repeated dips.
create or replace function public.fn_low_stock_notify()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_reorder integer; v_pname text; v_psku text; u record; v_exists boolean;
begin
  -- effective reorder point: per-branch override on stock_balance, else product.reorder_point
  v_reorder := coalesce(new.reorder_point, (select reorder_point from public.products where id = new.product_id));
  if v_reorder is null or v_reorder <= 0 then return new; end if;
  -- only fire on a downward cross to/below threshold
  if not (new.qty_on_hand <= v_reorder and (old.qty_on_hand is null or old.qty_on_hand > v_reorder)) then
    return new;
  end if;
  select name, sku into v_pname, v_psku from public.products where id = new.product_id;
  -- dedupe: skip if an unread low_stock notif for this product+branch already exists
  select exists(select 1 from public.notifications n
                where n.tenant_id=new.tenant_id and n.action_type='low_stock'
                  and n.action_id=new.product_id and n.read_at is null
                  and (n.metadata->>'branch_id')::uuid = new.branch_id) into v_exists;
  if v_exists then return new; end if;
  for u in select usr.id from public.users usr
           join public.roles r on r.id = usr.role_id
           where usr.tenant_id = new.tenant_id and r.name = 'ADMIN'
  loop
    -- respect notification_preferences (default enabled if no row)
    if not exists (select 1 from public.notification_preferences p
                   where p.user_id=u.id and p.event_type='low_stock' and p.enabled=false) then
      insert into public.notifications (tenant_id,user_id,title,body,priority,status,action_type,action_id,metadata)
      values (new.tenant_id, u.id, 'Low stock: ' || coalesce(v_pname,'product'),
              coalesce(v_pname,'A product') || ' (SKU ' || coalesce(v_psku,'-') || ') is at ' ||
              new.qty_on_hand || ', at/below reorder point ' || v_reorder || '.',
              'HIGH','SENT','low_stock',new.product_id,
              jsonb_build_object('branch_id',new.branch_id,'qty',new.qty_on_hand,'reorder_point',v_reorder));
    end if;
  end loop;
  return new;
end; $$;
drop trigger if exists trg_low_stock_notify on public.stock_balance;
create trigger trg_low_stock_notify after update of qty_on_hand on public.stock_balance
  for each row execute function public.fn_low_stock_notify();

-- mark-as-read RPC (and mark-all)
create or replace function public.mark_notification_read(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.notifications set read_at = now(), status='READ'
   where id = p_id and user_id = auth.uid();
end; $$;
revoke all on function public.mark_notification_read(uuid) from anon, public;
grant execute on function public.mark_notification_read(uuid) to authenticated;