import { assert, assertEquals, assertStringIncludes } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import {
  buildCreateTokenXml,
  buildVerifyTokenXml,
  dpoServiceDate,
  parseCreateTokenResponse,
  parseVerifyTokenResponse,
  statusFromResult,
} from "./dpo.ts";

const input = {
  companyToken: "B3F59BE7-0756-420E-BB88-1D98E7A6B040",
  amount: 20000,
  currency: "TZS",
  companyRef: "pay-123",
  redirectUrl: "https://example.supabase.co/functions/v1/dpo-callback",
  backUrl: "https://dalaliapp.com/payment-back",
  serviceType: "85325",
  serviceDescription: "Dalali agency fee",
  serviceDate: "2026/07/23 12:00",
  customerPhone: "+255700000000",
};

Deno.test("buildCreateTokenXml carries all required DPO tags", () => {
  const xml = buildCreateTokenXml(input);
  for (const snippet of [
    "<Request>createToken</Request>",
    `<CompanyToken>${input.companyToken}</CompanyToken>`,
    "<PaymentAmount>20000</PaymentAmount>",
    "<PaymentCurrency>TZS</PaymentCurrency>",
    "<CompanyRef>pay-123</CompanyRef>",
    "<ServiceType>85325</ServiceType>",
    "<CustomerPhone>+255700000000</CustomerPhone>",
  ]) {
    assertStringIncludes(xml, snippet);
  }
});

Deno.test("buildCreateTokenXml escapes XML-unsafe values", () => {
  const xml = buildCreateTokenXml({ ...input, serviceDescription: 'Fee "A" <B> & Co' });
  assertStringIncludes(xml, 'Fee &quot;A&quot; &lt;B&gt; &amp; Co');
  assert(!xml.includes('Fee "A" <B> & Co'));
});

Deno.test("parseCreateTokenResponse: success", () => {
  const r = parseCreateTokenResponse(
    `<API3G><Result>000</Result><ResultExplanation>Success</ResultExplanation><TransToken>TT-1</TransToken><TransRef>TR-1</TransRef></API3G>`,
  );
  assertEquals(r.ok, true);
  assertEquals(r.transToken, "TT-1");
  assertEquals(r.transRef, "TR-1");
});

Deno.test("parseCreateTokenResponse: failure has no token", () => {
  const r = parseCreateTokenResponse(
    `<API3G><Result>801</Result><ResultExplanation>Invalid company token</ResultExplanation></API3G>`,
  );
  assertEquals(r.ok, false);
  assertEquals(r.transToken, null);
  assertEquals(r.result, "801");
});

Deno.test("buildVerifyTokenXml is minimal and complete", () => {
  const xml = buildVerifyTokenXml("CT", "TT-9");
  assertStringIncludes(xml, "<Request>verifyToken</Request>");
  assertStringIncludes(xml, "<CompanyToken>CT</CompanyToken>");
  assertStringIncludes(xml, "<TransactionToken>TT-9</TransactionToken>");
});

Deno.test("parseVerifyTokenResponse: paid fixture", () => {
  const r = parseVerifyTokenResponse(
    `<API3G><Result>000</Result><ResultExplanation>Transaction Paid</ResultExplanation><TransactionRef>DP123</TransactionRef><TransactionAmount>20000</TransactionAmount><TransactionCurrency>TZS</TransactionCurrency><TransactionPaymentMethod>MPESA</TransactionPaymentMethod></API3G>`,
  );
  assertEquals(statusFromResult(r.result), "paid");
  assertEquals(r.transactionId, "DP123");
  assertEquals(r.amount, 20000);
  assertEquals(r.paymentMethod, "MPESA");
});

Deno.test("statusFromResult maps DPO codes", () => {
  assertEquals(statusFromResult("000"), "paid");
  assertEquals(statusFromResult("001"), "pending");
  assertEquals(statusFromResult("9999"), "pending");
  assertEquals(statusFromResult("801"), "failed");
  assertEquals(statusFromResult(""), "failed");
});

Deno.test("dpoServiceDate formats yyyy/mm/dd hh:mm UTC", () => {
  assertEquals(dpoServiceDate(new Date("2026-07-23T09:15:23Z")), "2026/07/23 09:15");
});
