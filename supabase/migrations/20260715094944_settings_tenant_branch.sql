-- tenants.settings_json (jsonb, exists, EMPTY) is the tenant config registry. branches already carry
-- currency/timezone/country/city — do NOT duplicate them on tenants.
create or replace function public.update_tenant_settings(p_patch jsonb)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid := public.auth_tenant_id(); v_new jsonb;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('settings','update') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  update tenants set settings_json = coalesce(settings_json,'{}'::jsonb) || coalesce(p_patch,'{}'::jsonb)
    where id=v_t returning settings_json into v_new;                 -- shallow merge: patch, don't replace
  return v_new;
end; $function$;

create or replace function public.update_branch_settings(
  p_branch_id uuid, p_name varchar, p_city varchar, p_country varchar, p_currency varchar, p_timezone varchar, p_is_active boolean
) returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid := public.auth_tenant_id();
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('settings','update') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  update branches set name=coalesce(p_name,name), city=coalesce(p_city,city), country=coalesce(p_country,country),
    currency=coalesce(p_currency,currency), timezone=coalesce(p_timezone,timezone), is_active=coalesce(p_is_active,is_active)
    where id=p_branch_id and tenant_id=v_t;
  if not found then raise exception 'ERR_BRANCH_NOT_FOUND'; end if;
  return jsonb_build_object('branch_id', p_branch_id);
end; $function$;