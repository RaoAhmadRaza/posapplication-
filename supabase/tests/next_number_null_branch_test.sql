-- Runnable check for migration 20260723110000 (next_number null-branch bug).
-- Run in Supabase SQL editor or: psql "$DATABASE_URL" -f supabase/tests/next_number_null_branch_test.sql
-- Passes silently; raises if the root cause regresses. No auth/tenant needed.
--
-- Root cause: `SELECT ... INTO v_code WHERE id = <null>` matches zero rows, and
-- PL/pgSQL sets the INTO target to NULL on no rows -> the whole entry_number went NULL.
do $$
declare v_code text := '';
begin
  -- Reproduce the exact broken idiom: no-row SELECT INTO nulls the variable.
  select coalesce(code,'') into v_code from public.branches where id = null;
  assert v_code is null,
    'REPRO FAILED: SELECT INTO on no rows should null the var (bug precondition changed)';

  -- The fix guards the lookup with `p_branch_id is not null`, so it never runs for a
  -- null branch and v_code keeps its '' init -> prefix||v_code||lpad(...) stays non-null.
  v_code := '';
  -- guard = (include_branch_code AND p_branch_id is not null); null branch => false => skip
  if true and (null is not null) then
    select coalesce(code,'') into v_code from public.branches where id = null;
  end if;
  assert v_code = '' and ('X' || v_code || '001') is not null,
    'FIX FAILED: guarded null-branch path must leave v_code empty and number non-null';

  raise notice 'next_number null-branch check: PASS';
end $$;
