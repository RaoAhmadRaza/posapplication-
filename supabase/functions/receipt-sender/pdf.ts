// Renders a branded A4 sales-receipt PDF from receipt_render_data() output, using pdf-lib
// (pure JS, no headless browser — safe in the Deno edge runtime).
//
// LIMITATION (v1): pdf-lib's standard fonts are WinAnsi and it does NO Arabic/Urdu shaping or bidi.
// Business/customer names in Latin script render correctly; Urdu would render as disconnected,
// reversed glyphs. For an Urdu branded header, pre-render it as an image and embed it via the logo
// slot (embedPng) — the header image path is a future extension, flagged in the plan.

import { PDFDocument, StandardFonts, rgb, PDFFont, PDFPage } from "pdf-lib";

// deno-lint-ignore no-explicit-any
type Json = Record<string, any>;

const A4 = { w: 595.28, h: 841.89 };
const MARGIN = 48;
const INK = rgb(0.09, 0.09, 0.09);
const MUTED = rgb(0.45, 0.45, 0.45);
const LINE = rgb(0.85, 0.85, 0.85);

function money(v: unknown): string {
  const n = Number(v ?? 0);
  return n.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function fmtDate(iso: unknown): string {
  if (!iso) return "";
  const d = new Date(String(iso));
  if (isNaN(d.getTime())) return String(iso);
  return d.toISOString().slice(0, 16).replace("T", " ");
}

// Fetch a PNG/JPEG logo with a timeout; return null on any failure (best-effort, never blocks).
async function fetchLogo(url: string): Promise<{ bytes: Uint8Array; kind: "png" | "jpg" } | null> {
  if (!url) return null;
  try {
    const ctrl = new AbortController();
    const t = setTimeout(() => ctrl.abort(), 4000);
    const r = await fetch(url, { signal: ctrl.signal });
    clearTimeout(t);
    if (!r.ok) return null;
    const ct = r.headers.get("content-type") ?? "";
    const buf = new Uint8Array(await r.arrayBuffer());
    if (ct.includes("png")) return { bytes: buf, kind: "png" };
    if (ct.includes("jpeg") || ct.includes("jpg")) return { bytes: buf, kind: "jpg" };
    return null; // pdf-lib decodes PNG/JPEG only — skip webp/svg/gif
  } catch {
    return null;
  }
}

export async function buildReceiptPdf(data: Json): Promise<Uint8Array> {
  const business = data.business ?? {};
  const branch = data.branch ?? {};
  const customer = data.customer ?? {};
  const inv = data.invoice ?? {};
  const items: Json[] = Array.isArray(data.items) ? data.items : [];
  const payments: Json[] = Array.isArray(data.payments) ? data.payments : [];

  const doc = await PDFDocument.create();
  const font = await doc.embedFont(StandardFonts.Helvetica);
  const bold = await doc.embedFont(StandardFonts.HelveticaBold);
  const logo = await fetchLogo(String(business.logo_url ?? ""));

  let page = doc.addPage([A4.w, A4.h]);
  let y = A4.h - MARGIN;
  const left = MARGIN;
  const right = A4.w - MARGIN;

  const text = (
    s: string, x: number, yy: number,
    opts: { size?: number; font?: PDFFont; color?: typeof INK; align?: "left" | "right" } = {},
  ) => {
    const f = opts.font ?? font;
    const size = opts.size ?? 9;
    let px = x;
    if (opts.align === "right") px = x - f.widthOfTextAtSize(s, size);
    page.drawText(s, { x: px, y: yy, size, font: f, color: opts.color ?? INK });
  };

  const hr = (yy: number) => page.drawLine({
    start: { x: left, y: yy }, end: { x: right, y: yy }, thickness: 0.5, color: LINE,
  });

  const ensure = (needed: number) => {
    if (y - needed < MARGIN) { page = doc.addPage([A4.w, A4.h]); y = A4.h - MARGIN; }
  };

  // ---- Header: logo + business identity ----
  if (logo) {
    try {
      const img = logo.kind === "png" ? await doc.embedPng(logo.bytes) : await doc.embedJpg(logo.bytes);
      const scaled = img.scaleToFit(120, 48);
      page.drawImage(img, { x: left, y: y - scaled.height, width: scaled.width, height: scaled.height });
    } catch { /* skip logo on decode failure */ }
  }
  text(String(business.name ?? ""), right, y - 10, { size: 15, font: bold, align: "right" });
  let hy = y - 26;
  for (const line of [business.address, business.phone, business.ntn ? `NTN: ${business.ntn}` : ""]) {
    const s = String(line ?? "").trim();
    if (!s) continue;
    text(s, right, hy, { size: 8, color: MUTED, align: "right" });
    hy -= 12;
  }
  y = Math.min(y - 56, hy - 8);
  hr(y); y -= 18;

  // ---- Invoice meta ----
  text("RECEIPT", left, y, { size: 12, font: bold });
  text(`#${inv.number ?? ""}`, right, y, { size: 11, font: bold, align: "right" });
  y -= 14;
  text(fmtDate(inv.date), left, y, { size: 8, color: MUTED });
  if (branch.name) text(String(branch.name) + (branch.address ? ` · ${branch.address}` : ""), right, y, { size: 8, color: MUTED, align: "right" });
  y -= 12;
  if (customer.name) { text(`Bill to: ${customer.name}`, left, y, { size: 9 }); y -= 12; }
  y -= 4; hr(y); y -= 16;

  // ---- Items table ----
  const cQty = left + 250, cUnit = left + 330, cTot = right;
  text("Item", left, y, { size: 8, font: bold, color: MUTED });
  text("Qty", cQty, y, { size: 8, font: bold, color: MUTED, align: "right" });
  text("Price", cUnit, y, { size: 8, font: bold, color: MUTED, align: "right" });
  text("Total", cTot, y, { size: 8, font: bold, color: MUTED, align: "right" });
  y -= 12;

  for (const it of items) {
    ensure(16);
    const desc = String(it.description ?? "Item");
    const maxW = cQty - left - 60;
    let d = desc;
    while (font.widthOfTextAtSize(d, 9) > maxW && d.length > 4) d = d.slice(0, -2);
    if (d !== desc) d = d.slice(0, -1) + "…";
    text(d, left, y, { size: 9 });
    text(String(Number(it.qty ?? 0)), cQty, y, { size: 9, align: "right" });
    text(money(it.unit_price), cUnit, y, { size: 9, align: "right" });
    text(money(it.line_total), cTot, y, { size: 9, align: "right" });
    y -= 14;
  }
  y -= 2; hr(y); y -= 16;

  // ---- Totals ----
  const totalRow = (label: string, val: unknown, strong = false) => {
    ensure(14);
    const f = strong ? bold : font;
    text(label, cUnit, y, { size: strong ? 10 : 9, font: f, align: "right" });
    text(money(val), cTot, y, { size: strong ? 10 : 9, font: f, align: "right" });
    y -= strong ? 16 : 13;
  };
  totalRow("Subtotal", inv.subtotal);
  if (Number(inv.discount_total ?? 0) > 0) totalRow("Discount", inv.discount_total);
  if (Number(inv.tax_total ?? 0) > 0) totalRow("Tax", inv.tax_total);
  totalRow("Total", inv.grand_total, true);
  totalRow("Paid", inv.paid_amount);
  if (Number(inv.change_amount ?? 0) > 0) totalRow("Change", inv.change_amount);
  if (Number(inv.balance ?? 0) > 0) totalRow("Balance due", inv.balance, true);

  // ---- Payments ----
  if (payments.length) {
    y -= 4; hr(y); y -= 16;
    text("Payments", left, y, { size: 8, font: bold, color: MUTED }); y -= 13;
    for (const p of payments) {
      ensure(13);
      const label = String(p.method ?? "").replace(/_/g, " ");
      text(label + (p.reference ? ` (${p.reference})` : ""), left, y, { size: 9 });
      text(money(p.amount), cTot, y, { size: 9, align: "right" });
      y -= 13;
    }
  }

  // ---- Footer ----
  const footer = String(business.receipt_footer ?? "").trim() || "Thank you for your business.";
  ensure(30); y -= 10; hr(y); y -= 16;
  text(footer, left, y, { size: 8, color: MUTED });

  return await doc.save();
}
