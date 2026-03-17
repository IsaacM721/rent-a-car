# Rent-a-Car App — Full Prepaid “Great MVP” Design Spec

Date: 2026-03-17  
Product: iOS Rent-a-Car App (fleet-owned)  
Repo: `rent-a-car/` (SwiftUI + SwiftData; backend: Firebase; payments: Stripe)

## 1) Goal & Non-Goals

### Goal
Build a fleet-owned rent-a-car app that **wows** customers with:
- **Instant trust**: transparent pricing + policies, real vehicle content, clear expectations.
- **Fast booking**: pick dates → pay → confirmation in under a minute.
- **Confidence post-booking**: clear next steps, directions, and easy support.

### Non-goals (MVP)
- Marketplace (third-party owners listing cars)
- Dynamic surge pricing
- Multi-city operations tooling
- Driver/dispatcher features (no ride-hailing)
- Loyalty tiers/subscriptions (can be added later)

## 2) Target Users & Constraints

### Primary users
- **Customers** booking rentals on iOS.
- **Operators (internal admin)** managing the fleet, availability, and bookings.

### Operating model
- Company **owns/manages the fleet**.
- Customer **pays 100% upfront** via card (Stripe).
- Operator fulfills booking and manages check-in/out.

### Authentication (MVP)
- Use Firebase Auth.
- MVP supports one simple sign-in method to reduce friction (choose one):
  - Phone OTP, or
  - Email + password

## 3) Experience Pillars (“Great” bar)

### 3.1 Trust by default
- “All-in” pricing on key screens.
- Policies written plainly (no legalese).
- Visible vehicle condition & accurate photos.

### 3.2 Speed without confusion
- Minimal steps; keep checkout on one screen.
- Defaults that reduce typing (saved details, remembered preferences).

### 3.3 Clarity after purchase
- A booking “timeline” + checklist: what to bring, where to go, how pickup works.
- Prominent support entry points.

## 4) Core Customer Flows

### 4.1 Browse inventory
Entry: Map screen and/or list view.

Requirements:
- **Map + list toggle**.
- Filter by: dates, price/day, seats, transmission, delivery availability, instant confirmation.
- Vehicle cards show:
  - Primary photo
  - Vehicle name + type
  - **All-in price/day** (or “from” price; choose one and keep consistent)
  - **Next available date** (if not available)

### 4.2 Vehicle detail
Requirements:
- Photo gallery
- Specs: seats, transmission, fuel, mileage policy, pickup location/delivery zones
- Pricing module:
  - Daily rate × days
  - Fees/taxes
  - Optional add-ons
  - Total (clearly labeled)
- Policies module:
  - Cancellation windows + fees
  - Late return policy
  - Fuel policy
  - Damage/incident policy

### 4.3 Checkout (Full prepaid)
One-screen checkout with:
- Date selection (pick-up/drop-off)
- Pickup/delivery selection (if supported)
- Add-ons
- Promo code (optional)
- Total with breakdown
- Pay with card

Success criteria:
- Payment completes
- Booking is created and confirmed
- User sees confirmation + next steps

### 4.4 Post-booking management
Booking detail screen shows:
- Status timeline: `confirmed → picked_up → returned → completed` (+ `cancelled`)
- Pickup address + hours + navigation
- “What to bring” checklist
- Support: call/text/email or in-app chat (MVP can be call/text)
- Modify/cancel:
  - Cancellation rules enforced by policy + time windows
  - Modifications may require operator review (MVP: block or allow limited changes)

## 5) Operator/Admin Flows (internal)

### 5.1 Fleet management
- Create/update vehicle inventory:
  - Photos
  - Base location (lat/lng)
  - Daily rate and price tiers (weekday/weekend optional)
  - Availability rules
  - Maintenance mode / blackout dates

### 5.2 Booking operations
- View bookings by status and date
- Check-in/out:
  - Condition notes
  - Damage notes/photos (phase 2)
  - Mileage and fuel at return (phase 2)

### 5.3 Refunds & cancellations
- Operator can issue:
  - Full refund
  - Partial refund
  - No refund (policy-based)
- Each action must leave an audit trail.

## 6) Payments & Money Movement (Stripe)

### 6.1 Payment method
- Card only for MVP (Apple Pay can be added later via Stripe)

### 6.2 Payment model
- Create PaymentIntent for the **full prepaid amount** at checkout.
- Capture immediately (default) or authorize+capture later (optional; choose one).

Recommendation:
- **Immediate capture** for simplicity in MVP.

### 6.2.1 Currency
- Pick a single primary currency for MVP and keep it consistent end-to-end (UI + Stripe + receipts).
- If operating in the Dominican Republic, default to `dop` unless there is a strong reason to use `usd`.

### 6.3 Refunds
- Refunds executed through Stripe, linked to booking ID.
- Refund policy is enforced in backend, not only client UI.

### 6.4 Ledger / audit
Maintain a minimal ledger so you can reconcile:
- Booking total
- Stripe fees
- Refunds
- Net revenue

## 7) Data Model (Firebase)

### 7.1 Collections (Firestore)

#### `users/{uid}`
- `name`
- `phone` (optional)
- `email` (optional)
- `createdAt`

#### `cars/{carId}`
- `name`
- `type`
- `priceLevel` (optional UI label)
- `dailyRate` (number)
- `location` (GeoPoint)
- `neighborhood` (string for UI)
- `isActive` (bool)
- `photos[]` (urls)
- `specs` (map: seats, transmission, fuel, etc.)
- `createdAt`, `updatedAt`

#### `bookings/{bookingId}`
- `userId`
- `carId`
- `startAt`, `endAt`
- `days`
- `pricing`
  - `dailyRate`
  - `subtotal`
  - `fees`
  - `taxes`
  - `discount`
  - `total`
- `status` (`pending_payment|confirmed|picked_up|returned|completed|cancelled`)
- `createdAt`
- `cancellation`
  - `cancelledAt`
  - `reason`
  - `refundAmount`
- `payment`
  - `provider` = `stripe`
  - `paymentIntentId`
  - `chargeId` (optional)
  - `amount`
  - `currency` (e.g. `usd` or `dop`)
  - `refundedAmount`

#### `carAvailability/{carId}/blocks/{blockId}` (optional structure)
- Used to block dates for maintenance or manual holds.
- Alternative: compute availability from bookings + blocks.

### 7.2 Realtime needs
Not required for MVP (no live tracking). Avoid Realtime DB unless needed later.

## 8) Backend Logic (Cloud Functions)

### 8.1 Booking creation (atomicity + double-booking prevention)
Booking creation must:
- Validate car availability for the selected date range.
- Create/confirm Stripe PaymentIntent and ensure payment success.
- Create booking record only after payment succeeds (or create pending, then confirm).

Recommended approach (safe):
- Create booking with status `pending_payment` (not visible to others).
- Confirm payment via Stripe.
- Transition booking to `confirmed`.
- Add availability block (or rely on confirmed bookings to block).

Edge cases to handle:
- **Race conditions**: two users trying to book the same car for overlapping dates.
- **Time zones**: treat start/end as date-times in a single canonical timezone (e.g. local fleet timezone).
- **Idempotency**: retries from client or Stripe webhooks should not create duplicate bookings/charges.

### 8.2 Cancellation
- Enforce time-window rules.
- Issue Stripe refund if applicable.
- Update booking status and store cancellation metadata.

## 9) UI Mapping to Existing Code

This spec aligns to current screens in repo:
- `MapView.swift`: browse inventory (map + card)
- `CarDetailView.swift`: vehicle details
- `RentCheckoutView.swift`: checkout flow (adapt to full prepaid + Stripe)
- `AdminView.swift` / `VehicleFormView.swift`: fleet management
- `WalletView.swift`: can be repurposed to “Payments/Receipts” or account area

### Data source note (important)
The repo currently uses SwiftData models for local demo data (e.g. `CarModel` via `@Query`).
For MVP production, inventory and bookings should load from Firestore, with SwiftData either:
- removed from the main flows, or
- kept only as a local cache (phase 2).

## 10) MVP Success Criteria
- User can browse cars, view details, choose dates, pay, and receive a confirmed booking.
- Operator can add cars and see bookings.
- No double-bookings.
- Refund/cancel works and is auditable.

## 11) Open Decisions (explicit)
- Currency: USD vs DOP in app UI and Stripe account configuration.
- Cancellation policy: exact windows (e.g. full refund within 24h, partial after).
- Delivery: pickup-only for MVP or allow delivery with fee.

