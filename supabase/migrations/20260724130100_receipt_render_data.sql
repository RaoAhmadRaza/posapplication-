-- WhatsApp PDF receipt, part 2/6: receipt_render_data(invoice_id) — one call returning everything
-- the receipt-sender edge function needs to render a branded PDF.
--
-- SECURITY DEFINER, tenant resolved FROM THE INVOICE ROW (no auth.uid(); the caller is the
-- service-role edge function, which has no JWT tenant). Execute is revoked from authenticated so a
-- client can never pull another tenant's receipt data — only the service-role sender calls it.
--
-- Business header comes from tenants.name + tenants.settings_json convention keys
-- (business_address, phone, logo_url, receipt_footer, ntn); logo falls back to the tenants.logo_url
-- column. Branch "address" = city + country (branches has no street column). Line items expose the
-- sale-time description (no product-name join — matches the on-device receipt).

create or replace function public.receipt_render_data(p_invoice_id uuid)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare
  v_t uuid;
  v_result jsonb;
begin
  select tenant_id into v_t from invoices where id = p_invoice_id;
  if v_t is null then raise exception 'ERR_INVOICE_NOT_FOUND'; end if;

  select jsonb_build_object(
    'business', (
      select jsonb_build_object(
        'name', t.name,
        'address', coalesce(t.settings_json->>'business_address', ''),
        'phone', coalesce(t.settings_json->>'phone', ''),
        'ntn', coalesce(t.settings_json->>'ntn', ''),
        'logo_url', coalesce(nullif(t.settings_json->>'logo_url',''), t.logo_url, ''),
        'receipt_footer', coalesce(t.settings_json->>'receipt_footer', '')
      ) from tenants t where t.id = v_t
    ),
    'branch', (
      select jsonb_build_object(
        'name', b.name,
        'address', trim(both ', ' from concat_ws(', ', nullif(b.city,''), nullif(b.country,'')))
      ) from branches b where b.id = i.branch_id
    ),
    'customer', (
      select jsonb_build_object('name', c.name, 'phone', coalesce(c.phone,''))
      from customers c where c.id = i.customer_id
    ),
    'invoice', jsonb_build_object(
      'number', i.invoice_number,
      'date', i.created_at,
      'subtotal', i.subtotal,
      'discount_total', i.discount_total,
      'tax_total', i.tax_total,
      'grand_total', i.grand_total,
      'paid_amount', i.paid_amount,
      'change_amount', i.change_amount,
      'balance', i.balance,
      'status', i.status
    ),
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'description', it.description,
        'qty', it.qty,
        'unit_price', it.unit_price,
        'discount_amount', it.discount_amount,
        'tax_amount', it.tax_amount,
        'line_total', it.line_total
      ) order by it.created_at)
      from invoice_items it where it.invoice_id = i.id
    ), '[]'::jsonb),
    'payments', coalesce((
      select jsonb_agg(jsonb_build_object(
        'method', p.method::text,
        'amount', p.amount,
        'reference', p.reference
      ) order by p.created_at)
      from payments p where p.invoice_id = i.id
    ), '[]'::jsonb)
  ) into v_result
  from invoices i where i.id = p_invoice_id;

  return v_result;
end; $function$;

revoke execute on function public.receipt_render_data(uuid) from public, anon, authenticated;
grant execute on function public.receipt_render_data(uuid) to service_role;
