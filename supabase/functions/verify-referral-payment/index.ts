// ═══════════════════════════════════════════════════════════════
// verify-referral-payment
// Server-to-server ops/backfill endpoint: given a Selcom order_id,
// resolves the transaction, confirms the payment succeeded, and runs
// the shared commission routine (idempotent). Use it to re-process
// payments whose commission hook was missed.
// Auth: x-commission-secret == COMMISSION_SECRET (never client-facing).
// ═══════════════════════════════════════════════════════════════

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { attributeAndCredit } from "../_shared/influencer_commission.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-commission-secret",
};

const SUCCESS_STATUSES = ["processing", "available", "completed"];

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
    const secret = req.headers.get("x-commission-secret");
    const expected = Deno.env.get("COMMISSION_SECRET");
    if (!expected || secret !== expected) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const { order_id } = await req.json();
    if (!order_id) {
      return new Response(JSON.stringify({ error: "order_id required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: tx } = await supabase
      .from("transactions")
      .select("*")
      .eq("idempotency_key", order_id)
      .maybeSingle();
    if (!tx) {
      return new Response(JSON.stringify({ verified: false, reason: "not_found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    if (!SUCCESS_STATUSES.includes(tx.status)) {
      return new Response(
        JSON.stringify({ verified: false, reason: `status_${tx.status}` }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const result = await attributeAndCredit(supabase, tx);

    return new Response(JSON.stringify({ verified: true, ...result }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("verify-referral-payment error:", err);
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
