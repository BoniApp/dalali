# Dalali Architecture Upgrade — Supabase Schema & Migration Plan

## Overview

This document describes the database schema changes required to support the new Property Registry, Deal Tracking, Agency Fee, and Earnings systems.

---

## New Tables

### 1. `property_registry`

Canonical record of every physical property. One property = one registry entry.

```sql
create table property_registry (
  registry_id uuid primary key default gen_random_uuid(),
  property_hash text unique not null,
  latitude double precision not null,
  longitude double precision not null,
  landlord_phone text not null,
  landlord_name text not null,
  property_type text not null,
  rooms int not null default 0,
  address text not null,
  verification_status text not null default 'unverified',
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

create index idx_property_registry_hash on property_registry(property_hash);
create index idx_property_registry_phone on property_registry(landlord_phone);
```

### 2. `property_claims`

Ownership claims submitted by users when a duplicate is detected.

```sql
create table property_claims (
  claim_id uuid primary key default gen_random_uuid(),
  property_id uuid not null references property_registry(registry_id),
  claimant_id uuid not null references auth.users(id),
  claimant_role text not null,
  reason text not null,
  evidence_urls jsonb default '[]',
  status text not null default 'pending',
  reviewed_by uuid references auth.users(id),
  review_notes text,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);

create index idx_claims_property on property_claims(property_id);
create index idx_claims_claimant on property_claims(claimant_id);
create index idx_claims_status on property_claims(status);
```

### 3. `deals`

Tracks the lifecycle from match to confirmed tenancy.

```sql
create table deals (
  deal_id uuid primary key default gen_random_uuid(),
  property_id uuid not null,
  listing_creator_id uuid not null references auth.users(id),
  seeker_id uuid references auth.users(id),
  landlord_phone text not null,
  status text not null default 'matched',
  viewing_date timestamptz,
  created_at timestamptz not null default now(),
  confirmed_at timestamptz,
  tenant_confirmed boolean not null default false,
  landlord_confirmed boolean not null default false,
  tenant_confirmed_at timestamptz,
  landlord_confirmed_at timestamptz
);

create index idx_deals_creator on deals(listing_creator_id);
create index idx_deals_property on deals(property_id);
create index idx_deals_status on deals(status);
```

### 4. `agency_fees`

Fixed 20,000 TZS agency fee per confirmed tenancy.

```sql
create table agency_fees (
  fee_id uuid primary key default gen_random_uuid(),
  deal_id uuid not null references deals(deal_id),
  property_id uuid not null,
  listing_creator_id uuid not null references auth.users(id),
  amount double precision not null default 20000,
  currency text not null default 'TZS',
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  approved_at timestamptz,
  paid_at timestamptz,
  approved_by uuid references auth.users(id),
  payout_reference text
);

create index idx_agency_fees_creator on agency_fees(listing_creator_id);
create index idx_agency_fees_status on agency_fees(status);
```

### 5. `earnings`

Earnings ledger (replaces generic wallet transactions for agency fee tracking).

```sql
create table earnings (
  entry_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id),
  deal_id uuid,
  property_id uuid,
  property_title text,
  type text not null default 'agencyFee',
  status text not null default 'pending',
  amount double precision not null,
  currency text not null default 'TZS',
  created_at timestamptz not null default now(),
  available_at timestamptz,
  withdrawn_at timestamptz,
  withdrawal_id uuid
);

create index idx_earnings_user on earnings(user_id);
create index idx_earnings_status on earnings(status);
```

---

## Updated Tables

### `properties`

Add listing ownership and registry linkage columns.

```sql
alter table properties
  add column listing_creator_id uuid references auth.users(id),
  add column listing_creator_role text,
  add column registry_id uuid references property_registry(registry_id),
  add column agency_fee_eligible boolean not null default false,
  add column tenancy_confirmed boolean not null default false,
  add column listing_status text not null default 'draft';

create index idx_properties_registry on properties(registry_id);
create index idx_properties_creator on properties(listing_creator_id);
create index idx_properties_listing_status on properties(listing_status);
```

### `users`

Add trust badge and earnings fields.

```sql
alter table users
  add column is_verified_agent boolean not null default false,
  add column is_verified_property boolean not null default false,
  add column is_verified_listing_creator boolean not null default false,
  add column total_earnings double precision not null default 0;
```

---

## Row Level Security (RLS) Policies

### property_registry
```sql
alter table property_registry enable row level security;

-- Everyone can read registry
create policy "Registry read all"
  on property_registry for select to authenticated, anon using (true);

-- Only admins can insert/update
create policy "Registry admin write"
  on property_registry for all to authenticated
  using (exists (select 1 from users where id = auth.uid() and is_admin = true))
  with check (exists (select 1 from users where id = auth.uid() and is_admin = true));
```

### property_claims
```sql
alter table property_claims enable row level security;

create policy "Claims read own"
  on property_claims for select to authenticated using (claimant_id = auth.uid());

create policy "Claims read admin"
  on property_claims for select to authenticated
  using (exists (select 1 from users where id = auth.uid() and is_admin = true));

create policy "Claims insert own"
  on property_claims for insert to authenticated with check (claimant_id = auth.uid());

create policy "Claims update admin"
  on property_claims for update to authenticated
  using (exists (select 1 from users where id = auth.uid() and is_admin = true));
```

### deals
```sql
alter table deals enable row level security;

create policy "Deals read participants"
  on deals for select to authenticated
  using (listing_creator_id = auth.uid() or seeker_id = auth.uid());

create policy "Deals insert"
  on deals for insert to authenticated with check (true);

create policy "Deals update participants"
  on deals for update to authenticated
  using (listing_creator_id = auth.uid() or seeker_id = auth.uid());
```

### agency_fees
```sql
alter table agency_fees enable row level security;

create policy "Fees read own"
  on agency_fees for select to authenticated using (listing_creator_id = auth.uid());

create policy "Fees read admin"
  on agency_fees for select to authenticated
  using (exists (select 1 from users where id = auth.uid() and is_admin = true));

create policy "Fees update admin"
  on agency_fees for update to authenticated
  using (exists (select 1 from users where id = auth.uid() and is_admin = true));
```

### earnings
```sql
alter table earnings enable row level security;

create policy "Earnings read own"
  on earnings for select to authenticated using (user_id = auth.uid());

create policy "Earnings read admin"
  on earnings for select to authenticated
  using (exists (select 1 from users where id = auth.uid() and is_admin = true));

create policy "Earnings insert system"
  on earnings for insert to authenticated with check (true);

create policy "Earnings update admin"
  on earnings for update to authenticated
  using (exists (select 1 from users where id = auth.uid() and is_admin = true));
```

---

## Anti-Tamper Rules (clients cannot write)

```sql
-- Properties: clients cannot tamper with computed/controlled fields
create or replace function prevent_property_tamper()
returns trigger as $$
begin
  if new.is_approved is distinct from old.is_approved and not exists (
    select 1 from users where id = auth.uid() and is_admin = true
  ) then
    raise exception 'Clients cannot modify is_approved';
  end if;
  if new.view_count is distinct from old.view_count and not exists (
    select 1 from users where id = auth.uid() and is_admin = true
  ) then
    raise exception 'Clients cannot modify view_count';
  end if;
  if new.inquiry_count is distinct from old.inquiry_count and not exists (
    select 1 from users where id = auth.uid() and is_admin = true
  ) then
    raise exception 'Clients cannot modify inquiry_count';
  end if;
  return new;
end;
$$ language plpgsql;

create trigger trg_prevent_property_tamper
  before update on properties
  for each row execute function prevent_property_tamper();
```

---

## Migration Steps

1. **Backup** existing database.
2. Run the `create table` statements for the 5 new tables.
3. Run `alter table` statements on `properties` and `users`.
4. Create indexes for performance.
5. Enable RLS and apply policies.
6. Apply anti-tamper triggers.
7. Deploy updated Flutter app.
8. Verify duplicate detection and registry creation via add-property flow.
9. Verify deal tracking and dual-confirmation flow.
10. Verify agency fee generation and earnings ledger.

---

## Integration Checklist

- [x] PropertyRegistryModel + hash generation
- [x] PropertyClaimModel + claim workflow
- [x] DealModel + dual-confirmation engine
- [x] AgencyFeeModel
- [x] EarningsEntryModel + EarningsSummaryModel
- [x] PropertyModel updated with listing ownership fields
- [x] UserModel updated with trust badges + totalEarnings
- [x] PropertyRegistryService (duplicate detection + haversine)
- [x] DealService (lifecycle management)
- [x] EarningsService (summary computation)
- [x] DataService extended with new collections
- [x] AppState subscriptions for deals, earnings, claims
- [x] MainNavigation updated: Earnings + Opportunities tabs for all roles
- [x] EarningsScreen + AgencyFeeHistoryScreen
- [x] OpportunityFeedScreen
- [x] DealTrackingScreen with dual-confirmation UI
- [x] ClaimPropertyScreen
- [x] AddPropertyScreen integrated with duplicate detection
- [x] ProfileScreen trust badges
- [x] Admin screens: Registry, Claims, Agency Fees
- [x] Localization strings (EN + SW)
- [x] Default theme light
