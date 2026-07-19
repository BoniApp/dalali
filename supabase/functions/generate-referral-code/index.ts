// ═══════════════════════════════════════════════════════════════
// generate-referral-code
// Admin-gated approval endpoint for influencer applications.
// Approves the application, creates/activates the influencer profile,
// mints a unique referral code + default link, flips users.role to
// 'influencer', ensures a wallet row exists, and notifies the user.
// Auth: x-admin-secret == ADMIN_API_SECRET, or an admin user JWT.
// ═══════════════════════════════════════════════════════════════

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-admin-secret",
};

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

function randomSuffix(len: number): string {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const bytes = new Uint8Array(len);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => alphabet[b % alphabet.length]).join("");
}

// deno-lint-ignore no-explicit-any
async function mintCode(supabase: any, fullName: string): Promise<string> {
  const base =
    (fullName || "").replace(/[^a-zA-Z]/g, "").toUpperCase().slice(0, 8) || "DALALI";
  for (let i = 0; i < 6; i++) {
    const candidate = `${base}${randomSuffix(4)}`;
    const { data: clash } = await supabase
      .from("influencers")
      .select("user_id")
      .eq("referral_code", candidate)
      .maybeSingle();
    if (!clash) return candidate;
  }
  return `${base}${Date.now().toString(36).toUpperCase()}`;
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

    const adminId = await resolveAdminId(supabase, req);
    if (!adminId) {
      return new Response(JSON.stringify({ error: "Admin only" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { application_id } = await req.json();
    if (!application_id) {
      return new Response(JSON.stringify({ error: "application_id required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: app } = await supabase
      .from("influencer_applications")
      .select("*")
      .eq("id", application_id)
      .maybeSingle();
    if (!app) {
      return new Response(JSON.stringify({ error: "Application not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    if (app.status !== "pending") {
      return new Response(JSON.stringify({ error: `Already ${app.status}` }), {
        status: 409,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // If the user already has an influencer row (signed up directly with
    // the influencer role — migration 013 trigger), reuse the existing
    // code instead of minting a new one, so shared links keep working.
    const { data: existing } = await supabase
      .from("influencers")
      .select("referral_code")
      .eq("user_id", app.user_id)
      .maybeSingle();
    const code = existing?.referral_code ?? (await mintCode(supabase, app.full_name));
    const now = new Date().toISOString();

    await supabase.from("influencers").upsert({
      user_id: app.user_id,
      referral_code: code,
      status: "active",
      tiktok_url: app.tiktok_url,
      instagram_url: app.instagram_url,
      youtube_url: app.youtube_url,
      followers_count: app.followers_count,
      content_niche: app.content_niche,
      audience_location: app.audience_location,
      activated_at: now,
    });

    await supabase.from("referral_links").upsert(
      {
        influencer_id: app.user_id,
        code,
        is_active: true,
      },
      { onConflict: "code", ignoreDuplicates: true },
    );

    await supabase.from("users").update({ role: "influencer" }).eq("id", app.user_id);

    // Ensure a wallet row exists (keep existing balances if present).
    await supabase
      .from("wallets")
      .upsert({ user_id: app.user_id }, { onConflict: "user_id", ignoreDuplicates: true });

    await supabase
      .from("influencer_applications")
      .update({
        status: "approved",
        reviewed_by: adminId === "secret" ? null : adminId,
        reviewed_at: now,
      })
      .eq("id", application_id);

    await supabase.from("notifications").insert({
      user_id: app.user_id,
      type: "system",
      title: "Influencer application approved",
      body: `Karibu! Your referral code is ${code}. Share it to start earning commissions.`,
    });

    await supabase.from("admin_logs").insert({
      admin_id: adminId === "secret" ? null : adminId,
      action: "approve_influencer",
      target_table: "influencers",
      target_id: app.user_id,
      details: { application_id, referral_code: code },
    });

    return new Response(JSON.stringify({ ok: true, referral_code: code }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("generate-referral-code error:", err);
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
