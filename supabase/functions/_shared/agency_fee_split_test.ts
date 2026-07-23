import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import {
  AGENT_FEE_SHARE_PCT,
  computeAgencyFeeSplit,
  creatorEarnsFee,
} from "./agency_fee_split.ts";

Deno.test("creatorEarnsFee: only agents earn", () => {
  assertEquals(creatorEarnsFee("agent"), true);
  assertEquals(creatorEarnsFee("landlord"), false);
  assertEquals(creatorEarnsFee("seeker"), false);
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

Deno.test("split: landlord payee gets 0%, platform keeps 100%", () => {
  const { payeeShare, platformShare } = computeAgencyFeeSplit(20000, "landlord");
  assertEquals(payeeShare, 0);
  assertEquals(platformShare, 20000);
});

Deno.test("split: unknown/missing role is platform-only", () => {
  for (const role of [null, undefined, "seeker", "admin"]) {
    const { payeeShare, platformShare } = computeAgencyFeeSplit(20000, role);
    assertEquals(payeeShare, 0);
    assertEquals(platformShare, 20000);
  }
});
