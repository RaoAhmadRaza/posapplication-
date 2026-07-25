// llm-proxy — the AI companion's server-side brain (OpenAI).
//
// Auth: the classic edge-function pattern — a Supabase client built with the project's
// ANON key + the CALLER's Authorization JWT, then getUser(). The client is RLS-scoped to
// the caller, so all data tools return only the caller's own tenant data (cross-tenant
// leakage is structurally impossible).
//
// Deploy WITHOUT gateway JWT verification (auth is done here):
//   supabase functions deploy llm-proxy --no-verify-jwt
//
// OpenAI key lives ONLY here (Deno.env), never in the app:
//   supabase secrets set OPENAI_API_KEY=sk-...
//   supabase secrets set OPENAI_MODEL=gpt-4o-mini   (optional; cheap default below)
//
// Returns a text/event-stream (SSE). Frames:
//   event: delta  data: {"text": "..."}          incremental assistant text
//   event: tool   data: {"name": "..."}          a read tool is being called (UX status)
//   event: done   data: {"conversation_id": ".."} stream complete, messages persisted
//   event: error  data: {"message": "..."}        mid-stream failure

import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";
import OpenAI from "openai";
import { runTool, openaiTools } from "./tools.ts";
import { buildSystem } from "./prompt.ts";

// Cheapest reliable default with solid function-calling. Override without a code edit:
//   supabase secrets set OPENAI_MODEL=gpt-4.1-nano   (or gpt-5-nano for the cheapest tier)
const MODEL = Deno.env.get("OPENAI_MODEL") ?? "gpt-4o-mini";
const RATE_WINDOW_SEC = 60; // per-user request budget window
const RATE_MAX = 20; // max user messages per window (abuse / cost guard)

// deno-lint-ignore no-explicit-any
type Any = any;

// SDK/API errors sometimes arrive as a (double-nested) JSON string; pull out the readable
// message so the chat shows "You exceeded your quota…" not a raw blob.
function cleanError(e: unknown): string {
  const raw = e instanceof Error ? e.message : String(e);
  try {
    const outer = JSON.parse(raw);
    const msg = outer?.error?.message ?? outer?.message;
    if (typeof msg === "string") {
      try {
        const inner = JSON.parse(msg);
        return String(inner?.error?.message ?? msg).trim();
      } catch {
        return msg.trim();
      }
    }
  } catch {
    // not JSON — fall through
  }
  return raw;
}

Deno.serve(async (req) => {
  try {
    console.log("[llm-proxy] request received", req.method);

    // --- auth: RLS-scoped client from the caller's JWT, then getUser() ---
    const authHeader = req.headers.get("Authorization") ?? "";
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user }, error: authErr } = await supabase.auth.getUser();
    console.log("[llm-proxy] auth", { hasUser: !!user, authError: authErr?.message ?? null });
    if (!user) return Response.json({ error: "Unauthorized" }, { status: 401 });

    const { data: profile } = await supabase
      .from("users").select("tenant_id, role_id").eq("id", user.id).single();
    const tenantId = profile?.tenant_id as string | undefined;
    const roleId = profile?.role_id as string | undefined;
    console.log("[llm-proxy] profile", { hasTenant: !!tenantId, hasRole: !!roleId });
    if (!tenantId) return Response.json({ error: "No tenant" }, { status: 403 });

    // caller's granted "module:action" keys → tailors what the assistant will route to
    const { data: perms } = await supabase
      .from("permissions").select("module, action").eq("role_id", roleId).eq("granted", true);
    const permissionKeys = (perms ?? []).map((p: Any) => `${p.module}:${p.action}`);
    console.log("[llm-proxy] permissions loaded", permissionKeys.length);

    const key = Deno.env.get("OPENAI_API_KEY");
    console.log("[llm-proxy] OPENAI_API_KEY present", !!key, "model", MODEL);
    if (!key) throw new Error("OPENAI_API_KEY unset");
    const openai = new OpenAI({ apiKey: key });

    const body = await req.json().catch(() => ({}));
    const userMessage = String(body.message ?? "").trim();
    console.log("[llm-proxy] message length", userMessage.length);
    if (!userMessage) return Response.json({ error: "Missing message" }, { status: 400 });

    // Per-user rate limit — the RLS policy scopes this count to the caller only.
    const sinceIso = new Date(Date.now() - RATE_WINDOW_SEC * 1000).toISOString();
    const { count } = await supabase
      .from("chat_messages")
      .select("id", { count: "exact", head: true })
      .eq("role", "user")
      .gte("created_at", sinceIso);
    console.log("[llm-proxy] recent user msgs (rate window)", count);
    if ((count ?? 0) >= RATE_MAX) {
      return Response.json(
        { error: "You're sending messages too fast. Please wait a moment." },
        { status: 429 },
      );
    }

    // --- resolve or create the conversation (RLS-scoped) ---
    let conversationId = body.conversation_id as string | undefined;
    if (!conversationId) {
      const { data: conv, error } = await supabase
        .from("chat_conversations")
        .insert({ tenant_id: tenantId, user_id: user.id, title: userMessage.slice(0, 60) })
        .select("id").single();
      if (error || !conv) throw new Error(`could not create conversation: ${error?.message ?? ""}`);
      conversationId = conv.id as string;
    }

    // --- load prior history (RLS-scoped) → OpenAI messages ---
    const { data: prior } = await supabase
      .from("chat_messages")
      .select("role, content")
      .eq("conversation_id", conversationId)
      .order("created_at", { ascending: true });
    const messages: Any[] = [{ role: "system", content: buildSystem(permissionKeys) }];
    for (const m of (prior ?? []) as Any[]) {
      messages.push({ role: m.role, content: m.content });
    }
    messages.push({ role: "user", content: userMessage });
    console.log("[llm-proxy] history turns", messages.length, "→ calling", MODEL);

    const tools = openaiTools();

    // --- stream the tool-call loop back as SSE ---
    const encoder = new TextEncoder();
    const stream = new ReadableStream({
      async start(controller) {
        const send = (event: string, data: unknown) =>
          controller.enqueue(encoder.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`));
        try {
          let assistantText = "";
          const toolAudit: { name: string; input: unknown }[] = [];
          const usage = { model: MODEL, prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 };

          // Manual loop: stream content deltas; when the model returns tool_calls, run the
          // read tools and continue with tool result messages. Ends when a turn has no calls.
          while (true) {
            const completion = await openai.chat.completions.create({
              model: MODEL,
              messages,
              tools,
              stream: true,
              stream_options: { include_usage: true },
            });

            let turnText = "";
            // Accumulate streamed tool_calls by index (id/name once, arguments in fragments).
            const partial: Record<number, { id: string; name: string; args: string }> = {};
            for await (const chunk of completion) {
              const choice = chunk.choices[0];
              const delta = choice?.delta;
              if (delta?.content) {
                turnText += delta.content;
                assistantText += delta.content;
                send("delta", { text: delta.content });
              }
              if (delta?.tool_calls) {
                for (const tc of delta.tool_calls) {
                  const i = tc.index ?? 0;
                  partial[i] ??= { id: "", name: "", args: "" };
                  if (tc.id) partial[i].id = tc.id;
                  if (tc.function?.name) partial[i].name = tc.function.name;
                  if (tc.function?.arguments) partial[i].args += tc.function.arguments;
                }
              }
              if (chunk.usage) {
                usage.prompt_tokens = chunk.usage.prompt_tokens ?? 0;
                usage.completion_tokens = chunk.usage.completion_tokens ?? 0;
                usage.total_tokens = chunk.usage.total_tokens ?? 0;
              }
            }

            const calls = Object.values(partial);
            console.log("[llm-proxy] turn done", {
              textLen: turnText.length,
              calls: calls.map((c) => c.name),
            });

            if (calls.length === 0) {
              messages.push({ role: "assistant", content: turnText });
              break;
            }

            // Append the assistant turn carrying the tool calls, then each tool result.
            messages.push({
              role: "assistant",
              content: turnText || null,
              tool_calls: calls.map((c) => ({
                id: c.id,
                type: "function",
                function: { name: c.name, arguments: c.args || "{}" },
              })),
            });

            for (const c of calls) {
              send("tool", { name: c.name });
              let args: Record<string, unknown> = {};
              try {
                args = JSON.parse(c.args || "{}");
              } catch {
                args = {};
              }
              console.log("[llm-proxy] running tool", c.name, args);
              toolAudit.push({ name: c.name, input: args });
              let toolResult: unknown;
              try {
                toolResult = await runTool(supabase as Any, c.name, args);
              } catch (e) {
                toolResult = { error: e instanceof Error ? e.message : "tool error" };
              }
              messages.push({
                role: "tool",
                tool_call_id: c.id,
                content: JSON.stringify(toolResult ?? null),
              });
            }
          }

          // --- persist both messages (RLS-scoped) ---
          await supabase.from("chat_messages").insert([
            {
              conversation_id: conversationId,
              tenant_id: tenantId,
              user_id: user.id,
              role: "user",
              content: userMessage,
            },
            {
              conversation_id: conversationId,
              tenant_id: tenantId,
              user_id: user.id,
              role: "assistant",
              content: assistantText,
              tool_calls: toolAudit.length ? toolAudit : null,
              usage,
            },
          ]);
          await supabase
            .from("chat_conversations")
            .update({ updated_at: new Date().toISOString() })
            .eq("id", conversationId);

          console.log("[llm-proxy] done", {
            conversation: conversationId,
            answerLen: assistantText.length,
            usage,
          });
          send("done", { conversation_id: conversationId });
        } catch (e) {
          console.error("[llm-proxy] STREAM ERROR", e);
          send("error", { message: cleanError(e) });
        } finally {
          controller.close();
        }
      },
    });

    return new Response(stream, {
      headers: {
        "content-type": "text/event-stream",
        "cache-control": "no-cache",
        "connection": "keep-alive",
      },
    });
  } catch (e) {
    console.error("[llm-proxy] FATAL", e);
    return Response.json({ error: cleanError(e) }, { status: 500 });
  }
});
