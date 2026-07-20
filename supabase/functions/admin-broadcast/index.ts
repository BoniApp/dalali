// ═══════════════════════════════════════════════════════════════
// admin-broadcast
// Admin-gated broadcast endpoint. Sends a chat message from the
// admin to every target user: finds or creates the admin↔user
// conversation (migration 017), inserts the message, and the
// handle_new_chat_message trigger updates unread counters and
// notifies each recipient.
// Auth: x-admin-secret == ADMIN_API_SECRET (then admin_user_id is
// required in the body), or an admin user JWT.
// ═══════════════════════════════════════════════════════════════

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-admin-secret",
};

const VALID_TARGETS = ["all", "seeker", "landlord", "agent", "influencer"];

// deno-lint-ignore no-explicit-any
async function resolveAdminId(supabase: any, req: Request): Promise<string | null> {
  const secret = req.headers.get("x-admin-secret");
  const expected = Deno.env.get("ADMIN_API_SECRET");
  if (secret && expected && secret === expected) return "secret";

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return null;
  const token = authHeader.replace("Bearer ", "");
  const {
    data: { user },
  } = await supabase.auth.getUser(token);
  if (!user) return null;
  const { data: adminRow } = await supabase
    .from("users")
    .select("id, is_admin")
    .eq("id", user.id)
    .maybeSingle();
  return adminRow?.is_admin ? adminRow.id : null;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "POST only" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const adminIdOrSecret = await resolveAdminId(supabase, req);
    if (!adminIdOrSecret) {
      return new Response(JSON.stringify({ error: "Admin only" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { message, target = "all", admin_user_id } = await req.json();
    const body = (message ?? "").toString().trim();
    if (!body) {
      return new Response(JSON.stringify({ error: "message required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    if (!VALID_TARGETS.includes(target)) {
      return new Response(JSON.stringify({ error: `target must be one of ${VALID_TARGETS.join(", ")}` }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Secret-authed calls carry no user id — the sender must be named.
    const adminId = adminIdOrSecret === "secret" ? (admin_user_id ?? "") : adminIdOrSecret;
    if (!adminId) {
      return new Response(JSON.stringify({ error: "admin_user_id required with x-admin-secret" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: adminRow } = await supabase
      .from("users")
      .select("full_name")
      .eq("id", adminId)
      .maybeSingle();
    const adminName = adminRow?.full_name || "Dalali Admin";

    // Recipients: non-admin users, optionally filtered by role.
    let query = supabase
      .from("users")
      .select("id, full_name")
      .eq("is_admin", false)
      .neq("id", adminId);
    if (target !== "all") query = query.eq("role", target);
    const { data: recipients, error: recErr } = await query;
    if (recErr) throw recErr;

    let sent = 0;
    for (const u of recipients ?? []) {
      // Find the existing thread in either direction, else create it.
      const { data: existing } = await supabase
        .from("conversations")
        .select("id")
        .or(
          `and(participant_a.eq.${adminId},participant_b.eq.${u.id}),` +
            `and(participant_a.eq.${u.id},participant_b.eq.${adminId})`
        )
        .limit(1);

      let conversationId = existing?.[0]?.id as string | undefined;
      if (!conversationId) {
        const { data: created, error: createErr } = await supabase
          .from("conversations")
          .insert({
            participant_a: adminId,
            participant_b: u.id,
            participant_a_name: adminName,
            participant_b_name: u.full_name ?? "",
          })
          .select("id")
          .single();
        if (createErr) {
          console.error("conversation create failed for", u.id, createErr.message);
          continue;
        }
        conversationId = created.id;
      }

      const { error: msgErr } = await supabase.from("messages").insert({
        conversation_id: conversationId,
        sender_id: adminId,
        body,
      });
      if (msgErr) {
        console.error("message insert failed for", u.id, msgErr.message);
        continue;
      }
      sent++;
    }

    await supabase.from("admin_logs").insert({
      admin_id: adminId,
      action: "broadcast_message",
      target_table: "conversations",
      target_id: adminId,
      details: { target, recipients: recipients?.length ?? 0, sent },
    });

    return new Response(
      JSON.stringify({ ok: true, sent, recipients: recipients?.length ?? 0 }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("admin-broadcast error:", err);
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
