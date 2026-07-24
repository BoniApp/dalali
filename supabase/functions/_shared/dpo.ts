// ═══════════════════════════════════════════════════════════════
// DPO Pay API v6 (shared)
//
// Pure XML builders/parsers for DPO's CreateToken / VerifyToken
// calls plus the result-code mapping. All network I/O lives in the
// edge functions (create-dpo-token, verify-dpo-payment, dpo-callback)
// — the DPO company token must NEVER reach the client.
// ═══════════════════════════════════════════════════════════════

export const DPO_API_BASE = "https://secure.3gdirectpay.com/API/v6/";
export const DPO_PAY_PAGE = "https://secure.3gdirectpay.com/payv3.php?ID=";

export interface CreateTokenInput {
  companyToken: string;
  amount: number;
  currency: string;
  /// Our payments.id — echoed back by DPO on the callback.
  companyRef: string;
  redirectUrl: string;
  backUrl: string;
  serviceType: string;
  serviceDescription: string;
  serviceDate: string; // yyyy/mm/dd hh:mm
  customerPhone?: string;
  customerEmail?: string;
}

export interface CreateTokenResult {
  ok: boolean;
  transToken: string | null;
  transRef: string | null;
  result: string;
  explanation: string;
}

export interface VerifyTokenResult {
  result: string;
  explanation: string;
  transactionId: string | null;
  amount: number | null;
  currency: string | null;
  paymentMethod: string | null;
}

/// DPO result codes relevant to this integration.
export type DpoStatus = "paid" | "pending" | "failed";

export function statusFromResult(result: string): DpoStatus {
  if (result === "000") return "paid";
  if (result === "001" || result === "9999") return "pending"; // 9999 = not yet paid
  return "failed";
}

function esc(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function tag(xml: string, name: string): string | null {
  const m = xml.match(new RegExp(`<${name}>([\\s\\S]*?)</${name}>`));
  return m ? m[1].trim() : null;
}

export function buildCreateTokenXml(i: CreateTokenInput): string {
  const phone = i.customerPhone ? `<CustomerPhone>${esc(i.customerPhone)}</CustomerPhone>` : "";
  const email = i.customerEmail ? `<CustomerEmail>${esc(i.customerEmail)}</CustomerEmail>` : "";
  return `<?xml version="1.0" encoding="utf-8"?>
<API3G>
  <CompanyToken>${esc(i.companyToken)}</CompanyToken>
  <Request>createToken</Request>
  <Transaction>
    <PaymentAmount>${i.amount}</PaymentAmount>
    <PaymentCurrency>${esc(i.currency)}</PaymentCurrency>
    <CompanyRef>${esc(i.companyRef)}</CompanyRef>
    <RedirectURL>${esc(i.redirectUrl)}</RedirectURL>
    <BackURL>${esc(i.backUrl)}</BackURL>
    <CompanyRefUnique>0</CompanyRefUnique>
    <PTL>60</PTL>
    ${phone}
    ${email}
  </Transaction>
  <Services>
    <Service>
      <ServiceType>${esc(i.serviceType)}</ServiceType>
      <ServiceDescription>${esc(i.serviceDescription)}</ServiceDescription>
      <ServiceDate>${esc(i.serviceDate)}</ServiceDate>
    </Service>
  </Services>
</API3G>`;
}

export function buildVerifyTokenXml(companyToken: string, transactionToken: string): string {
  return `<?xml version="1.0" encoding="utf-8"?>
<API3G>
  <CompanyToken>${esc(companyToken)}</CompanyToken>
  <Request>verifyToken</Request>
  <TransactionToken>${esc(transactionToken)}</TransactionToken>
</API3G>`;
}

export function parseCreateTokenResponse(xml: string): CreateTokenResult {
  const result = tag(xml, "Result") ?? "";
  const explanation = tag(xml, "ResultExplanation") ?? "";
  const transToken = tag(xml, "TransToken");
  return {
    ok: result === "000" && !!transToken,
    transToken,
    transRef: tag(xml, "TransRef"),
    result,
    explanation,
  };
}

export function parseVerifyTokenResponse(xml: string): VerifyTokenResult {
  const amountRaw = tag(xml, "TransactionAmount");
  return {
    result: tag(xml, "Result") ?? "",
    explanation: tag(xml, "ResultExplanation") ?? "",
    transactionId: tag(xml, "TransactionRef") ?? tag(xml, "TransactionId"),
    amount: amountRaw != null ? Number(amountRaw) : null,
    currency: tag(xml, "TransactionCurrency"),
    paymentMethod: tag(xml, "TransactionPaymentMethod") ?? tag(xml, "PaymentMedium"),
  };
}

/// yyyy/mm/dd hh:mm in UTC — the ServiceDate format DPO expects.
export function dpoServiceDate(d = new Date()): string {
  const p = (n: number) => String(n).padStart(2, "0");
  return `${d.getUTCFullYear()}/${p(d.getUTCMonth() + 1)}/${p(d.getUTCDate())} ${p(d.getUTCHours())}:${p(d.getUTCMinutes())}`;
}
