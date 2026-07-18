// ═══════════════════════════════════════════════════════════════
// Influencer commission engine (shared)
// Pure rate math + the server-side attribution/crediting routine.
// Used by calculate-influencer-commission and verify-referral-payment.
// Money lands in `wallets` (003 schema); ledger row in `earnings`
// with type 'referralCommission'; attribution in referral_clicks.
// ═══════════════════════════════════════════════════════════════

export interface InfluencerSettings {
  influencer_agency_fee_pct: number;
  influencer_premium_pct: number;
  influencer_registration_bonus: number;
  influencer_program_enabled: boolean;
}

export const DEFAULT_SETTINGS: InfluencerSettings = {
  influencer_agency_fee_pct: 0.10,
  influencer_premium_pct: 0.20,
  influencer_registration_bonus: 0,
  influencer_program_enabled: true,
};

export function round2(v: number): number {
  return Math.round(v * 100) / 100;
}

// Agency fee payments (seeker referral) use the agency-fee rate; other
// payment types (e.g. premium listings) use the premium rate. Purely
// internal movements never earn commission.
export function computeCommission(
  amount: number,
  txType: string,
  settings: InfluencerSettings
): number {
  if (amount <= 0) return 0;
  switch (txType) {
    case "agencyFee":
      return round2(amount * settings.influencer_agency_fee_pct);
    case "withdrawal":
    case "refund":
    case "adminAdjustment":
      return 0;
    default:
      return round2(amount * settings.influencer_premium_pct);
  }
}

export function conversionTypeFor(txType: string): string {
  return txType === "agencyFee" ? "agency_fee_payment" : "premium_payment";
}

export interface CreditDecision {
  credit: boolean;
  reason: string;
}

export function decideCredit(input: {
  programEnabled: boolean;
  influencerStatus: string;
  influencerUserId: string;
  payerUserId: string;
  commission: number;
}): CreditDecision {
  if (!input.programEnabled) return { credit: false, reason: "program_disabled" };
  if (input.influencerUserId === input.payerUserId)
    return { credit: false, reason: "self_referral" };
  if (input.influencerStatus !== "active")
    return { credit: false, reason: `influencer_${input.influencerStatus}` };
  if (input.commission <= 0) return { credit: false, reason: "zero_commission" };
  return { credit: true, reason: "ok" };
}

// deno-lint-ignore no-explicit-any
export async function loadSettings(supabase: any): Promise<InfluencerSettings> {
  const { data } = await supabase
    .from("system_settings")
    .select(
      "influencer_agency_fee_pct, influencer_premium_pct, influencer_registration_bonus, influencer_program_enabled"
    )
    .eq("id", "default")
    .maybeSingle();
  return { ...DEFAULT_SETTINGS, ...(data ?? {}) };
}

// deno-lint-ignore no-explicit-any
export async function logFraud(
  supabase: any,
  entry: {
    influencer_id?: string | null;
    referred_user_id?: string | null;
    reason: string;
    severity?: string;
    metadata?: Record<string, unknown>;
  }
): Promise<void> {
  await supabase.from("fraud_logs").insert({
    influencer_id: entry.influencer_id ?? null,
    referred_user_id: entry.referred_user_id ?? null,
    reason: entry.reason,
    severity: entry.severity ?? "low",
    metadata: entry.metadata ?? {},
  });
}

// deno-lint-ignore no-explicit-any
async function creditWallet(supabase: any, userId: string, amount: number): Promise<void> {
  const { data: wallet } = await supabase
    .from("wallets")
    .select("*")
    .eq("user_id", userId)
    .maybeSingle();
  if (!wallet) {
    await supabase.from("wallets").insert({
      user_id: userId,
      pending_balance: amount,
      total_earned: amount,
    });
  } else {
    await supabase
      .from("wallets")
      .update({
        pending_balance: Number(wallet.pending_balance || 0) + amount,
        total_earned: Number(wallet.total_earned || 0) + amount,
        updated_at: new Date().toISOString(),
      })
      .eq("user_id", userId);
  }
}

export interface CreditResult {
  credited: boolean;
  reason: string;
  commission?: number;
  conversion_id?: string;
}

// Attributes a successful transaction to an influencer (first-touch via
// referral_clicks) and credits commission. Idempotent: the unique index
// on (referred_user_id, conversion_type) blocks double-crediting.
// deno-lint-ignore no-explicit-any
export async function attributeAndCredit(supabase: any, txn: any): Promise<CreditResult> {
  if (!txn?.payer_id) return { credited: false, reason: "no_payer" };

  const settings = await loadSettings(supabase);

  const { data: click } = await supabase
    .from("referral_clicks")
    .select("*")
    .eq("referred_user_id", txn.payer_id)
    .order("created_at", { ascending: true })
    .limit(1)
    .maybeSingle();
  if (!click) return { credited: false, reason: "no_attribution" };

  let influencerId: string | null = null;
  if (click.link_id) {
    const { data: link } = await supabase
      .from("referral_links")
      .select("influencer_id")
      .eq("id", click.link_id)
      .maybeSingle();
    influencerId = link?.influencer_id ?? null;
  }
  if (!influencerId) return { credited: false, reason: "link_missing" };

  const { data: influencer } = await supabase
    .from("influencers")
    .select("*")
    .eq("user_id", influencerId)
    .maybeSingle();
  if (!influencer) return { credited: false, reason: "influencer_missing" };

  const conversionType = conversionTypeFor(txn.type);
  const commission = computeCommission(Number(txn.amount), txn.type, settings);
  const decision = decideCredit({
    programEnabled: settings.influencer_program_enabled,
    influencerStatus: influencer.status,
    influencerUserId: influencerId,
    payerUserId: txn.payer_id,
    commission,
  });

  if (!decision.credit) {
    if (decision.reason === "self_referral" || decision.reason === "influencer_suspended") {
      await logFraud(supabase, {
        influencer_id: influencerId,
        referred_user_id: txn.payer_id,
        reason: decision.reason,
        severity: decision.reason === "self_referral" ? "high" : "medium",
        metadata: { transaction_id: txn.id, amount: txn.amount },
      });
    }
    return { credited: false, reason: decision.reason };
  }

  const { data: conv, error: convErr } = await supabase
    .from("referral_conversions")
    .insert({
      influencer_id: influencerId,
      link_id: click.link_id,
      referred_user_id: txn.payer_id,
      transaction_id: txn.id,
      conversion_type: conversionType,
      commission_amount: commission,
      status: "approved",
    })
    .select()
    .single();

  if (convErr) {
    if (convErr.code === "23505") return { credited: false, reason: "duplicate" };
    throw convErr;
  }

  const { data: earningsRow } = await supabase
    .from("earnings")
    .insert({
      user_id: influencerId,
      property_id: txn.property_id ?? null,
      property_title: txn.property_title ?? null,
      type: "referralCommission",
      status: "pending",
      amount: commission,
      currency: "TZS",
    })
    .select()
    .single();

  if (earningsRow) {
    await supabase
      .from("referral_conversions")
      .update({ earnings_entry_id: earningsRow.entry_id })
      .eq("id", conv.id);
  }

  await creditWallet(supabase, influencerId, commission);

  await supabase
    .from("influencers")
    .update({
      total_conversions: Number(influencer.total_conversions || 0) + 1,
      total_earnings: Number(influencer.total_earnings || 0) + commission,
    })
    .eq("user_id", influencerId);

  return { credited: true, reason: "ok", commission, conversion_id: conv.id };
}
