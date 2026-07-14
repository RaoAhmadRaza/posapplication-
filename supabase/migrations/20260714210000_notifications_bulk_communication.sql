-- Bulk customer communication: enqueue one PENDING communication_logs row per customer in
-- a segment, rendering the chosen template per recipient. communication_logs has no INSERT
-- policy (definer/service_role only), so this set-based write must be a SECURITY DEFINER RPC.
-- p_dry_run=true counts recipients without inserting (for the confirm dialog).
create or replace function public.enqueue_bulk_communication(
  p_segment text,
  p_tag text,
  p_template_code text,
  p_channel text,
  p_dry_run boolean default false
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_t uuid := public.auth_tenant_id();
  v_body text;
  v_subject text;
  v_to text;
  v_n int := 0;
  r record;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('notifications', 'create') then
    raise exception 'ERR_FORBIDDEN' using errcode='42501';
  end if;

  -- resolve the channel-appropriate active template (skip for a dry run)
  if not p_dry_run then
    if p_channel = 'EMAIL' then
      select coalesce(body_html, body_text), subject into v_body, v_subject
        from email_templates
        where tenant_id = v_t and template_code = p_template_code and is_active;
    else
      select body, name into v_body, v_subject from sms_templates
        where tenant_id = v_t and template_code = p_template_code and is_active;
    end if;
    if v_body is null then
      raise exception 'ERR_TEMPLATE_NOT_FOUND' using errcode='P0002';
    end if;
  end if;

  for r in
    select c.id, c.name, c.phone, c.email
    from customers c
    where c.tenant_id = v_t
      and (
        p_segment = 'all'
        or (p_segment = 'with_balance' and exists (
              select 1 from invoices i
              where i.customer_id = c.id and i.balance > 0
                and i.status not in ('DRAFT', 'VOID') and i.deleted_at is null))
        or (p_segment = 'by_tag' and p_tag = any(c.tags))
      )
  loop
    v_to := case when p_channel = 'EMAIL' then r.email else r.phone end;
    if v_to is null or v_to = '' then continue; end if;
    if not p_dry_run then
      insert into communication_logs
        (tenant_id, customer_id, channel, template_code, status, recipient, payload)
      values (v_t, r.id, p_channel, p_template_code, 'PENDING', v_to,
        jsonb_build_object(
          'subject', v_subject,
          'body', public.render_template(v_body, jsonb_build_object('name', coalesce(r.name, '')))
        ));
    end if;
    v_n := v_n + 1;
  end loop;

  return jsonb_build_object('enqueued', v_n, 'dry_run', p_dry_run);
end; $$;
