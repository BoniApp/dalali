import { assertEquals } from "https://deno.land/std@0.201.0/testing/asserts.ts";
import {
  computeCommission,
  conversionTypeFor,
  decideCredit,
  DEFAULT_SETTINGS,
} from "./influencer_commission.ts";

Deno.test("computeCommission: agency fee 10% of 20,000 = 2,000", () => {
  assertEquals(computeCommission(20000, "agencyFee", DEFAULT_SETTINGS), 2000);
});

Deno.test("computeCommission: premium 20% of 50,000 = 10,000", () => {
  assertEquals(computeCommission(50000, "revenueShare", DEFAULT_SETTINGS), 10000);
});

Deno.test("computeCommission: internal movements earn nothing", () => {
  assertEquals(computeCommission(20000, "withdrawal", DEFAULT_SETTINGS), 0);
  assertEquals(computeCommission(20000, "refund", DEFAULT_SETTINGS), 0);
  assertEquals(computeCommission(20000, "adminAdjustment", DEFAULT_SETTINGS), 0);
  assertEquals(computeCommission(0, "agencyFee", DEFAULT_SETTINGS), 0);
  assertEquals(computeCommission(-5000, "agencyFee", DEFAULT_SETTINGS), 0);
});

Deno.test("conversionTypeFor maps transaction types", () => {
  assertEquals(conversionTypeFor("agencyFee"), "agency_fee_payment");
  assertEquals(conversionTypeFor("revenueShare"), "premium_payment");
});

Deno.test("decideCredit blocks self-referral", () => {
  const d = decideCredit({
    programEnabled: true,
    influencerStatus: "active",
    influencerUserId: "u1",
    payerUserId: "u1",
    commission: 2000,
  });
  assertEquals(d, { credit: false, reason: "self_referral" });
});

Deno.test("decideCredit blocks disabled program and non-active influencers", () => {
  assertEquals(
    decideCredit({
      programEnabled: false,
      influencerStatus: "active",
      influencerUserId: "u1",
      payerUserId: "u2",
      commission: 2000,
    }).reason,
    "program_disabled"
  );
  assertEquals(
    decideCredit({
      programEnabled: true,
      influencerStatus: "suspended",
      influencerUserId: "u1",
      payerUserId: "u2",
      commission: 2000,
    }).reason,
    "influencer_suspended"
  );
  assertEquals(
    decideCredit({
      programEnabled: true,
      influencerStatus: "active",
      influencerUserId: "u1",
      payerUserId: "u2",
      commission: 0,
    }).reason,
    "zero_commission"
  );
});

Deno.test("decideCredit allows a valid conversion", () => {
  const d = decideCredit({
    programEnabled: true,
    influencerStatus: "active",
    influencerUserId: "u1",
    payerUserId: "u2",
    commission: 2000,
  });
  assertEquals(d, { credit: true, reason: "ok" });
});
