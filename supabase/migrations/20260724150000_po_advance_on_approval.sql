-- Bridge: when a PURCHASE_ORDER approval request completes, advance the PO itself.
-- Bug: act_on_approval only marks approval_requests.status=APPROVED; nothing moved the
-- purchase_order, so a fully-approved PO stayed stuck at SUBMITTED. The PO's manual
-- Approve button (approve_purchase_order) was the only path, making the approvals-tab
-- decision a dead end once a workflow existed.
--
-- Fix: a trigger on approval_requests advances the PO when its request reaches a terminal
-- state. Mirrors the same 4-column update approve_purchase_order does (status + approved_by
-- + approved_at + version) — no GL/stock side effects there, so no shared logic to factor.
-- The approval chain IS the authorization, so this bypasses the manual purchase:approve gate.
-- Idempotent + SECURITY DEFINER (fires inside act_on_approval's tx; bypasses PO RLS).

create or replace function public.advance_po_on_approval()
returns trigger language plpgsql security definer set search_path to 'public' as $function$
begin
  if NEW.entity_type = 'purchase_orders'
     and NEW.status = 'APPROVED'
     and OLD.status is distinct from 'APPROVED' then
    update public.purchase_orders
       set status      = 'APPROVED',
           approved_by  = (select actor_id from public.approval_actions
                            where request_id = NEW.id and action = 'APPROVED'
                            order by acted_at desc limit 1),   -- final approver
           approved_at  = now(),
           updated_at   = now(),
           version      = version + 1
     where id = NEW.entity_id and tenant_id = NEW.tenant_id and status = 'SUBMITTED';
  end if;
  return NEW;
end; $function$;

drop trigger if exists trg_advance_po_on_approval on public.approval_requests;
create trigger trg_advance_po_on_approval
  after update of status on public.approval_requests
  for each row execute function public.advance_po_on_approval();
