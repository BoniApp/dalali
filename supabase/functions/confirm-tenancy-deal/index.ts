/// ═══════════════════════════════════════════════════════════════
/// SUPABASE EDGE FUNCTION: confirm-tenancy-deal
/// ═══════════════════════════════════════════════════════════════
///
/// Server-side dual-confirmation tenancy workflow.
/// Triggered when tenant OR landlord confirms a deal.
/// When BOTH confirm:
///   - Deal status -> tenancyConfirmed
///   - Agency fee record created (20,000 TZS)
///   - Earnings entry created for listing creator
///   - Property status -> closed
///
/// Invocation:
///   POST /functions/v1/confirm-tenancy-deal
///   Body: { deal_id: string, confirmed_by: 'tenant' | 'landlord' }
///
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { deal_id, confirmed_by } = await req.json()

    if (!deal_id || !confirmed_by) {
      return new Response(
        JSON.stringify({ error: 'deal_id and confirmed_by are required' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
      )
    }

    // Fetch deal
    const { data: deal } = await supabaseClient
      .from('deals')
      .select('*')
      .eq('deal_id', deal_id)
      .single()

    if (!deal) {
      return new Response(
        JSON.stringify({ error: 'Deal not found' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 404 }
      )
    }

    const now = new Date().toISOString()

    // Update confirmation flags
    const updateData: Record<string, unknown> = {}
    if (confirmed_by === 'tenant') {
      updateData.tenant_confirmed = true
      updateData.tenant_confirmed_at = now
    } else if (confirmed_by === 'landlord') {
      updateData.landlord_confirmed = true
      updateData.landlord_confirmed_at = now
    }

    await supabaseClient
      .from('deals')
      .update(updateData)
      .eq('deal_id', deal_id)

    // Re-fetch to check dual confirmation
    const { data: updatedDeal } = await supabaseClient
      .from('deals')
      .select('*')
      .eq('deal_id', deal_id)
      .single()

    if (!updatedDeal) {
      return new Response(
        JSON.stringify({ error: 'Deal update failed' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
      )
    }

    // If both confirmed, finalize
    if (updatedDeal.tenant_confirmed && updatedDeal.landlord_confirmed) {
      // Update deal status
      await supabaseClient
        .from('deals')
        .update({
          status: 'tenancyConfirmed',
          confirmed_at: now,
        })
        .eq('deal_id', deal_id)

      // Create agency fee record
      await supabaseClient
        .from('agency_fees')
        .insert({
          deal_id,
          property_id: updatedDeal.property_id,
          listing_creator_id: updatedDeal.listing_creator_id,
          amount: 20000,
          currency: 'TZS',
          status: 'pending',
          created_at: now,
        })

      // Create earnings entry
      await supabaseClient
        .from('earnings')
        .insert({
          user_id: updatedDeal.listing_creator_id,
          deal_id,
          property_id: updatedDeal.property_id,
          type: 'agencyFee',
          status: 'pending',
          amount: 20000,
          currency: 'TZS',
          created_at: now,
        })

      // Update property status
      await supabaseClient
        .from('properties')
        .update({
          tenancy_confirmed: true,
          listing_status: 'closed',
          agency_fee_eligible: true,
        })
        .eq('id', updatedDeal.property_id)
    }

    return new Response(
      JSON.stringify({
        success: true,
        deal_id,
        tenant_confirmed: updatedDeal.tenant_confirmed,
        landlord_confirmed: updatedDeal.landlord_confirmed,
        fully_confirmed: updatedDeal.tenant_confirmed && updatedDeal.landlord_confirmed,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
    )
  }
})
