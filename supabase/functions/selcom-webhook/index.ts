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

    const event = await req.json();
    const eventType = event.event_type || event.event || "";
    const orderId = event.order_id || event.payout_id || "";
    const status = event.status || "";

    console.log(`Webhook: ${eventType} for ${orderId}`);

    // Idempotency check
    const { data: processed } = await supabase
      .from("webhook_processed")
      .select("order_id")
      .eq("order_id", `${orderId}_${status}`)
      .maybeSingle();

    if (processed) {
      return new Response(JSON.stringify({ ok: true, note: "already processed" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    await supabase.from("webhook_processed").insert({
      order_id: `${orderId}_${status}`,
      status,
      event_type: eventType,
    });

    // Handle payment success
    if (eventType === "order.payment_success" || status === "completed") {
      await handlePaymentSuccess(supabase, event);
    }

    // Handle payout success
    if (eventType === "payout.completed" || eventType === "payout.success") {
      await handlePayoutSuccess(supabase, event);
    }

    // Handle failures
    if (status === "failed" || status === "cancelled") {
      await handleFailure(supabase, event);
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("Webhook error:", err);
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

async function handlePaymentSuccess(supabase: any, event: any) {
  const orderId = event.order_id;
  const selcomTxId = event.transaction_id || event.id;

  // Find pending transaction
  const { data: tx } = await supabase
    .from("transactions")
    .select("*")
    .eq("idempotency_key", orderId)
    .eq("status", "pending")
    .maybeSingle();

  if (!tx) {
    console.warn(`No pending transaction for ${orderId}`);
    return;
  }

  const agentShare = tx.amount * 0.60;
  const platformShare = tx.amount * 0.40;

  // Update transaction
  await supabase
    .from("transactions")
    .update({
      status: "processing",
      selcom_transaction_id: selcomTxId,
      processed_at: new Date().toISOString(),
      split: { agent: agentShare, platform: platformShare },
    })
    .eq("id", tx.id);

  // Credit agent's pending balance
  if (tx.payee_id) {
    await creditWallet(supabase, tx.payee_id, "pending_balance", agentShare, "total_earned");
  }

  // Credit platform
  await creditWallet(supabase, "_platform", "pending_balance", platformShare, "total_earned");

  console.log(`Payment processed: ${orderId}`);
}

async function handlePayoutSuccess(supabase: any, event: any) {
  const payoutId = event.payout_id;

  const { data: wd } = await supabase
    .from("withdrawals")
    .select("*")
    .eq("selcom_payout_id", payoutId)
    .maybeSingle();

  if (!wd) return;

  await supabase
    .from("withdrawals")
    .update({ status: "completed", processed_at: new Date().toISOString() })
    .eq("id", wd.id);

  await debitWallet(supabase, wd.user_id, "available_balance", wd.amount);
  await incrementWallet(supabase, wd.user_id, "total_withdrawn", wd.amount);

  console.log(`Payout completed: ${payoutId}`);
}

async function handleFailure(supabase: any, event: any) {
  const orderId = event.order_id;
  await supabase
    .from("transactions")
    .update({
      status: "failed",
      failure_reason: event.message || event.error || "Payment failed",
      processed_at: new Date().toISOString(),
    })
    .eq("idempotency_key", orderId);
}

async function creditWallet(supabase: any, userId: string, balanceField: string, amount: number, earnedField?: string) {
  const { data: wallet } = await supabase.from("wallets").select("*").eq("user_id", userId).maybeSingle();
  if (!wallet) {
    await supabase.from("wallets").insert({
      user_id: userId,
      [balanceField]: amount,
      ...(earnedField ? { [earnedField]: amount } : {}),
    });
  } else {
    await supabase.from("wallets").update({
      [balanceField]: (wallet[balanceField] || 0) + amount,
      ...(earnedField ? { [earnedField]: (wallet[earnedField] || 0) + amount } : {}),
      updated_at: new Date().toISOString(),
    }).eq("user_id", userId);
  }
}

async function debitWallet(supabase: any, userId: string, balanceField: string, amount: number) {
  const { data: wallet } = await supabase.from("wallets").select("*").eq("user_id", userId).maybeSingle();
  if (!wallet) return;
  await supabase.from("wallets").update({
    [balanceField]: Math.max(0, (wallet[balanceField] || 0) - amount),
    updated_at: new Date().toISOString(),
  }).eq("user_id", userId);
}

async function incrementWallet(supabase: any, userId: string, field: string, amount: number) {
  const { data: wallet } = await supabase.from("wallets").select("*").eq("user_id", userId).maybeSingle();
  if (!wallet) return;
  await supabase.from("wallets").update({
    [field]: (wallet[field] || 0) + amount,
    updated_at: new Date().toISOString(),
  }).eq("user_id", userId);
}
