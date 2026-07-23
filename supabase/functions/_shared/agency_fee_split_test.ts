import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import {
  AGENT_FEE_SHARE_PCT,
  computeAgencyFeeSplit,
  creatorEarnsFee,
} from "./agency_fee_split.ts";

Deno.test("creatorEarnsFee: agents and seekers earn, landlords don't", () => {
  assertEquals(creatorEarnsFee("agent"), true);
  assertEquals(creatorEarnsFee("seeker"), true);
  assertEquals(creatorEarnsFee("landlord"), false);
  assertEquals(creatorEarnsFee("influencer"), false);
  assertEquals(creatorEarnsFee(null), false);
  assertEquals(creatorEarnsFee(undefined), false);
});

Deno.test("split: agent payee gets 60%, platform 40%", () => {
  const { payeeShare, platformShare } = computeAgencyFeeSplit(20000, "agent");
  assertEquals(payeeShare, 20000 * AGENT_FEE_SHARE_PCT);
  assertEquals(platformShare, 20000 * (1 - AGENT_FEE_SHARE_PCT));
  assertEquals(payeeShare + platformShare, 20000);
});

Deno.test("split: seeker payee earns like an agent", () => {
  const { payeeShare, platformShare } = computeAgencyFeeSplit(20000, "seeker");
  assertEquals(payeeShare, 20000 * AGENT_FEE_SHARE_PCT);
  assertEquals(platformShare, 20000 * (1 - AGENT_FEE_SHARE_PCT));
});

Deno.test("split: landlord payee gets 0%, platform keeps 100%", () => {
  const { payeeShare, platformShare } = computeAgencyFeeSplit(20000, "landlord");
  assertEquals(payeeShare, 0);
  assertEquals(platformShare, 20000);
});

Deno.test("split: unknown/missing role is platform-only", () => {
  for (const role of [null, undefined, "influencer", "admin"]) {
    const { payeeShare, platformShare } = computeAgencyFeeSplit(20000, role);
    assertEquals(payeeShare, 0);
    assertEquals(platformShare, 20000);
  }
});
