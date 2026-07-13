-- REPAIR_USE stock movement type. A prior migration (094744) recorded this ADD VALUE but the value
-- never landed on prod (add-then-use / transaction-batch foot-gun). Re-add idempotently in its own
-- push so it commits before any RPC uses 'REPAIR_USE'::stock_movement_type_enum (R3 File 1/File 2).
alter type public.stock_movement_type_enum add value if not exists 'REPAIR_USE';
