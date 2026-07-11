-- next_number is SECURITY DEFINER (owner postgres). Its only callers are other SECURITY DEFINER
-- RPCs — create_sale, create_sales_return, create_stock_transfer, open_stock_count — which execute
-- its body as the owner, NOT as the invoking role. Revoking EXECUTE from authenticated therefore
-- removes direct client access without affecting any internal caller.
-- Verified 2026-07-10: zero `.rpc('next_number')` calls in lib/; proacl = {postgres,authenticated,service_role}.
-- Body intentionally unchanged (four RPCs depend on it).
revoke execute on function public.next_number(number_series_type_enum, uuid) from authenticated;
revoke execute on function public.next_number(number_series_type_enum, uuid) from public;