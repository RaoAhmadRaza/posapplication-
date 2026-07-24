// Unified outbound sender. Drains PENDING rows from notifications (non-IN_APP),
// communication_logs, and report_deliveries to Twilio (SMS/WhatsApp) + SendGrid (email)
// + FCM (PUSH, fanned out to device_tokens), marking each SENT or FAILED — PUSH rows with no
// active device token are SKIPPED instead (see the 1b) block: no device can register a token
// yet, so that's not a transient error, and this sender is one-shot with no retry/attempts
// column, so FAILED there would be permanent and unrecoverable except by hand-resetting status.
// Service-role, all tenants — guarded by the secret key
// (auth:["secret"]), so only the cron/scheduler (bearer = service key) can trigger it.
//
// Deploy:  supabase functions deploy notification-sender
// Secrets: supabase secrets set TWILIO_SID=... TWILIO_AUTH=... TWILIO_FROM=... \
//            TWILIO_WHATSAPP_FROM=... SENDGRID_KEY=... FROM_EMAIL=... \
//            FCM_SERVICE_ACCOUNT='<firebase service-account JSON>'
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

const BATCH = 100;

// --- FCM v1 push (OAuth token minted from the service-account JSON) --------------
function b64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

let fcmCache: { token: string; exp: number; projectId: string } | null = null;

async function fcmAuth(): Promise<{ token: string; projectId: string }> {
  const now = Math.floor(Date.now() / 1000);
  if (fcmCache && fcmCache.exp - 60 > now) return fcmCache;
  const raw = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!raw) throw new Error("fcm key unset");
  const sa = JSON.parse(raw); // { client_email, private_key, project_id }
  const header = b64url(new TextEncoder().encode(JSON.stringify({ alg: "RS256", typ: "JWT" })));
  const claims = b64url(new TextEncoder().encode(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now, exp: now + 3600,
  })));
  const pem = sa.private_key.replace(/-----[^-]+-----/g, "").replace(/\s/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8", der, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"],
  );
  const sig = new Uint8Array(await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${header}.${claims}`),
  ));
  const jwt = `${header}.${claims}.${b64url(sig)}`;
  const r = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!r.ok) throw new Error(`fcm oauth ${r.status}: ${await r.text()}`);
  const { access_token } = await r.json();
  fcmCache = { token: access_token, exp: now + 3600, projectId: sa.project_id };
  return fcmCache;
}

async function sendPush(token: string, title: string, body: string, actionUrl?: string | null) {
  const { token: bearer, projectId } = await fcmAuth();
  const r = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
    method: "POST",
    headers: { Authorization: `Bearer ${bearer}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      message: { token, notification: { title, body }, data: actionUrl ? { action_url: actionUrl } : {} },
    }),
  });
  if (!r.ok) throw new Error(`fcm ${r.status}: ${await r.text()}`);
}

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
  let sent = 0, failed = 0, skipped = 0;
  const now = () => new Date().toISOString();
  // Freshness window: never send rows older than this. Defense-in-depth against a stale backlog
  // (the queues were never drained before this sender was wired). Quarantine migration handles
  // the historical rows; this stops any future gap/backfill from blasting old messages.
  const cutoff = new Date(Date.now() - 30 * 60_000).toISOString();

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

  // 1b) PUSH notifications — fan out to the user's active device tokens
  const { data: pushes } = await sb.from("notifications")
    .select("id, title, body, user_id, action_url")
    .eq("channel", "PUSH").eq("status", "PENDING").limit(BATCH);
  for (const n of pushes ?? []) {
    try {
      const { data: toks } = await sb.from("device_tokens")
        .select("token").eq("user_id", n.user_id).eq("is_active", true);
      if (!toks?.length) {
        // Unsendable by construction, not a transient error: no device can register a token yet
        // (the Flutter half of push was deferred, never built). SKIP, don't FAIL — this sender is
        // one-shot (PENDING -> SENT or FAILED, no attempts column, no retry), so a FAILED row here
        // is permanent and unrecoverable except by hand-resetting status. SKIPPED says "this was
        // never going to work"; FAILED (below) stays reserved for a real send attempt that broke.
        await sb.from("notifications")
          .update({ status: "SKIPPED", failed_reason: "PUSH unsupported: no device token registration" })
          .eq("id", n.id);
        skipped++;
        continue;
      }
      for (const t of toks) await sendPush(t.token, n.title, n.body, n.action_url);
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
    let q = sb.from(tbl)
      .select("id, channel, recipient, payload")
      .eq("status", "PENDING").gte("created_at", cutoff);
    // SALE_RECEIPT rows are WhatsApp PDF receipts owned by the receipt-sender function — this generic
    // sender must NOT touch them (it would send JSON.stringify(payload) as garbage text). Exclude them.
    if (tbl === "communication_logs") q = q.neq("template_code", "SALE_RECEIPT");
    const { data: rows } = await q.limit(BATCH);
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
  return { sent, failed, skipped };
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
