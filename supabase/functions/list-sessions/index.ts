import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

export default {
  fetch: withSupabase({ auth: ["publishable", "secret"] }, async (req, ctx) => {
    try {
      const {
        data: { user },
      } = await ctx.supabase.auth.getUser();

      if (!user) {
        return Response.json({ error: "Unauthorized" }, { status: 401 });
      }

      const { data: profile } = await ctx.supabase
        .from("users")
        .select("role_id, tenant_id, roles!inner(name)")
        .eq("id", user.id)
        .single();

      if (profile?.roles?.name !== "ADMIN") {
        return Response.json({ error: "Forbidden" }, { status: 403 });
      }

      const { data: sessions } = await ctx.supabaseAdmin
        .from("sessions")
        .select(
          "id, user_id, device_id, ip_address, user_agent, created_at, last_active_at, status, users(full_name, email)",
        )
        .eq("tenant_id", profile.tenant_id)
        .order("last_active_at", { ascending: false });

      return Response.json({ sessions: sessions ?? [] });
    } catch (e) {
      return Response.json(
        { error: e instanceof Error ? e.message : "Internal error" },
        { status: 500 },
      );
    }
  }),
};
