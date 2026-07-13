-- C6 — WARRANTY_CLAIM re-repair workflow + accounting.
-- A warranty re-repair consumes REAL parts (stock deducts via REPAIR_USE) but
-- charges the customer NOTHING. So the captured part cost lands as a WARRANTY
-- EXPENSE against inventory — balanced, revenue-free. Sign-offs this phase:
--   linkage      = new original_repair_id column (explicit parent link).
--   expense acct = new 5200 'Warranty Cost' (dedicated EXPENSE, separately reportable).
-- NOTE: post_journal lines use account_code (string) — the live contract; account_id
-- fails (ERR_ACCOUNT_NOT_FOUND). reference_type is free varchar → 'REPAIR_WARRANTY' ok.

-- ---- linkage: additive self-FK ----
alter table public.repair_jobs
  add column if not exists original_repair_id uuid references public.repair_jobs(id);
create index if not exists idx_repair_jobs_original
  on public.repair_jobs(original_repair_id) where original_repair_id is not null;

-- ---- seed 5200 Warranty Cost for all existing tenants (idempotent, is_system) ----
-- Mirrors the accounting_foundation_coa seed pattern. (New-tenant COA seeding is a
-- pre-existing gap — handle_new_user seeds no accounts at all — not introduced here.)
insert into public.accounts (tenant_id, code, name, type, is_system)
select t.id, '5200', 'Warranty Cost', 'EXPENSE'::account_type_enum, true
from public.tenants t
where not exists (select 1 from public.accounts a where a.tenant_id=t.id and a.code='5200');

-- ---- open_warranty_claim: DELIVERED + in-warranty original → linked RECEIVED re-repair ----
create or replace function public.open_warranty_claim(p_original_repair_id uuid, p_reported_issue text)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare
  v_t uuid := public.auth_tenant_id(); v_o repair_jobs%rowtype; v_res jsonb; v_id uuid;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  -- create-permission + branch are re-checked inside create_repair_job below.
  select * into v_o from repair_jobs where id=p_original_repair_id and tenant_id=v_t and deleted_at is null;
  if not found then raise exception 'ERR_JOB_NOT_FOUND'; end if;
  if v_o.status <> 'DELIVERED' then raise exception 'ERR_NOT_DELIVERED'; end if;
  if v_o.warranty_expires_at is null or v_o.warranty_expires_at < current_date then
    raise exception 'ERR_WARRANTY_EXPIRED'; end if;

  -- reuse the SOLE creator (numbering + validation + RECEIVED + history)
  v_res := public.create_repair_job(v_o.branch_id, v_o.customer_id, v_o.device_type, v_o.device_brand,
    v_o.device_model, v_o.serial_no, v_o.imei, p_reported_issue, v_o.priority, null, null,
    'Warranty claim of '||v_o.job_number);
  v_id := (v_res->>'repair_id')::uuid;

  -- link to the original + share its correlation group
  update repair_jobs set original_repair_id = p_original_repair_id,
    correlation_id = coalesce(v_o.correlation_id, correlation_id)
    where id = v_id;

  -- flip the original to WARRANTY_CLAIM (sole status writer; DELIVERED→WARRANTY_CLAIM is legal)
  perform public.change_repair_status(p_original_repair_id, 'WARRANTY_CLAIM',
    'Claim opened: '||(v_res->>'job_number'));

  return jsonb_build_object('claim_repair_id', v_id, 'job_number', v_res->>'job_number',
    'original', p_original_repair_id);
end; $function$;

-- ---- close_warranty_claim: zero customer charge, cost-only balanced post ----
create or replace function public.close_warranty_claim(p_repair_id uuid, p_warranty_days int, p_signature_url varchar)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare
  v_t uuid := public.auth_tenant_id(); v_uid uuid := auth.uid(); v_job repair_jobs%rowtype;
  v_cost numeric; v_lines jsonb := '[]'::jsonb;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('repair','update') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  select * into v_job from repair_jobs where id=p_repair_id and tenant_id=v_t and deleted_at is null;
  if not found then raise exception 'ERR_JOB_NOT_FOUND'; end if;
  if v_job.status <> 'READY' then raise exception 'ERR_JOB_NOT_READY'; end if;

  -- NO invoice, NO revenue. Parts already consumed (REPAIR_USE). Recognize their
  -- captured cost as warranty expense: Dr 5200 Warranty Cost / Cr 1200 Inventory.
  select coalesce(sum(total_cost),0) into v_cost from repair_parts where repair_id=p_repair_id;
  if v_cost > 0 then
    v_lines := jsonb_build_array(
      jsonb_build_object('account_code','5200','debit',v_cost,'credit',0),
      jsonb_build_object('account_code','1200','debit',0,'credit',v_cost));
    perform public.post_journal(v_job.branch_id, 'REPAIR_WARRANTY', p_repair_id,
      'Warranty '||v_job.job_number, v_lines, current_date, null, false);
  end if;

  -- READY→DELIVERED directly (change_repair_status forbids DELIVERED); final_cost=0 (no charge)
  update repair_jobs set status='DELIVERED', final_cost=0, delivered_at=now(),
    customer_signature_url=coalesce(p_signature_url, customer_signature_url),
    warranty_expires_at=case when p_warranty_days is not null then current_date + p_warranty_days else warranty_expires_at end,
    updated_by=v_uid, updated_at=now(), version=version+1
    where id=p_repair_id;
  insert into repair_status_history (repair_id, old_status, new_status, changed_by, notes)
  values (p_repair_id, 'READY', 'DELIVERED', v_uid, 'Warranty repair delivered (no charge)');

  return jsonb_build_object('repair_id', p_repair_id, 'charged', 0, 'warranty_cost', v_cost,
    'status', 'DELIVERED');
end; $function$;
