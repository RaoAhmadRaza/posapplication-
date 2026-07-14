// Unified outbound sender. Drains PENDING rows from notifications (non-IN_APP),
// communication_logs, and report_deliveries to Twilio (SMS/WhatsApp) + SendGrid (email),
// marking each SENT or FAILED. Service-role, all tenants — guarded by the secret key
// (auth:["secret"]), so only the cron/scheduler (bearer = service key) can trigger it.
//
// Deploy:  supabase functions deploy notification-sender
// Secrets: supabase secrets set TWILIO_SID=... TWILIO_AUTH=... TWILIO_FROM=... \
//                               TWILIO_WHATSAPP_FROM=... SENDGRID_KEY=... FROM_EMAIL=...
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

const BATCH = 100;

async function sendSms(to: string, body: string, whatsapp = false) {
  const sid = Deno.env.get("TWILIO_SID");
  const auth = Deno.env.get("TWILIO_AUTH");
  if (!sid || !auth) throw new Error("twilio keys unset");
  const from = whatsapp
    ? `whatsapp:${Deno.env.get("TWILIO_WHATSAPP_FROM") ?? Deno.env.get("TWILIO_FROM")}`
    : Deno.env.get("TWILIO_FROM")!;
  const dest = whatsapp ? `whatsapp:${to}` : to;
  const r = await fetch(
    `https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`,
    {
      method: "POST",
      headers: {
        Authorization: "Basic " + btoa(`${sid}:${auth}`),
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({ To: dest, From: from, Body: body }),
    },
  );
  if (!r.ok) throw new Error(`twilio ${r.status}: ${await r.text()}`);
}

async function sendEmail(to: string, subject: string, html: string) {
  const key = Deno.env.get("SENDGRID_KEY");
  const from = Deno.env.get("FROM_EMAIL");
  if (!key || !from) throw new Error("sendgrid keys unset");
  const r = await fetch("https://api.sendgrid.com/v3/mail/send", {
    method: "POST",
    headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      personalizations: [{ to: [{ email: to }] }],
      from: { email: from },
      subject,
      content: [{ type: "text/html", value: html }],
    }),
  });
  if (!r.ok) throw new Error(`sendgrid ${r.status}: ${await r.text()}`);
}

// deno-lint-ignore no-explicit-any
async function dispatch(channel: string, to: string, subject: string, body: string) {
  if (!to) throw new Error("no recipient");
  if (channel === "EMAIL") await sendEmail(to, subject, body);
  else if (channel === "WHATSAPP") await sendSms(to, body, true);
  else await sendSms(to, body); // SMS
}

// deno-lint-ignore no-explicit-any
async function drain(sb: any) {
  let sent = 0, failed = 0;
  const now = () => new Date().toISOString();

  // 1) user-directed notifications (PUSH has no transport yet — excluded)
  const { data: notifs } = await sb.from("notifications")
    .select("id, channel, title, body, user_id")
    .in("channel", ["SMS", "EMAIL", "WHATSAPP"]).eq("status", "PENDING").limit(BATCH);
  for (const n of notifs ?? []) {
    try {
      const { data: u } = await sb.from("users").select("phone, email").eq("id", n.user_id).single();
      const to = n.channel === "EMAIL" ? u?.email : u?.phone;
      await dispatch(n.channel, to, n.title, n.body);
      await sb.from("notifications").update({ status: "SENT", sent_at: now() }).eq("id", n.id);
      sent++;
    } catch (e) {
      await sb.from("notifications").update({ status: "FAILED", failed_reason: String(e) }).eq("id", n.id);
      failed++;
    }
  }

  // 2) communication_logs (customer notices)  3) report_deliveries (report emails)
  // Same shape: channel + recipient + payload; error column is `error` on both.
  for (const tbl of ["communication_logs", "report_deliveries"]) {
    const { data: rows } = await sb.from(tbl)
      .select("id, channel, recipient, payload").eq("status", "PENDING").limit(BATCH);
    for (const row of rows ?? []) {
      try {
        const channel = row.channel ?? "EMAIL";
        const p = row.payload ?? {};
        const subject = p.subject ?? p.name ?? "Notification";
        const body = p.body ?? p.html ?? JSON.stringify(p);
        await dispatch(channel, row.recipient, subject, body);
        await sb.from(tbl).update({ status: "SENT", sent_at: now() }).eq("id", row.id);
        sent++;
      } catch (e) {
        await sb.from(tbl).update({ status: "FAILED", error: String(e) }).eq("id", row.id);
        failed++;
      }
    }
  }
  return { sent, failed };
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
