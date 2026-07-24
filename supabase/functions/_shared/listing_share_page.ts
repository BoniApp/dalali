// ═══════════════════════════════════════════════════════════════
// Listing share preview page (shared)
//
// Builds the tiny HTML page served by the listing-share edge
// function. Social crawlers (WhatsApp, Facebook, X, TikTok) read the
// Open Graph tags and render a rich card with the listing PHOTO;
// humans are bounced straight to the dalaliapp.com deep link, which
// opens the app on the listing (see DeepLinkService).
// ═══════════════════════════════════════════════════════════════

export interface SharePageData {
  title: string;
  location: string;
  priceTzs: number;
  imageUrl: string;
  /// App deep link humans are redirected to (…/ref/CODE?listing=id).
  deepLinkUrl: string;
  code: string;
}

export function formatTzs(amount: number): string {
  return `TZS ${Math.round(amount).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",")}`;
}

function esc(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

export function buildSharePage(d: SharePageData): string {
  const price = `${formatTzs(d.priceTzs)}/month`;
  const ogTitle = esc(`${d.title} in ${d.location} — ${price}`);
  const ogDesc = esc(
    `Verified listing on Dalali. Sign up with referral code ${d.code} to view and book this home.`,
  );
  const img = esc(d.imageUrl);
  const link = esc(d.deepLinkUrl);

  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${ogTitle}</title>
<meta property="og:type" content="website">
<meta property="og:site_name" content="Dalali">
<meta property="og:title" content="${ogTitle}">
<meta property="og:description" content="${ogDesc}">
<meta property="og:image" content="${img}">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${ogTitle}">
<meta name="twitter:description" content="${ogDesc}">
<meta name="twitter:image" content="${img}">
<meta http-equiv="refresh" content="0;url=${link}">
</head>
<body style="margin:0;font-family:system-ui,sans-serif;background:#0D9488;display:flex;min-height:100vh;align-items:center;justify-content:center">
  <a href="${link}" style="display:block;max-width:340px;background:#fff;border-radius:16px;overflow:hidden;text-decoration:none;color:#1F2937;box-shadow:0 8px 24px rgba(0,0,0,.25)">
    <img src="${img}" alt="" style="width:100%;height:200px;object-fit:cover">
    <div style="padding:16px">
      <div style="font-weight:700">${ogTitle}</div>
      <div style="margin-top:4px;font-size:13px;color:#6B7280">${ogDesc}</div>
      <div style="margin-top:12px;font-size:13px;font-weight:600;color:#0D9488">Open in Dalali →</div>
    </div>
  </a>
  <script>location.replace(${JSON.stringify(d.deepLinkUrl)});</script>
</body>
</html>`;
}
