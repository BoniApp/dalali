/// ═══════════════════════════════════════════════════════════════
/// SUPABASE EDGE FUNCTION: listing-share
/// ═══════════════════════════════════════════════════════════════
///
/// Serves the Open Graph preview page for influencer listing shares,
/// so social platforms render a rich card with the listing PHOTO.
/// Humans are redirected to the dalaliapp.com deep link (opens the
/// app on the listing; see DeepLinkService).
///
///   GET /functions/v1/listing-share?l=<property-id>&r=<referral-code>
///
/// Must be deployed with verify_jwt = false (see supabase/config.toml)
/// — crawlers send no auth headers.
///
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { buildSharePage } from '../_shared/listing_share_page.ts'

function htmlResponse(html: string, status = 200) {
  return new Response(html, {
    status,
    headers: { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'public, max-age=300' },
  })
}

serve(async (req) => {
  const url = new URL(req.url)
  const listingId = url.searchParams.get('l') ?? ''
  const code = (url.searchParams.get('r') ?? '').toUpperCase()

  // Humans always land on the referral deep link, even when the
  // listing is gone — fall back to the bare referral URL.
  const bareRef = `https://dalaliapp.com/ref/${code}`
  if (!listingId || !code) {
    return Response.redirect(bareRef, 302)
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const { data: property } = await supabase
      .from('properties')
      .select('title, location, rent_price, images')
      .eq('id', listingId)
      .maybeSingle()

    if (!property) {
      return Response.redirect(bareRef, 302)
    }

    const images = Array.isArray(property.images) ? property.images : []
    return htmlResponse(buildSharePage({
      title: property.title ?? 'House for rent',
      location: property.location ?? '',
      priceTzs: Number(property.rent_price ?? 0),
      imageUrl: images.length > 0 ? String(images[0]) : 'https://dalaliapp.com/icons/Icon-512.png',
      deepLinkUrl: `${bareRef}?listing=${listingId}`,
      code,
    }))
  } catch (error) {
    return htmlResponse(`Error: ${error.message}`, 500)
  }
})
