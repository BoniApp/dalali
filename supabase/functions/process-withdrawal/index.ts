import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const { withdrawal_id } = await req.json();
    if (!withdrawal_id) {
      return new Response(JSON.stringify({ error: "withdrawal_id required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Get withdrawal
    const { data: wd } = await supabase
      .from("withdrawals")
      .select("*")
      .eq("id", withdrawal_id)
      .eq("status", "pending")
      .maybeSingle();

    if (!wd) {
      return new Response(JSON.stringify({ error: "Withdrawal not found or not pending" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Get wallet
    const { data: wallet } = await supabase
      .from("wallets")
      .select("*")
      .eq("user_id", wd.user_id)
      .maybeSingle();

    if (!wallet || wallet.available_balance < wd.amount) {
      await supabase.from("withdrawals").update({
        status: "failed",
        failure_reason: "Insufficient balance",
      }).eq("id", withdrawal_id);
      return new Response(JSON.stringify({ error: "Insufficient balance" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Get min withdrawal from settings
    const { data: settings } = await supabase
      .from("system_settings")
      .select("min_withdrawal")
      .eq("id", "default")
      .maybeSingle();

    const minWithdrawal = settings?.min_withdrawal || 5000;
    if (wd.amount < minWithdrawal) {
      await supabase.from("withdrawals").update({
        status: "failed",
        failure_reason: `Minimum withdrawal is ${minWithdrawal}`,
      }).eq("id", withdrawal_id);
      return new Response(JSON.stringify({ error: `Minimum withdrawal is ${minWithdrawal}` }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Lock funds
    const payoutId = `PAYOUT_${withdrawal_id}`;
    await supabase.from("wallets").update({
      available_balance: wallet.available_balance - wd.amount,
      locked_balance: wallet.locked_balance + wd.amount,
      updated_at: new Date().toISOString(),
    }).eq("user_id", wd.user_id);

    await supabase.from("withdrawals").update({
      status: "processing",
      selcom_payout_id: payoutId,
    }).eq("id", withdrawal_id);

    // In production, call Selcom API here
    // For now, the webhook will complete the payout

    return new Response(JSON.stringify({ ok: true, payout_id: payoutId }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("Process withdrawal error:", err);
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
