-- Bulk status change: loops the SOLE writer (change_repair_status) so every job
-- gets full validation + history + notify. Each job is independent — a failure
-- (illegal transition, not found, permission) is collected, never aborts the batch.
create or replace function public.bulk_change_repair_status(
  p_repair_ids uuid[], p_new_status repair_status_enum, p_notes text)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare
  v_id uuid; v_ok int := 0; v_fail jsonb := '[]'::jsonb;
begin
  foreach v_id in array p_repair_ids loop
    begin
      perform public.change_repair_status(v_id, p_new_status, p_notes);
      v_ok := v_ok + 1;
    exception when others then
      v_fail := v_fail || jsonb_build_array(
        jsonb_build_object('repair_id', v_id, 'error', SQLERRM));
    end;
  end loop;
  return jsonb_build_object('succeeded', v_ok, 'failed', v_fail);
end; $function$;
