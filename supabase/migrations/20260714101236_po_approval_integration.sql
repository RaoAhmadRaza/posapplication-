-- Reference integration: wire PURCHASE_ORDER approval into the PO lifecycle.
-- Both bodies are the LIVE A0.5 dumps, verbatim, with ONLY the approval calls
-- added (submit: fetch grand_total + request_approval after SUBMITTED update;
-- approve: approval_status guard before APPROVED update). Nothing else changed.
-- Inert when no PURCHASE_ORDER workflow is configured (request_approval →
-- required:false, approval_status → NONE): PO submit/approve behave as today.

CREATE OR REPLACE FUNCTION public.submit_purchase_order(p_po_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_t uuid := public.auth_tenant_id(); v_status purchase_order_status_enum; v_total numeric;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('purchase','create') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  select status, grand_total into v_status, v_total from purchase_orders where id=p_po_id and tenant_id=v_t and deleted_at is null;
  if not found then raise exception 'ERR_PO_NOT_FOUND'; end if;
  if v_status <> 'DRAFT' then raise exception 'ERR_BAD_TRANSITION'; end if;
  update purchase_orders set status='SUBMITTED', updated_at=now(), version=version+1 where id=p_po_id;
  perform public.request_approval('PURCHASE_ORDER', 'purchase_orders', p_po_id, v_total, 'PO submitted', null);
  return jsonb_build_object('po_id',p_po_id,'status','SUBMITTED');
end; $function$;

CREATE OR REPLACE FUNCTION public.approve_purchase_order(p_po_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_t uuid := public.auth_tenant_id(); v_uid uuid := auth.uid(); v_status purchase_order_status_enum;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('purchase','approve') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  select status into v_status from purchase_orders where id=p_po_id and tenant_id=v_t and deleted_at is null;
  if not found then raise exception 'ERR_PO_NOT_FOUND'; end if;
  if v_status <> 'SUBMITTED' then raise exception 'ERR_BAD_TRANSITION'; end if;
  if (public.approval_status('purchase_orders', p_po_id)->>'status') in ('PENDING','ESCALATED','REJECTED') then
    raise exception 'ERR_APPROVAL_REQUIRED' using errcode='42501';   -- must clear the approval chain first
  end if;
  update purchase_orders set status='APPROVED', approved_by=v_uid, approved_at=now(), updated_at=now(), version=version+1 where id=p_po_id;
  return jsonb_build_object('po_id',p_po_id,'status','APPROVED');
end; $function$;
