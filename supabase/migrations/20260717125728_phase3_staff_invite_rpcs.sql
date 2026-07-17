-- Phase 3 — Staff-invite RPCs. Basis: RUNBOOK v3 §3.
-- Tokens: gen_random_uuid() x2 (~244 bits) + core sha256() (no pgcrypto; verified P1).
-- consume_staff_invite is trigger-only (wired into handle_new_user in Phase 4).

-- ===== 3.1  create_staff_invite (four-guard set) =====
create or replace function public.create_staff_invite(
  p_role_id uuid, p_branch_ids uuid[],
  p_full_name text default null, p_email text default null,
  p_employee_id uuid default null, p_expires_in_hours integer default 72
) returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_tenant_id uuid := public.auth_tenant_id();
  v_token text; v_hash text; v_invite_id uuid; v_branch_id uuid;
  v_my_level integer; v_tgt_level integer; v_tgt_name text;
  v_i_am_admin boolean := public.is_admin_role_name(public.auth_role_name());
begin
  if v_tenant_id is null then raise exception 'ERR_NO_TENANT'; end if;
  if not public.auth_has_permission('users','create') then raise exception 'ERR_FORBIDDEN'; end if;
  if p_expires_in_hours is null or p_expires_in_hours < 1 or p_expires_in_hours > 720 then
    raise exception 'ERR_INVALID_EXPIRY';
  end if;

  select r.hierarchy_level, r.name into v_tgt_level, v_tgt_name
  from public.roles r where r.id = p_role_id and r.tenant_id = v_tenant_id;
  if not found then raise exception 'ERR_ROLE_NOT_IN_TENANT'; end if;

  -- GUARD 1 (name, drift-proof): only ADMIN may mint ADMIN.
  if public.is_admin_role_name(v_tgt_name) and not v_i_am_admin then
    raise exception 'ERR_ONLY_ADMIN_CAN_CREATE_ADMIN';
  end if;

  -- GUARD 2 (subset, drift-proof): cannot assign a role holding any permission you don't hold.
  if not v_i_am_admin and not public.auth_can_grant_role(p_role_id) then
    raise exception 'ERR_CANNOT_GRANT_UNHELD_PERMISSION';
  end if;

  -- GUARD 3 (level, needs 1.9): blocks peer-or-higher. Guards 1-2 are backstops.
  select r.hierarchy_level into v_my_level from public.roles r where r.id = public.auth_role_id();
  if not v_i_am_admin and coalesce(v_tgt_level, 99) <= coalesce(v_my_level, 99) then
    raise exception 'ERR_HIERARCHY_VIOLATION';
  end if;

  -- GUARD 4: tenant + branch scoping
  if p_branch_ids is null or array_length(p_branch_ids, 1) is null then
    raise exception 'ERR_NO_BRANCH';
  end if;
  foreach v_branch_id in array p_branch_ids loop
    if not exists (select 1 from public.branches b where b.id = v_branch_id and b.tenant_id = v_tenant_id) then
      raise exception 'ERR_BRANCH_NOT_IN_TENANT';
    end if;
    if not public.auth_has_branch(v_branch_id) then
      raise exception 'ERR_BRANCH_NOT_ASSIGNED';
    end if;
  end loop;

  if p_employee_id is not null and not exists (
       select 1 from public.employees e where e.id = p_employee_id and e.tenant_id = v_tenant_id) then
    raise exception 'ERR_EMPLOYEE_NOT_IN_TENANT';
  end if;

  v_token := 'lum_' || replace(gen_random_uuid()::text,'-','') || replace(gen_random_uuid()::text,'-','');
  v_hash  := encode(sha256(v_token::bytea), 'hex');

  insert into public.staff_invites
    (tenant_id, role_id, employee_id, token_hash, full_name, email, expires_at, created_by)
  values (v_tenant_id, p_role_id, p_employee_id, v_hash,
          nullif(trim(p_full_name),''), lower(nullif(trim(p_email),'')),
          now() + make_interval(hours => p_expires_in_hours), auth.uid())
  returning id into v_invite_id;

  foreach v_branch_id in array p_branch_ids loop
    insert into public.staff_invite_branches (invite_id, branch_id, is_default)
    values (v_invite_id, v_branch_id, v_branch_id = p_branch_ids[1])
    on conflict do nothing;
  end loop;

  return jsonb_build_object('invite_id', v_invite_id, 'token', v_token,
    'qr_payload', 'lumina://join?t=' || v_token,
    'expires_at', now() + make_interval(hours => p_expires_in_hours));
end $$;

revoke all on function public.create_staff_invite(uuid, uuid[], text, text, uuid, integer) from public, anon;
grant execute on function public.create_staff_invite(uuid, uuid[], text, text, uuid, integer) to authenticated;

-- ===== 3.2  validate_staff_invite (anon, pre-auth) =====
create or replace function public.validate_staff_invite(p_token text)
returns jsonb language plpgsql security definer stable set search_path = public
as $$
declare v_hash text; v_rec record;
begin
  if p_token is null or length(p_token) < 32 then
    return jsonb_build_object('valid', false, 'reason', 'INVALID');
  end if;
  v_hash := encode(sha256(p_token::bytea), 'hex');

  select si.status, si.expires_at, si.used_count, si.max_uses, si.full_name, si.email,
         t.name as business_name, r.name as role_name
    into v_rec
  from public.staff_invites si
  join public.tenants t on t.id = si.tenant_id
  join public.roles   r on r.id = si.role_id
  where si.token_hash = v_hash;

  if not found then return jsonb_build_object('valid', false, 'reason', 'INVALID'); end if;
  if v_rec.status = 'REVOKED' then return jsonb_build_object('valid', false, 'reason', 'REVOKED'); end if;
  if v_rec.status = 'REDEEMED' or v_rec.used_count >= v_rec.max_uses then
    return jsonb_build_object('valid', false, 'reason', 'ALREADY_USED'); end if;
  if v_rec.expires_at <= now() then
    return jsonb_build_object('valid', false, 'reason', 'EXPIRED'); end if;

  return jsonb_build_object('valid', true, 'business_name', v_rec.business_name,
    'role_name', v_rec.role_name, 'full_name', v_rec.full_name, 'email', v_rec.email,
    'email_locked', v_rec.email is not null, 'expires_at', v_rec.expires_at);
end $$;

revoke all on function public.validate_staff_invite(text) from public;
grant execute on function public.validate_staff_invite(text) to anon, authenticated;

-- ===== 3.3  consume_staff_invite (trigger-only; single atomic UPDATE, race-safe) =====
create or replace function public.consume_staff_invite(p_token text, p_user_id uuid, p_email text)
returns table (tenant_id uuid, role_id uuid, default_branch_id uuid, full_name text)
language plpgsql security definer set search_path = public
as $$
declare v_hash text; v_invite public.staff_invites%rowtype; v_branch uuid;
begin
  v_hash := encode(sha256(p_token::bytea), 'hex');

  update public.staff_invites si
     set used_count  = si.used_count + 1,
         status      = case when si.used_count + 1 >= si.max_uses
                            then 'REDEEMED'::public.invite_status_enum else si.status end,
         redeemed_by = coalesce(si.redeemed_by, p_user_id),
         redeemed_at = coalesce(si.redeemed_at, now())
   where si.token_hash = v_hash
     and si.status     = 'PENDING'
     and si.expires_at > now()
     and si.used_count < si.max_uses
     and (si.email is null or si.email = lower(p_email))
  returning si.* into v_invite;

  if not found then
    raise exception 'ERR_INVITE_INVALID'
      using hint = 'Invalid, expired, revoked, already used, or email mismatch';
  end if;

  insert into public.user_branch_assignments (user_id, branch_id, is_default)
  select p_user_id, sib.branch_id, sib.is_default
  from public.staff_invite_branches sib where sib.invite_id = v_invite.id
  on conflict (user_id, branch_id) do nothing;

  if v_invite.employee_id is not null then
    update public.employees e set user_id = p_user_id
    where e.id = v_invite.employee_id and e.tenant_id = v_invite.tenant_id and e.user_id is null;
  end if;

  select sib.branch_id into v_branch from public.staff_invite_branches sib
  where sib.invite_id = v_invite.id order by sib.is_default desc limit 1;

  return query select v_invite.tenant_id, v_invite.role_id, v_branch, v_invite.full_name;
end $$;

revoke all on function public.consume_staff_invite(text, uuid, text) from public, anon, authenticated;

-- ===== 3.4  revoke_staff_invite =====
create or replace function public.revoke_staff_invite(p_invite_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.auth_has_permission('users','update') then raise exception 'ERR_FORBIDDEN'; end if;
  update public.staff_invites set status='REVOKED', revoked_at=now(), revoked_by=auth.uid()
  where id = p_invite_id and tenant_id = public.auth_tenant_id() and status = 'PENDING';
  if not found then raise exception 'ERR_INVITE_NOT_FOUND_OR_NOT_PENDING'; end if;
end $$;
revoke all on function public.revoke_staff_invite(uuid) from public, anon;
grant execute on function public.revoke_staff_invite(uuid) to authenticated;

-- ===== 3.5  list_staff_invites (surfaces abandonment via AWAITING_CONFIRMATION) =====
create or replace function public.list_staff_invites()
returns table (id uuid, full_name text, email text, role_name text,
               branch_names text[], effective_status text,
               expires_at timestamptz, created_at timestamptz, redeemed_at timestamptz)
language sql security definer stable set search_path = public
as $$
  select si.id, si.full_name, si.email, r.name,
         array(select b.name from public.staff_invite_branches sib
               join public.branches b on b.id = sib.branch_id where sib.invite_id = si.id),
         case
           when si.status = 'REVOKED'  then 'REVOKED'
           when si.status = 'REDEEMED' and au.email_confirmed_at is null
                then 'AWAITING_CONFIRMATION'
           when si.status = 'REDEEMED' then 'REDEEMED'
           when si.expires_at <= now() then 'EXPIRED'
           else 'PENDING'
         end,
         si.expires_at, si.created_at, si.redeemed_at
  from public.staff_invites si
  join public.roles r on r.id = si.role_id
  left join auth.users au on au.id = si.redeemed_by
  where si.tenant_id = public.auth_tenant_id()
    and public.auth_has_permission('users','read')
  order by si.created_at desc;
$$;
revoke all on function public.list_staff_invites() from public, anon;
grant execute on function public.list_staff_invites() to authenticated;

-- ===== 3.6  regenerate_staff_invite (revoke old + re-enter create -> all four guards re-apply) =====
create or replace function public.regenerate_staff_invite(p_invite_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_old public.staff_invites%rowtype; v_branches uuid[];
begin
  if not public.auth_has_permission('users','create') then raise exception 'ERR_FORBIDDEN'; end if;
  select * into v_old from public.staff_invites
  where id = p_invite_id and tenant_id = public.auth_tenant_id() and status = 'PENDING';
  if not found then raise exception 'ERR_INVITE_NOT_FOUND_OR_NOT_PENDING'; end if;

  select array_agg(branch_id order by is_default desc) into v_branches
  from public.staff_invite_branches where invite_id = p_invite_id;

  update public.staff_invites set status='REVOKED', revoked_at=now(), revoked_by=auth.uid()
  where id = p_invite_id;

  return public.create_staff_invite(v_old.role_id, v_branches, v_old.full_name, v_old.email,
    v_old.employee_id, greatest(1, ceil(extract(epoch from (v_old.expires_at - now()))/3600)::int));
end $$;
revoke all on function public.regenerate_staff_invite(uuid) from public, anon;
grant execute on function public.regenerate_staff_invite(uuid) to authenticated;

-- ===== 3.7  release_abandoned_invite (Confirm-email ON; deletes an unconfirmed/never-signed-in
-- auth.users row -> cascades to public.users via 0.7 ON DELETE CASCADE) =====
create or replace function public.release_abandoned_invite(p_invite_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_inv public.staff_invites%rowtype; v_uid uuid;
begin
  if not public.auth_has_permission('users','delete') then raise exception 'ERR_FORBIDDEN'; end if;
  select * into v_inv from public.staff_invites
  where id = p_invite_id and tenant_id = public.auth_tenant_id() and status = 'REDEEMED';
  if not found then raise exception 'ERR_INVITE_NOT_REDEEMED'; end if;
  if v_inv.redeemed_by is null then raise exception 'ERR_NO_REDEEMER'; end if;

  select au.id into v_uid from auth.users au
  where au.id = v_inv.redeemed_by
    and au.email_confirmed_at is null
    and au.last_sign_in_at   is null;
  if not found then raise exception 'ERR_USER_ACTIVE_CANNOT_RELEASE'; end if;

  delete from auth.users where id = v_uid;              -- cascades (0.7)
  update public.employees set user_id = null where user_id = v_uid;
  update public.staff_invites set status='REVOKED', revoked_at=now(), revoked_by=auth.uid()
  where id = p_invite_id;
end $$;
revoke all on function public.release_abandoned_invite(uuid) from public, anon;
grant execute on function public.release_abandoned_invite(uuid) to authenticated;
