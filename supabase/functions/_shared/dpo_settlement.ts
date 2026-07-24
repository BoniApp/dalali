// ═══════════════════════════════════════════════════════════════
// DPO settlement (shared)
//
// Single verify-and-settle routine used by verify-dpo-payment (app
// poll) and dpo-callback (browser redirect). VerifyToken → on '000':
// mark the payment paid, unlock property_access, write the
// `transactions` ledger row and apply the agency-fee split
// (_shared/agency_fee_split.ts), credit the influencer commission
// (_shared/influencer_commission.ts), and notify all parties.
// Idempotent: an already-paid payment replays as 'already_paid'.
// ═══════════════════════════════════════════════════════════════

import { computeAgencyFeeSplit } from "./agency_fee_split.ts";
import { attributeAndCredit } from "./influencer_commission.ts";
import {
  buildVerifyTokenXml,
  DPO_API_BASE,
  parseVerifyTokenResponse,
  statusFromResult,
  type VerifyTokenResult,
} from "./dpo.ts";

export type XmlPoster = (url: string, xml: string) => Promise<string>;

export const defaultPoster: XmlPoster = async (url, xml) => {
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/xml" },
    body: xml,
  });
  return await res.text();
};

export interface SettlementOutcome {
  status: "paid" | "pending" | "failed";
  payment: Record<string, unknown>;
  verify: VerifyTokenResult | null;
  note?: string;
}

async function creditWallet(
  supabase: any,
  userId: string,
  balanceField: string,
  amount: number,
  earnedField?: string,
) {
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

async function notify(_supabase: any, userId: string, title: string, body: string, targetId?: string) {
  // Route through send-notification: it inserts the in-app row AND
  // pushes via FCM. Fire-and-forget semantics stay with the caller's
  // try/catch — notification failure must never fail settlement.
  const fnBase = Deno.env.get("SUPABASE_URL")!.replace(".supabase.co", ".functions.supabase.co");
  await fetch(`${fnBase}/send-notification`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-admin-secret": Deno.env.get("ADMIN_API_SECRET") ?? "",
    },
    body: JSON.stringify({
      user_id: userId,
      title,
      body,
      type: "paymentReceived",
      target_collection: "payments",
      target_id: targetId ?? null,
    }),
  });
}

export async function verifyAndSettle(
  supabase: any,
  payment: any,
  opts: { companyToken: string; apiBase?: string; poster?: XmlPoster },
): Promise<SettlementOutcome> {
  // Idempotent replay: DPO callback and app poll can race.
  if (payment.status === "paid") {
    return { status: "paid", payment, verify: null, note: "already_paid" };
  }

  const xml = buildVerifyTokenXml(opts.companyToken, payment.dpo_token);
  const body = await (opts.poster ?? defaultPoster)(opts.apiBase ?? DPO_API_BASE, xml);
  const verify = parseVerifyTokenResponse(body);
  const status = statusFromResult(verify.result);
  const now = new Date().toISOString();

  if (status !== "paid") {
    await supabase.from("payments").update({ status }).eq("id", payment.id);
    return { status, payment: { ...payment, status }, verify };
  }

  // ─── 1. Mark paid ────────────────────────────────────────────
  await supabase.from("payments").update({
    status: "paid",
    paid_at: now,
    dpo_transaction_id: verify.transactionId,
    payment_method: verify.paymentMethod,
  }).eq("id", payment.id);

  // ─── 2. Unlock contact access ────────────────────────────────
  await supabase.from("property_access").upsert({
    property_id: payment.property_id,
    tenant_id: payment.tenant_id,
    payment_id: payment.id,
    paid: true,
  }, { onConflict: "property_id,tenant_id" });

  // ─── 3. Ledger + wallet split (creator vs platform rule) ─────
  const { data: creator } = payment.agent_id
    ? await supabase.from("users").select("role").eq("id", payment.agent_id).maybeSingle()
    : { data: null };
  const { payeeShare, platformShare } = computeAgencyFeeSplit(payment.amount, creator?.role ?? null);

  const { data: prop } = await supabase
    .from("properties").select("title").eq("id", payment.property_id).maybeSingle();
  const propertyTitle = prop?.title ?? "";

  const { data: txn } = await supabase.from("transactions").insert({
    type: "agencyFee",
    status: "processing",
    amount: payment.amount,
    currency: payment.currency,
    payer_id: payment.tenant_id,
    payee_id: payment.agent_id,
    property_id: payment.property_id,
    property_title: propertyTitle,
    payment_method: "dpo",
    idempotency_key: verify.transactionId ?? `dpo_${payment.id}`,
    split: { agent: payeeShare, platform: platformShare },
    processed_at: now,
  }).select().single();

  if (txn) {
    if (payment.agent_id && payeeShare > 0) {
      await creditWallet(supabase, payment.agent_id, "pending_balance", payeeShare, "total_earned");
    }
    await creditWallet(supabase, "_platform", "pending_balance", platformShare, "total_earned");

    // ─── 4. Influencer commission (best-effort — never fails settlement)
    try {
      await attributeAndCredit(supabase, txn);
    } catch (e) {
      console.error("Influencer commission failed:", e);
    }
  }

  // ─── 5. Notifications ────────────────────────────────────────
  const amount = `${payment.amount} ${payment.currency}`;
  try {
    await notify(
      supabase,
      payment.tenant_id,
      "Payment received",
      `Your agency fee of ${amount} for "${propertyTitle}" was received. Receipt ${payment.receipt_number}.`,
      payment.id,
    );
    if (payment.landlord_id && payment.landlord_id !== payment.agent_id) {
      await notify(
        supabase,
        payment.landlord_id,
        "Agency fee paid",
        `The agency fee for your listing "${propertyTitle}" has been paid.`,
        payment.id,
      );
    }
    if (payment.agent_id && payeeShare > 0) {
      await notify(
        supabase,
        payment.agent_id,
        "Commission earned",
        `You earned ${payeeShare} ${payment.currency} commission for "${propertyTitle}".`,
        payment.id,
      );
    }
    const { data: admins } = await supabase.from("users").select("id").eq("is_admin", true);
    for (const admin of admins ?? []) {
      await notify(
        supabase,
        admin.id,
        "Agency fee payment",
        `${amount} paid for "${propertyTitle}" (receipt ${payment.receipt_number}).`,
        payment.id,
      );
    }
  } catch (e) {
    console.error("Payment notifications failed:", e);
  }

  return {
    status: "paid",
    payment: {
      ...payment,
      status: "paid",
      paid_at: now,
      dpo_transaction_id: verify.transactionId,
      payment_method: verify.paymentMethod,
    },
    verify,
  };
}
