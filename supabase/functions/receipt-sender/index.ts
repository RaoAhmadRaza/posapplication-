// Sale-receipt WhatsApp sender. Drains communication_logs rows (channel=WHATSAPP,
// template_code=SALE_RECEIPT, status=PENDING, fresh only), and per row: renders a branded PDF via
// receipt_render_data() → uploads it to the private `receipts` bucket → mints a short-lived signed
// URL → sends it as a WhatsApp document via Twilio → marks SENT (with the Twilio SID) or retries.
//
// Kept separate from notification-sender (which handles SMS/EMAIL/staff notifications) because the
// per-row PDF pipeline is heavy and has its own retry semantics. notification-sender explicitly
// EXCLUDES template_code='SALE_RECEIPT' so the two never collide on the same table.
//
// Service-role only (auth:["secret"]) — triggered by the receipt_sender_2min pg_cron job.
//
// Deploy:  supabase functions deploy receipt-sender
// Secrets: supabase secrets set TWILIO_SID=... TWILIO_AUTH=... TWILIO_WHATSAPP_FROM=whatsapp:+... \
//            SALE_RECEIPT_CONTENT_SID=HX...   (ContentSid optional — omit to use sandbox free-form)

import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { buildReceiptPdf } from "./pdf.ts";

const BATCH = 15;
const MAX_ATTEMPTS = 3;
const FRESH_MINUTES = 30; // ignore anything older than this (backlog defense-in-depth)
const SIGNED_URL_TTL = 300; // seconds — Twilio fetches the media server-side within seconds

// Send a WhatsApp document via Twilio. Prod path uses an approved template (ContentSid); without one
// it falls back to free-form Body + MediaUrl, which is deliverable ONLY inside the Twilio sandbox
// 24h session (a real business-initiated receipt requires the approved template).
async function sendWhatsAppDocument(
  to: string, mediaUrl: string, vars: { business: string; invoice: string; total: string },
): Promise<string> {
  const sid = Deno.env.get("TWILIO_SID");
  const auth = Deno.env.get("TWILIO_AUTH");
  if (!sid || !auth) throw new Error("twilio keys unset");
  const from = Deno.env.get("TWILIO_WHATSAPP_FROM") ?? Deno.env.get("TWILIO_FROM");
  if (!from) throw new Error("twilio whatsapp from unset");
  const contentSid = Deno.env.get("SALE_RECEIPT_CONTENT_SID");

  const params = new URLSearchParams({
    To: `whatsapp:${to}`,
    From: from.startsWith("whatsapp:") ? from : `whatsapp:${from}`,
  });
  if (contentSid) {
    // Template must be built with a document header bound to variable {{1}} (the media URL) plus
    // body variables {{2}}=business, {{3}}=invoice number, {{4}}=total. Adjust to the approved template.
    params.set("ContentSid", contentSid);
    params.set("ContentVariables", JSON.stringify({
      "1": mediaUrl, "2": vars.business, "3": vars.invoice, "4": vars.total,
    }));
  } else {
    params.set("Body", `Receipt ${vars.invoice} — ${vars.business}. Total ${vars.total}.`);
    params.set("MediaUrl", mediaUrl);
  }

  const r = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`, {
    method: "POST",
    headers: {
      Authorization: "Basic " + btoa(`${sid}:${auth}`),
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: params,
  });
  const json = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(`twilio ${r.status}: ${json?.message ?? JSON.stringify(json)}`);
  return String(json?.sid ?? "");
}

// deno-lint-ignore no-explicit-any
async function drain(sb: any) {
  let sent = 0, failed = 0, retried = 0;
  const now = () => new Date().toISOString();
  const cutoff = new Date(Date.now() - FRESH_MINUTES * 60_000).toISOString();

  const { data: rows } = await sb.from("communication_logs")
    .select("id, tenant_id, invoice_id, recipient, payload, attempts")
    .eq("channel", "WHATSAPP").eq("template_code", "SALE_RECEIPT").eq("status", "PENDING")
    .gte("created_at", cutoff).limit(BATCH);

  for (const row of rows ?? []) {
    try {
      if (!row.recipient) throw new Error("no recipient phone");
      if (!row.invoice_id) throw new Error("no invoice_id");

      // 1) gather all receipt data (tenant resolved server-side from the invoice)
      const { data: rd, error: rdErr } = await sb.rpc("receipt_render_data", { p_invoice_id: row.invoice_id });
      if (rdErr || !rd) throw new Error(`receipt_render_data: ${rdErr?.message ?? "no data"}`);

      // 2) render + 3) upload (service-role bypasses RLS)
      const pdf = await buildReceiptPdf(rd);
      const path = `${row.tenant_id}/${row.invoice_id}.pdf`;
      const up = await sb.storage.from("receipts").upload(path, pdf, {
        contentType: "application/pdf", upsert: true,
      });
      if (up.error) throw new Error(`storage upload: ${up.error.message}`);

      // 4) fresh signed URL at send time (never persisted)
      const signed = await sb.storage.from("receipts").createSignedUrl(path, SIGNED_URL_TTL);
      if (signed.error || !signed.data?.signedUrl) throw new Error(`signed url: ${signed.error?.message}`);

      // 5) send
      const inv = rd.invoice ?? {}, biz = rd.business ?? {};
      const twilioSid = await sendWhatsAppDocument(row.recipient, signed.data.signedUrl, {
        business: String(biz.name ?? ""),
        invoice: String(inv.number ?? ""),
        total: Number(inv.grand_total ?? 0).toLocaleString("en-US", { minimumFractionDigits: 2 }),
      });

      // 6) mark SENT (keep the media path + twilio sid for reconciliation)
      await sb.from("communication_logs").update({
        status: "SENT", sent_at: now(),
        payload: { ...(row.payload ?? {}), media_path: path, twilio_sid: twilioSid },
      }).eq("id", row.id);
      sent++;
    } catch (e) {
      const attempts = (row.attempts ?? 0) + 1;
      const terminal = attempts >= MAX_ATTEMPTS;
      await sb.from("communication_logs").update({
        attempts,
        status: terminal ? "FAILED" : "PENDING",
        error: String(e instanceof Error ? e.message : e),
      }).eq("id", row.id);
      terminal ? failed++ : retried++;
    }
  }
  return { sent, failed, retried };
}

export default {
  fetch: withSupabase({ auth: ["secret"] }, async (_req, ctx) => {
    try {
      return Response.json(await drain(ctx.supabaseAdmin));
    } catch (e) {
      return Response.json(
        { error: e instanceof Error ? e.message : "Internal error" },
        { status: 500 },
      );
    }
  }),
};
