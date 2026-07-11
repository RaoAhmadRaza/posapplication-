-- Additive enum value. Safe/idempotent. Must be committed before it's used (R2 uses it at runtime + seed).
alter type public.number_series_type_enum add value if not exists 'PURCHASE_RETURN';