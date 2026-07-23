# DalaliApp — Property Listing Journey: Workflow Specification

System workflow spec for the listing → viewing → application → reservation → tenancy pipeline.
Written against the actual codebase; every element is tagged so readers can distinguish what
exists today from what is designed but not yet built.

**Status tags**

| Tag | Meaning |
|---|---|
| ✅ | Implemented and persisted in Supabase |
| 🟡 | Partially implemented (client-only, unwired, or unreachable) |
| ❌ | Stubbed / missing (call path or table does not exist) |
| 🆕 | Proposed in this document (not yet built) |

**Source-of-truth map**

| Concern | Authority |
|---|---|
| DB schema | `supabase/migrations/002_core_data.sql` (properties, appointments, inquiries), `010_architecture_upgrade_and_kyc.sql` (deals, agency_fees, listing_status), `009_notifications_table.sql` |
| Client state machines | `lib/providers/app_state.dart` (applications, tenancies, appointments), `lib/services/deal_service.dart` (deals) |
| Persistence | `supabase/migrations/019_tenancy_applications_and_tenancies.sql` — applications/tenancies are DB-backed with trigger-owned side effects (G1 closed); maintenance/review methods remain stubs in `data_service.dart` |
| UX entry points | `lib/screens/shared/property_detail_screen.dart`, `lib/screens/tenancy/reservation_requests_screen.dart`, `lib/screens/tenancy/tenancy_detail_screen.dart`, `lib/screens/deals/deal_tracking_screen.dart` |

---

## 0. Entities and interlocking state machines

Five state machines drive the journey. They interlock through side effects, not foreign-key
enforced workflows — several transitions are orchestrated in client code (`AppState`), which
matters for the gap analysis in §6.

```
Property (listing)          Appointment (viewing)        TenancyApplication ("reservation request")
  status ✅                   status ✅                      status ✅ (migration 019)
  listing_status ✅                                                        │
  is_approved ✅                                                           ▼
        ▲                            Deal ✅ ──────────► Tenancy ✅ (migration 019)
        └──── side effects pending → occupied → available, trigger-owned (migration 019)
```

- **Property** — `properties.status`: `available | occupied | pending` ✅ (DB CHECK);
  `properties.listing_status`: `draft | active | viewing | negotiating | tenancyConfirmed | closed` ✅ (migration 010, default `draft`);
  `is_approved` ✅ (client writes blocked by `prevent_property_tamper` trigger).
- **Appointment** — `appointments.status`: `pending | confirmed | completed | cancelled` ✅ (DB CHECK + RLS).
- **TenancyApplication** — `ApplicationStatus { pending, approved, rejected }` ✅ (migration 019: table + RLS + `tenancy_application_guard` transition trigger).
- **Tenancy** — `TenancyStatus { upcoming, active, completed, terminated }` ✅ (migration 019: table + RLS + `tenancy_guard` transition trigger).
- **Deal** — `deals.status`: `matched | viewingScheduled | viewingCompleted | negotiating | tenancyConfirmed | agencyFeePending | agencyFeePaid | closed` ✅ (migration 010).

**Feed visibility rule** (gates the whole journey): a listing is discoverable iff
`status = 'available' AND is_approved = true` — enforced in the seeker feed
(`data_service.dart:47`), paginated queries (`:68-69`), and the `properties_nearby` RPC
(migration 012, SECURITY INVOKER).

---

## 1. Phase 1 — Discovery → Viewing Request → Application → Landlord Notification

### 1.1 Happy-path sequence

| # | Actor | Action | System effect | Status |
|---|-------|--------|---------------|--------|
| 1 | Seeker | Opens home feed / Near Me map | Receives only `available` + `is_approved` listings (realtime stream, newest first; map variant sorted by distance) | ✅ |
| 2 | Seeker | Taps a listing | `properties.view_count + 1` (fire-and-forget update) | ✅ |
| 3 | Seeker | Taps **Schedule Viewing** on `property_detail_screen.dart:339`, picks date/time in dialog | `AppState.addAppointment` → INSERT `appointments` (`status='pending'`) | ✅ |
| 4 | System | Trigger: appointment INSERT (client-orchestrated) | `NotificationService.notifyUser` → INSERT `notifications` for `landlord_id`: `type='appointment'`, title **"New Viewing Request"**, body "{seeker} wants to view {property}", `target_collection='appointments'` | ✅ |
| 5 | Landlord | (Intended) confirms/completes/cancels viewing | `AppState.updateAppointmentStatus` exists and persists | 🟡 **no screen calls it** — appointments never leave `pending` in the current UI |
| 6 | Seeker | Taps **Apply to Rent** (`ApplyForTenancyButton`), optional note, Submit | `AppState.applyForTenancy` → INSERT `tenancy_applications` (`status='pending'`, DB-generated id); duplicate open applications rejected by the `uniq_open_application` index | ✅ |
| 7 | System | Trigger: `trg_new_tenancy_application` (AFTER INSERT, server-side) | INSERT `notifications` for landlord: `type='tenancyApplication'`, title **"New Tenancy Application"**, body "{tenant} applied for {property}", `target_collection='tenancy_applications'` | ✅ |
| 8 | Landlord | Opens app → notifications list | Sees the notification (persisted, realtime stream) | ✅ |
| 9 | Landlord | Opens **Reservations → Reservation Approvals** | Realtime stream of `tenancy_applications` scoped by RLS to the landlord; Approve/Reject buttons write `status` only — side effects run in triggers | ✅ |

### 1.2 Branch outcomes at each step

- **Step 1 — nothing visible**: listing is `draft`/unapproved (`is_approved=false` pending moderation, admin-gated) or already `pending`/`occupied`. Dead end from the seeker's perspective — see §4.
- **Step 3 — viewing request guards**: none server-side. Any authenticated user can INSERT an
  appointment as `seeker_id` (RLS: `auth.uid() = seeker_id`), including for their own listing.
  No double-booking, date-past, or property-availability validation. 🆕 Recommended: CHECK /
  trigger guard that `scheduled_date > now()` and property is `available`.
- **Step 3 alternative doors** (all on the detail screen): **Send Inquiry** (persisted
  `inquiries` row, `is_read=false`, `inquiry_count+1`, landlord marks read ✅); **Chat**
  (`conversations`/`messages`, migration 017 ✅); call/SMS (leaves the app); **Pay Agency Fee**
  (→ `PaymentScreen`, 20,000 TZS fixed — payable *without* any application or reservation;
  attribution handled server-side by the payment webhook).
- **Step 6 — duplicate application**: blocked client-side only (`alreadyApplied` check in
  `ApplyForTenancyButton`). No DB uniqueness — a second session or reinstall bypasses it. ❌
- **Step 6 — apply without viewing**: allowed. The viewing→application order is a UX
  suggestion, not an enforced transition. 🆕 If the business wants "viewing before
  application," enforce via a check that a `completed` appointment exists for the pair.
- **Step 6 — non-seeker roles**: button hidden unless `role == seeker` (client-side).

---

## 2. Phase 2 — Seeker Applications: State Machine

**States** (`ApplicationStatus`): `pending` (initial) → `approved` | `rejected`.
🆕 Proposed additions: `withdrawn`, `expired` (see transition table).

### 2.1 Transition matrix

| # | From → To | Trigger / Actor | Guards | Effects on commit | Status |
|---|-----------|-----------------|--------|-------------------|--------|
| T1 | — → `pending` | Seeker submits application (`applyForTenancy`) | `role=seeker` (client); RLS: `auth.uid()=tenant_id` and `landlord_id` must match the property's landlord; one open application per property per seeker (`uniq_open_application`) | Notify landlord (`tenancyApplication`, INSERT trigger) | ✅ |
| T2 | `pending` → `approved` | Landlord taps **Approve** in Reservation Approvals (`approveApplication`) | RLS: caller is `landlord_id`; guard trigger: only from `pending`; atomic `properties.status='available'` guard aborts if the listing was already taken | ① `resolved_at=now` (trigger-stamped); ② notify tenant (`tenancyApproved`, "Application Approved"); ③ **create Tenancy** (`status=upcoming`, move-in = now+14d, expected move-out = now+374d, rent = listing price, deposit = 2× rent); ④ **property reserved**: `properties.status → 'pending'` → listing leaves the public feed. ②③④ run inside `handle_application_resolution()` in the same transaction | ✅ |
| T3 | `pending` → `rejected` | Landlord taps **Reject**, optional reason | RLS: caller is `landlord_id`; guard trigger: only from `pending` | `resolved_at=now` (trigger-stamped), `notes=reason`; notify tenant (`type='system'`, "Application Rejected"). No property side effects | ✅ |
| T4 | `pending` → `withdrawn` 🆕 | Seeker withdraws ("My Applications") | Caller is `tenant_id`; status still `pending` | Notify landlord; frees seeker to re-apply later | 🆕 |
| T5 | `pending` → `expired` 🆕 | TTL job: no landlord decision within N days (proposed N=7) | System | Notify both parties; application becomes read-only | 🆕 |
| T6 | `approved` → (void) 🆕 | Landlord revokes before tenancy activation, or seeker declines after approval | Within activation window | Release hold: `properties.status → 'available'`; terminate the `upcoming` tenancy; notify counterpart | 🆕 closes the "stuck pending listing" hole in §3 |

### 2.2 Branch outcomes and edge cases

- **Competing applications**: multiple seekers may apply to one property. On T2, all other
  `pending` applications for that property are **left dangling** — no auto-reject, no
  notification. ❌ 🆕 On approval, bulk-transition siblings → `rejected` with reason
  "Property reserved by another applicant" and notify each.
- **Re-application**: the DB now allows it correctly — rejected rows drop out of the
  `uniq_open_application` partial index, so a fresh application INSERT succeeds. The
  client-side `alreadyApplied` check in `ApplyForTenancyButton` still matches applications of
  **any** status, so the UI blocks legitimate re-applications after rejection. ❌ client-side
  residue — 🆕 scope the check to `pending`/`approved`.
- **No edit**: an application is immutable once submitted (guard trigger allows only
  `status`/`notes` changes; resolved rows are fully locked).
- **Cross-device consistency** ✅ (fixed by migration 019): applications and tenancies are
  persisted; both parties stream rows scoped by RLS. Approval side effects (tenancy creation,
  property reservation, notifications) execute in one DB transaction — no partial-failure
  drift between the application, the tenancy, and the listing.
- **Tenancy follow-on** (from T2③): `upcoming → active` via landlord's **Confirm Move-in**
  button (`activateTenancy`; `handle_tenancy_status_change` trigger flips
  `properties.status → 'occupied'`); `active → completed` via **End Tenancy**
  (`completeTenancy`; trigger flips `properties.status → 'available'` — listing re-enters
  the feed). Transition legality and timestamps are guard-enforced. `terminated` is accepted
  by the DB (`upcoming`/`active → terminated`) but **no UI path sets it yet** ❌.

---

## 3. Phase 3 — Reservations: Lifecycle, Holding, Expiration

### 3.1 What exists today 🟡

There is **no reservation entity**. "Reservation" is emergent behavior:

| Aspect | Current behavior |
|---|---|
| Creation | Implicit — a reservation *is* an approved application (the `handle_application_resolution` trigger sets `properties.status='pending'` atomically, migration 019) |
| Hold condition | None. The property sits at `pending` indefinitely; it vanishes from the feed but is not bound to any expiry, payment, or confirmation |
| Release | Only forward: `activateTenancy` (`pending → occupied`) or `completeTenancy` (`→ available`). **No path reverts `pending → available`** if the deal falls through ❌ |
| Expiration | None. A listing can be stuck at `pending` forever, invisible and unbookable ❌ |
| UI | `ReservationRequestsScreen` ("Reservation Approvals" / "My Applications") — renders the (unpersisted) application lists |

### 3.2 Proposed reservation lifecycle 🆕

Introduce a first-class `reservations` table (one active row per property):

```
            approve application (T2)
                      │
                      ▼
                   HELD ───────────────┬──────────────────┐
                  │   │                │                  │
     fee paid /   │   │ TTL expires    │ landlord releases│ seeker cancels
     both confirm │   │ (72 h)         │ (T6)             │ (T6)
                  ▼   ▼                ▼                  ▼
              CONFIRMED            EXPIRED            RELEASED / CANCELLED
                  │
                  ▼  move-in confirmed (activateTenancy)
              CONVERTED → tenancy active, property occupied
```

| State | Meaning | Property status while in state | Exit |
|---|---|---|---|
| `held` | Property soft-locked for this seeker pending fee/confirmation | `pending` (hidden from feed) | fee/confirm → `confirmed`; TTL → `expired`; either party backs out → `released`/`cancelled` |
| `confirmed` | Agency fee paid / both parties confirmed intent; awaiting move-in | `pending` | move-in → `converted`; no move-in by deadline → `expired` |
| `converted` | Terminal-success: tenancy activated | `occupied` | — |
| `expired` | Terminal-fail: TTL lapsed | auto-revert → `available` | — |
| `released` / `cancelled` | Terminal-fail: landlord / seeker aborted | auto-revert → `available` | — |

**Holding conditions (proposed rules)**

- R1 — Exclusivity: at most one `held`/`confirmed` reservation per property. Enforce with a
  partial unique index: `UNIQUE(property_id) WHERE status IN ('held','confirmed')`.
- R2 — Eligibility: reservation is created only from an `approved` application, by system
  trigger — never directly by a client.
- R3 — Hold TTL: `held` expires after **72 h** unless converted to `confirmed` (fee paid or
  dual confirmation). `confirmed` expires at the tenancy `moveInDate` if not activated.
- R4 — No stacking: a seeker may hold at most one active reservation per property (and 🆕 at
  most 3 platform-wide, to prevent hoarding).

**Expiration rules (proposed)**

- E1 — Enforced by a scheduled job (pg_cron or scheduled Edge Function), not client timers:
  `UPDATE reservations SET status='expired' WHERE status IN ('held','confirmed') AND expires_at < now()`.
- E2 — On expiry: `properties.status → 'available'` (listing re-enters feed), linked
  application → `expired`, notify both parties (`type='system'`).
- E3 — Expiry is idempotent and race-safe against a concurrent `converted` commit (guard the
  UPDATE with the state predicate above).
- E4 — Extension: landlord may extend `held` once by +48 h; record `extended_count` to prevent
  indefinite parking.

---

## 4. Phase 4 — Dead Ends (Terminal States)

Every state from which the workflow **permanently** closes for that entity instance, and what
happens to the rest of the graph:

| Entity | Terminal state | How reached | Ripple effects | Status |
|---|---|---|---|---|
| Listing | **Rented out**: `status='occupied'` + `listing_status='tenancyConfirmed'` | Deal dual confirmation (`DealService._confirmTenancy`) ✅, or tenancy activation 🟡 | Exits feed; new applications/viewings should be refused 🆕 (no guard today ❌) | ✅/🟡 |
| Listing | **Closed**: `listing_status='closed'` | `DealService.closeDeal` | Ends the deal pipeline; does **not** reset `status` — listing may stay `available` and visible, a zombie state ❌ define whether closed = delisted | 🟡 |
| Listing | **Delisted / rejected**: `is_approved=false` | Admin moderation (trigger-protected from clients) | Exits feed immediately; all `pending` applications/appointments orphaned — 🆕 cascade-notify | ✅ |
| Listing | **Deleted** | Landlord/admin DELETE | DB `ON DELETE CASCADE` removes appointments/inquiries; applications (in-memory) dangle ❌ | ✅ |
| Application | `rejected` | Landlord decision (T3) | Seeker notified; currently cannot re-apply ❌ | 🟡 |
| Application | `withdrawn` 🆕 | Seeker cancels (T4) | Frees property + seeker | 🆕 |
| Application | `expired` 🆕 | TTL (T5/E2) | Hold released, listing re-listed | 🆕 |
| Appointment | `cancelled` | Either party (RLS allows both; no UI today ❌) | Seeker may re-book; no notification on change ❌ → 🆕 notify counterpart | ✅ schema / ❌ UX |
| Appointment | `completed` | Landlord after viewing | Terminal for the appointment; expected precursor to application | ✅ schema / ❌ UX |
| Reservation | `expired` / `released` / `cancelled` / `converted` | §3.2 | Property status reconciled automatically | 🆕 |
| Deal | `closed` | `closeDeal` after fee settlement | End of agency-fee pipeline (`agencyFeePaid → closed`) | ✅ |
| Deal | **Collapsed** 🆕 | No cancel path exists today ❌ — a deal whose seeker walks away sits in `negotiating` forever | 🆕 add `cancelled` with reason + property rollback | 🆕 |
| Tenancy | `completed` | `completeTenancy` | Property returns to `available` — **the cycle restarts** (only designed loop-back) | 🟡 |
| Tenancy | `terminated` | Early exit — enum value exists, **no setter** ❌ | 🆕 wire to a "Terminate" flow with handover report; property → `available` | ❌ |

**Dead-end invariants to enforce** 🆕

1. A listing in a terminal state refuses new appointments, applications, reservations, and deals (trigger-level guard, not client checks).
2. Every terminal transition reconciles `properties.status` in the same transaction — today this reconciliation is scattered across client code and silently skipped on failure (all DB calls are fire-and-forget `catchError(debugPrint)`).
3. Every terminal transition notifies the counterparty; today only create/approve/reject notify.

---

## 5. Interlock: Deal pipeline (agency-fee track) ✅

Parallel machine that monetizes the journey (`deals`, `agency_fees` — fully persisted):

| Transition | Trigger | Notes |
|---|---|---|
| — → `matched` | `DealService.createDeal` | ❌ **never called** from any screen — pipeline is detached from the journey |
| `matched` → `viewingScheduled` → `viewingCompleted` → `negotiating` | service methods | ⚠️ lookup bug: methods query `getDealsForProperty(dealId)` — a deal id passed as property id (`deal_service.dart:34` etc.) |
| `negotiating` → `tenancyConfirmed` | **dual confirmation**: `confirmTenant` + `confirmLandlord`; second flag auto-advances | Side effect: property → `occupied`, `listing_status='tenancyConfirmed'`, `tenancy_confirmed=true` ✅ |
| → `agencyFeePending` | (intended: on tenancyConfirmed) | ❌ never set by any code path |
| → `agencyFeePaid` → `closed` | `markAgencyFeePaid`, `closeDeal` | Fee record: fixed **20,000 TZS**, `agency_fees.status: pending → approved → paid` (admin-approved), mirrored to `earnings` ledger |

---

## 6. Gap register (build list)

| ID | Gap | Impact | Proposed fix |
|---|---|---|---|
| G1 | ✅ **Done** — `supabase/migrations/019_tenancy_applications_and_tenancies.sql`: both tables + RLS + guard triggers + server-owned side effects (landlord/tenant notifications, tenancy creation, atomic property reservation and reconciliation). `DataService` stubs replaced with real typed queries; `AppState` reduced to status writes | — | Apply with `supabase db push`; remaining client residue: `ApplyForTenancyButton` dedup still matches resolved applications (see §2.2) |
| G2 | ❌ `updateAppointmentStatus` has no UI caller | Viewings stay `pending` forever | Landlord appointment inbox with Confirm/Cancel/Complete |
| G3 | ❌ `createDeal` never called; `agencyFeePending` never set | Fee pipeline detached | Create deal on first viewing request or on application approval |
| G4 | ⚠️ `DealService` queries deals by property id using a deal id | Viewing transitions never find their deal | Query `.eq('deal_id', dealId)` |
| G5 | ❌ No reservation entity, hold, or expiry | Listings stuck at `pending` | §3.2 table + TTL job + property status reconciliation |
| G6 | ❌ Competing applications not resolved on approval | Losing seekers never told | Bulk auto-reject + notify in T2 trigger |
| G7 | ❌ Application dedup client-side only; blocks legit re-applications | Dupes via reinstall; no re-apply after rejection | DB unique `(property_id, tenant_id) WHERE status IN ('pending','approved')` |
| G8 | ❌ No notification on appointment status change | Seeker not told of confirm/cancel | Notify counterpart in update path (or DB trigger) |
| G9 | ❌ Side effects run client-side, fire-and-forget | Partial failures leave graph inconsistent (e.g., application approved but property not reserved) | Move T2/activation/expiration side effects into DB triggers or an Edge Function transaction |
| G10 | ❌ `terminated` tenancy unreachable; no early-exit flow | Dead enum value | Terminate flow + handover report linkage |

---

## Appendix A — Notification matrix (as built)

| Event | Recipient | `type` | Title | Persisted |
|---|---|---|---|---|
| Viewing requested | Landlord | `appointment` | "New Viewing Request" | ✅ |
| Application submitted | Landlord | `tenancyApplication` | "New Tenancy Application" | ✅ |
| Application approved | Tenant | `tenancyApproved` | "Application Approved" | ✅ |
| Application rejected | Tenant | `system` | "Application Rejected" | ✅ |
| New chat message | Recipient | `message` | (sender name) | ✅ (migration 017 trigger) |
| Appointment confirmed/cancelled | Counterpart | — | — | ❌ missing |
| Reservation expiring / expired 🆕 | Both | `system` | "Reservation Expired" | 🆕 |
