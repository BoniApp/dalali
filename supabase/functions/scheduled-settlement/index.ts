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

    let settled = 0;
    for (const tx of txs || []) {
      const split = tx.split || {};
      const agentShare = split.agent || 0;
      const platformShare = split.platform || 0;

      // Move agent's pending to available (atomic — migration 027's
      // wallet_settle_pending, replacing a read-then-write race).
      if (tx.payee_id && agentShare > 0) {
        const { error } = await supabase.rpc("wallet_settle_pending", {
          p_user_id: tx.payee_id,
          p_amount: agentShare,
        });
        if (error) console.error(`wallet_settle_pending failed for ${tx.payee_id}:`, error);
      }

      // Move platform's pending to available. Previously written against
      // a "_platform" sentinel row in `wallets`, whose user_id column is
      // uuid + FK'd to users(id) — every insert/update against that
      // string silently failed, so the platform's revenue share was
      // never actually landing anywhere. platform_wallet (migration 027)
      // is a real, dedicated singleton table for this.
      if (platformShare > 0) {
        const { error } = await supabase.rpc("platform_wallet_settle_pending", {
          p_amount: platformShare,
        });
        if (error) console.error("platform_wallet_settle_pending failed:", error);
      }

      // Mark transaction as available
      await supabase.from("transactions").update({
        status: "available",
        settled_at: new Date().toISOString(),
      }).eq("id", tx.id);

      settled++;
    }

    // ─── Referral commission settlement ─────────────────────
    // Move aged referralCommission earnings pending → available
    // and mark the matching conversions as paid.
    let referralSettled = 0;
    const { data: pendingEarnings } = await supabase
      .from("earnings")
      .select("*")
      .eq("type", "referralCommission")
      .eq("status", "pending")
      .lte("created_at", cutoff)
      .limit(100);

    for (const entry of pendingEarnings || []) {
      const { error } = await supabase.rpc("wallet_settle_pending", {
        p_user_id: entry.user_id,
        p_amount: Number(entry.amount),
      });
      if (error) {
        console.error(`wallet_settle_pending failed for earnings entry ${entry.entry_id}:`, error);
        continue;
      }

      await supabase.from("earnings").update({
        status: "available",
        available_at: new Date().toISOString(),
      }).eq("entry_id", entry.entry_id);

      await supabase.from("referral_conversions").update({
        status: "paid",
      }).eq("earnings_entry_id", entry.entry_id);

      referralSettled++;
    }

    return new Response(JSON.stringify({ settled, referralSettled }), {
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
