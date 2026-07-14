-- ========== ai_recommendations — verbatim §3.12 ==========
create table if not exists public.ai_recommendations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  recommendation_type varchar(100) not null,
  entity_type varchar(50) not null,
  entity_id uuid not null,
  recommendation_json jsonb not null,
  confidence_score decimal(3,2) not null,
  reasoning text,
  status varchar(20) not null default 'PENDING',
  accepted_by uuid references public.users(id),
  accepted_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_ai_recommendations_tenant on public.ai_recommendations(tenant_id, status);
create index if not exists idx_ai_recommendations_entity on public.ai_recommendations(entity_type, entity_id);
create index if not exists idx_ai_recommendations_type on public.ai_recommendations(recommendation_type, status);
create index if not exists idx_ai_recommendations_expires on public.ai_recommendations(expires_at) where status='PENDING';

alter table public.ai_recommendations enable row level security;
drop policy if exists "air read" on public.ai_recommendations;
create policy "air read" on public.ai_recommendations for select to authenticated using (tenant_id=public.auth_tenant_id());
revoke insert,update,delete on public.ai_recommendations from authenticated;

-- rules-based REORDER generator (ML deferred): products at/below reorder_point → a REORDER recommendation.
create or replace function public.generate_reorder_recommendations()
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_n int:=0; v_row record;
begin
  for v_row in
    select tenant_id, product_id, product_name, sku, qty_on_hand, reorder_point
    from mv_inventory_valuation where below_reorder
  loop
    -- one open recommendation per product
    if not exists (select 1 from ai_recommendations where tenant_id=v_row.tenant_id and recommendation_type='REORDER'
                     and entity_id=v_row.product_id and status='PENDING') then
      insert into ai_recommendations (tenant_id, recommendation_type, entity_type, entity_id, recommendation_json,
        confidence_score, reasoning, status, expires_at)
      values (v_row.tenant_id, 'REORDER', 'product', v_row.product_id,
        jsonb_build_object('product', v_row.product_name, 'sku', v_row.sku, 'qty_on_hand', v_row.qty_on_hand, 'reorder_point', v_row.reorder_point),
        0.90, 'On-hand '||v_row.qty_on_hand||' at/below reorder point '||v_row.reorder_point, 'PENDING', now()+interval '7 days');
      v_n := v_n + 1;
    end if;
  end loop;
  return jsonb_build_object('created', v_n);
end; $function$;

create or replace function public.act_on_recommendation(p_id uuid, p_accept boolean)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid:=public.auth_tenant_id(); v_uid uuid:=auth.uid();
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('reports','read') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  update ai_recommendations set status=case when p_accept then 'ACCEPTED' else 'DISMISSED' end,
    accepted_by=case when p_accept then v_uid else accepted_by end,
    accepted_at=case when p_accept then now() else accepted_at end, updated_at=now()
    where id=p_id and tenant_id=v_t and status='PENDING';
  if not found then raise exception 'ERR_REC_NOT_FOUND_OR_CLOSED'; end if;
  return jsonb_build_object('recommendation_id', p_id, 'status', case when p_accept then 'ACCEPTED' else 'DISMISSED' end);
end; $function$;