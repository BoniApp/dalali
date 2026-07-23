// ═══════════════════════════════════════════════════════════════
// Agency-fee split rule (shared)
//
// The fixed 20,000 TZS agency fee is the listing commission: agents
// earn 60% for the listings they source; landlords list for FREE, so
// a landlord-sourced listing earns them nothing — the platform keeps
// 100%. Used by selcom-webhook (wallet split) and confirm-tenancy-deal
// (payout/earnings ledger rows).
// ═══════════════════════════════════════════════════════════════

export const AGENT_FEE_SHARE_PCT = 0.6;

export interface AgencyFeeSplit {
  payeeShare: number;
  platformShare: number;
}

/// Only agent-sourced listings earn the creator a share of the fee.
export function creatorEarnsFee(role: string | null | undefined): boolean {
  return role === "agent";
}

/// Wallet split for a successful agency-fee payment.
export function computeAgencyFeeSplit(
  amount: number,
  payeeRole: string | null | undefined,
): AgencyFeeSplit {
  if (creatorEarnsFee(payeeRole)) {
    return {
      payeeShare: amount * AGENT_FEE_SHARE_PCT,
      platformShare: amount * (1 - AGENT_FEE_SHARE_PCT),
    };
  }
  return { payeeShare: 0, platformShare: amount };
}
