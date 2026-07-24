import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { buildSharePage, formatTzs } from "./listing_share_page.ts";

const data = {
  title: "2BR Apartment",
  location: "Mikocheni",
  priceTzs: 450000,
  imageUrl: "https://cdn.example.com/house.jpg",
  deepLinkUrl: "https://dalaliapp.com/ref/K7X2M?listing=abc-123",
  code: "K7X2M",
};

Deno.test("formatTzs groups thousands", () => {
  assertEquals(formatTzs(20000), "TZS 20,000");
  assertEquals(formatTzs(450000), "TZS 450,000");
});

Deno.test("share page carries the listing photo as og:image + twitter:image", () => {
  const html = buildSharePage(data);
  assertStringIncludes(html, '<meta property="og:image" content="https://cdn.example.com/house.jpg">');
  assertStringIncludes(html, '<meta name="twitter:card" content="summary_large_image">');
  assertStringIncludes(html, '<meta name="twitter:image" content="https://cdn.example.com/house.jpg">');
});

Deno.test("share page embeds title, price and the deep-link redirect", () => {
  const html = buildSharePage(data);
  assertStringIncludes(html, "2BR Apartment in Mikocheni — TZS 450,000/month");
  assertStringIncludes(html, '<meta http-equiv="refresh" content="0;url=https://dalaliapp.com/ref/K7X2M?listing=abc-123">');
  assertStringIncludes(html, "referral code K7X2M");
});

Deno.test("share page HTML-escapes listing text", () => {
  const html = buildSharePage({ ...data, title: 'A "Great" <Home> & Co' });
  assertStringIncludes(html, "A &quot;Great&quot; &lt;Home&gt; &amp; Co");
  assertEquals(html.includes("<Home>"), false);
});
