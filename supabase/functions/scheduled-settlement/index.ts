// ═══════════════════════════════════════════════════════════════
// SUPABASE EDGE FUNCTION: scheduled-settlement (pg_cron daily)
// ═══════════════════════════════════════════════════════════════
//
// Moves aged money from pending to available:
//   1. `transactions` rows in 'processing' older than the settlement
//      hold (system_settings.settlement_delay_hours, default 48h) —
//      agent share → wallets pending→available, platform share →
//      platform_wallet pending→available, row marked 'available'.
//   2. `earnings` referralCommission rows in 'pending' past the hold
//      — wallet pending→available, conversion marked 'paid'.
//
// Scheduled by migration 038 (pg_cron → invoke_edge_function) and
// gated on CRON_SECRET. Fail-closed: if CRON_SECRET is not set the
// function refuses to run — verify_jwt is off at the gateway
// (config.toml), so the shared secret is the only gate.
//
// Reliability: every run writes a settlement_log row (038) with the
// counts and any failures. Individual item failures are skipped and
// retried automatically on the next run (rows stay in their
// pending/processing state); any failure count > 0 fans out an
// admin notification so ops sees it the same day.
// ═══════════════════════════════════════════════════════════════

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  // ─── Auth: mandatory shared cron secret ──────────────────────
  const cronSecret = Deno.env.get("CRON_SECRET");
  if (!cronSecret) {
    console.error("scheduled-settlement: CRON_SECRET is not configured — refusing to run");
    return new Response(JSON.stringify({ error: "CRON_SECRET not configured" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
  if (req.headers.get("Authorization") !== `Bearer ${cronSecret}`) {
    return new Response("Unauthorized", { status: 401 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const failures: string[] = [];
  let settled = 0;
  let referralSettled = 0;

  try {
    // ─── Settlement hold ─────────────────────────────────────────
    const { data: settings } = await supabase
      .from("system_settings")
      .select("settlement_delay_hours")
      .eq("id", "default")
      .maybeSingle();

    const delayHours = settings?.settlement_delay_hours || 48;
    const cutoff = new Date(Date.now() - delayHours * 60 * 60 * 1000).toISOString();

    // ─── 1. Agency-fee transactions: processing → available ──────
    const { data: txs, error: txError } = await supabase
      .from("transactions")
      .select("*")
      .eq("status", "processing")
      .lte("processed_at", cutoff)
      .limit(100);
    if (txError) failures.push(`tx query: ${txError.message}`);

    for (const tx of txs || []) {
      try {
        const split = tx.split || {};
        const agentShare = split.agent || 0;
        const platformShare = split.platform || 0;

        // Atomic pending→available moves (migration 027 RPCs).
        if (tx.payee_id && agentShare > 0) {
          const { error } = await supabase.rpc("wallet_settle_pending", {
            p_user_id: tx.payee_id,
            p_amount: agentShare,
          });
          if (error) throw new Error(`wallet_settle_pending: ${error.message}`);
        }
        if (platformShare > 0) {
          const { error } = await supabase.rpc("platform_wallet_settle_pending", {
            p_amount: platformShare,
          });
          if (error) throw new Error(`platform_wallet_settle_pending: ${error.message}`);
        }

        const { error: markError } = await supabase.from("transactions").update({
          status: "available",
          settled_at: new Date().toISOString(),
        }).eq("id", tx.id).eq("status", "processing");
        if (markError) throw new Error(`mark available: ${markError.message}`);

        settled++;
      } catch (e) {
        // Skip — the row stays 'processing' and is retried next run.
        failures.push(`tx ${tx.id}: ${(e as Error).message}`);
      }
    }

    // ─── 2. Referral commissions: pending → available ────────────
    const { data: pendingEarnings, error: earnError } = await supabase
      .from("earnings")
      .select("*")
      .eq("type", "referralCommission")
      .eq("status", "pending")
      .lte("created_at", cutoff)
      .limit(100);
    if (earnError) failures.push(`earnings query: ${earnError.message}`);

    for (const entry of pendingEarnings || []) {
      try {
        const { error } = await supabase.rpc("wallet_settle_pending", {
          p_user_id: entry.user_id,
          p_amount: Number(entry.amount),
        });
        if (error) throw new Error(`wallet_settle_pending: ${error.message}`);

        const { error: markError } = await supabase.from("earnings").update({
          status: "available",
          available_at: new Date().toISOString(),
        }).eq("entry_id", entry.entry_id).eq("status", "pending");
        if (markError) throw new Error(`mark earnings available: ${markError.message}`);

        await supabase.from("referral_conversions").update({
          status: "paid",
        }).eq("earnings_entry_id", entry.entry_id);

        referralSettled++;
      } catch (e) {
        failures.push(`earnings ${entry.entry_id}: ${(e as Error).message}`);
      }
    }

    // ─── 3. Run log ──────────────────────────────────────────────
    await supabase.from("settlement_log").insert({
      settled,
      referral_settled: referralSettled,
      failures: failures.length,
      details: { cutoff, delay_hours: delayHours, errors: failures.slice(0, 20) },
    });

    // ─── 4. Failure alerts → admin notifications ─────────────────
    if (failures.length > 0) {
      const { data: admins } = await supabase
        .from("users").select("id").eq("is_admin", true);
      for (const admin of admins ?? []) {
        await supabase.from("notifications").insert({
          user_id: admin.id,
          type: "system",
          title: "Settlement job reported failures",
          body: `${failures.length} item(s) failed in the latest settlement run (${settled} settled, ${referralSettled} referral). First error: ${failures[0]}`,
          target_collection: "settlement_log",
        });
      }
    }

    return new Response(
      JSON.stringify({ settled, referralSettled, failures: failures.length }),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("Settlement error:", err);
    await supabase.from("settlement_log").insert({
      settled,
      referral_settled: referralSettled,
      failures: failures.length + 1,
      details: { fatal: (err as Error).message, errors: failures.slice(0, 20) },
    });
    return new Response(JSON.stringify({ error: "Settlement run failed" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
