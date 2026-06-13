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
        .select("role_id, roles!inner(name)")
        .eq("id", user.id)
        .single();

      if (profile?.roles?.name !== "ADMIN") {
        return Response.json({ error: "Forbidden" }, { status: 403 });
      }

      const { userId } = await req.json();

      if (!userId) {
        return Response.json({ error: "Missing userId" }, { status: 400 });
      }

      await ctx.supabaseAdmin.auth.admin.signOut(userId, "global");

      await ctx.supabaseAdmin
        .from("sessions")
        .update({ status: "REVOKED", revoked_at: new Date().toISOString() })
        .eq("user_id", userId);

      return Response.json({ success: true });
    } catch (e) {
      return Response.json(
        { error: e instanceof Error ? e.message : "Internal error" },
        { status: 500 },
      );
    }
  }),
};
