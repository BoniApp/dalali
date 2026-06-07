import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  // Verify cron secret if configured
  const cronSecret = Deno.env.get("CRON_SECRET");
  const authHeader = req.headers.get("Authorization");
  if (cronSecret && authHeader !== `Bearer ${cronSecret}`) {
    return new Response("Unauthorized", { status: 401 });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Get settlement delay
    const { data: settings } = await supabase
      .from("system_settings")
      .select("settlement_delay_hours")
      .eq("id", "default")
      .maybeSingle();

    const delayHours = settings?.settlement_delay_hours || 48;
    const cutoff = new Date(Date.now() - delayHours * 60 * 60 * 1000).toISOString();

    // Find transactions ready to settle
    const { data: txs } = await supabase
      .from("transactions")
      .select("*")
      .eq("status", "processing")
      .lte("processed_at", cutoff)
      .limit(100);

    if (!txs || txs.length === 0) {
      return new Response(JSON.stringify({ settled: 0 }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    let settled = 0;
    for (const tx of txs) {
      const split = tx.split || {};
      const agentShare = split.agent || 0;
      const platformShare = split.platform || 0;

      // Move agent's pending to available
      if (tx.payee_id && agentShare > 0) {
        const { data: wallet } = await supabase
          .from("wallets")
          .select("*")
          .eq("user_id", tx.payee_id)
          .maybeSingle();

        if (wallet) {
          await supabase.from("wallets").update({
            pending_balance: Math.max(0, wallet.pending_balance - agentShare),
            available_balance: wallet.available_balance + agentShare,
            updated_at: new Date().toISOString(),
          }).eq("user_id", tx.payee_id);
        }
      }

      // Move platform's pending to available
      if (platformShare > 0) {
        const { data: wallet } = await supabase
          .from("wallets")
          .select("*")
          .eq("user_id", "_platform")
          .maybeSingle();

        if (wallet) {
          await supabase.from("wallets").update({
            pending_balance: Math.max(0, wallet.pending_balance - platformShare),
            available_balance: wallet.available_balance + platformShare,
            updated_at: new Date().toISOString(),
          }).eq("user_id", "_platform");
        } else {
          await supabase.from("wallets").insert({
            user_id: "_platform",
            available_balance: platformShare,
          });
        }
      }

      // Mark transaction as available
      await supabase.from("transactions").update({
        status: "available",
        settled_at: new Date().toISOString(),
      }).eq("id", tx.id);

      settled++;
    }

    return new Response(JSON.stringify({ settled }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("Settlement error:", err);
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
