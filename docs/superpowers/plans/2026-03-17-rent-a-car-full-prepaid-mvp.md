# Rent-a-Car Full Prepaid MVP Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship an iOS fleet-owned rent-a-car app where users browse cars, pick dates, pay **100% upfront (USD)**, and receive a **confirmed booking** with strong double-booking protection.

**Architecture:** SwiftUI app uses **Firebase Auth (Phone OTP)** for sign-in, **Firestore** for `cars` + `bookings`, and **Cloud Functions** to create Stripe PaymentIntents + enforce availability/atomic booking state transitions. Stripe webhooks finalize payment state and update bookings.

**Tech Stack:** SwiftUI, Swift Concurrency, Firebase iOS SDK (Auth, Firestore, Functions), Node.js Firebase Cloud Functions, Stripe (PaymentIntent + webhooks).

---

## File map (what we’ll touch)

**iOS app (SwiftUI):**
- Modify: `rent-a-car/rent_a_carApp.swift` (Firebase init already added)
- Create: `rent-a-car/Services/Firebase/AuthService.swift`
- Create: `rent-a-car/Services/Firebase/FirestoreService.swift`
- Create: `rent-a-car/Services/Bookings/BookingService.swift`
- Create: `rent-a-car/Services/Payments/StripeCheckoutService.swift`
- Create: `rent-a-car/Models/Firestore/CarDoc.swift`
- Create: `rent-a-car/Models/Firestore/BookingDoc.swift`
- Modify: `rent-a-car/MapView.swift` (load cars from Firestore instead of SwiftData `@Query`)
- Modify: `rent-a-car/CarDetailView.swift` (date selection entry + availability messaging)
- Modify: `rent-a-car/RentCheckoutView.swift` (replace fake payment rows with real card flow)
- Create: `rent-a-car/Views/Auth/PhoneAuthView.swift`
- Create: `rent-a-car/Views/Bookings/BookingDetailView.swift`
- Modify: `rent-a-car/AdminView.swift` + `rent-a-car/VehicleFormView.swift` (write cars to Firestore; keep SwiftData only if needed for local drafts)

**Firebase (repo-level):**
- Create: `firebase.json`
- Create: `firestore.rules`
- Create: `firestore.indexes.json` (if needed for queries)
- Create: `functions/package.json`
- Create: `functions/src/index.ts` (or `index.js`)
- Create: `functions/src/stripe.ts`
- Create: `functions/src/bookings.ts`

**Tests:**
- Create: `rent-a-carTests/AvailabilityTests.swift`
- Create: `rent-a-carTests/PricingTests.swift`
- (Optional) Create: `functions/test/bookings.test.ts` (unit tests for booking overlap + idempotency)

---

## Chunk 1: Firebase project wiring (iOS + local emulators)

### Task 1: Add Firebase to the iOS project

**Files:**
- Modify: Xcode project settings (no file path)
- Add: `rent-a-car/GoogleService-Info.plist` (downloaded)

- [ ] **Step 1: Create Firebase project + iOS app**
  - Firebase Console → Add app (iOS)
  - Bundle ID must match Xcode target
  - Download `GoogleService-Info.plist`

- [ ] **Step 2: Add `GoogleService-Info.plist` to Xcode**
  - Drag into Xcode project
  - Ensure it’s in the correct target
  - Ensure it appears in “Copy Bundle Resources”

- [ ] **Step 3: Add Firebase SDK via Swift Package Manager**
  - Add package: `https://github.com/firebase/firebase-ios-sdk`
  - Products (MVP):
    - `FirebaseAuth`
    - `FirebaseFirestore`
    - `FirebaseFunctions`

- [ ] **Step 4: Run app to verify Firebase initializes**
  - Expected: app launches without crash
  - If crash: plist missing or wrong target/bundle id mismatch

- [ ] **Step 5: Commit**

```bash
git add rent-a-car/rent_a_carApp.swift docs/superpowers/specs/2026-03-17-rent-a-car-full-prepaid-design.md
git commit -m "chore: prepare app for Firebase integration"
```

### Task 2: Enable Phone OTP auth (Firebase)

**Files:**
- N/A (console + iOS code later)

- [ ] **Step 1: Firebase Console → Authentication → Sign-in method**
  - Enable **Phone**
  - Add test phone numbers for development

---

## Chunk 2: Define Firestore schema + security rules

### Task 3: Write Firestore rules (MVP-safe)

**Files:**
- Create: `firestore.rules`

- [ ] **Step 1: Write rules that allow**
  - Signed-in users:
    - Read `cars` where `isActive == true`
    - Create their own `bookings` with `userId == request.auth.uid`
    - Read their own bookings
  - Admin (temporary approach for MVP):
    - Gate admin actions via a custom claim `admin == true` OR a hardcoded allowlist of UIDs in rules (short-term only).

- [ ] **Step 2: Add minimal deny-by-default posture**
  - No public writes to `cars`
  - No writing booking status transitions from client (status changes done via Functions)

- [ ] **Step 3: Deploy rules**

```bash
firebase deploy --only firestore:rules
```

- [ ] **Step 4: Commit**

```bash
git add firestore.rules
git commit -m "chore: add Firestore rules for cars and bookings"
```

### Task 4: Firestore indexes (only if queries require)

**Files:**
- Create: `firestore.indexes.json` (only if Firebase prompts for index)

- [ ] **Step 1: Implement browsing queries first**
  - Only add indexes when Firestore error gives the direct index link.

---

## Chunk 3: Implement phone OTP sign-in UI (SwiftUI)

### Task 5: Add `AuthService` and Phone OTP screens

**Files:**
- Create: `rent-a-car/Services/Firebase/AuthService.swift`
- Create: `rent-a-car/Views/Auth/PhoneAuthView.swift`
- Modify: `rent-a-car/rent_a_carApp.swift` (route to auth vs app root)

- [ ] **Step 1: Write the failing test (basic formatting/validation)**

Create `rent-a-carTests/PhoneAuthValidationTests.swift` with tests for:
- phone normalization (E.164)
- empty code handling

- [ ] **Step 2: Run tests to see failure**
  - Run in Xcode: `rent-a-carTests`

- [ ] **Step 3: Implement `AuthService`**
  - `sendOTP(phone: String) async throws -> verificationId`
  - `verifyOTP(verificationId: String, code: String) async throws`
  - `currentUser` publisher/async stream

- [ ] **Step 4: Implement `PhoneAuthView`**
  - Two-step UI: phone entry → code entry
  - Use Firebase Auth’s phone verification
  - Add clear error states + resend timer

- [ ] **Step 5: Route app**
  - If not authenticated → show `PhoneAuthView`
  - Else → show `AppRootView`

- [ ] **Step 6: Run tests and app**
  - Expected: can sign in using test phone numbers

- [ ] **Step 7: Commit**

```bash
git add rent-a-car/Services/Firebase/AuthService.swift rent-a-car/Views/Auth/PhoneAuthView.swift rent-a-car/rent_a_carApp.swift rent-a-carTests
git commit -m "feat: add phone OTP authentication"
```

---

## Chunk 4: Firestore models + read-only inventory browsing

### Task 6: Add Firestore models and car repository

**Files:**
- Create: `rent-a-car/Models/Firestore/CarDoc.swift`
- Create: `rent-a-car/Services/Firebase/FirestoreService.swift`
- Modify: `rent-a-car/MapView.swift`

- [ ] **Step 1: Write failing tests for decoding `CarDoc`**
  - Ensure required fields decode (name, dailyRate, location)

- [ ] **Step 2: Implement `CarDoc`**
  - Include `id`, `name`, `type`, `dailyRate`, `location`, `photos`, `isActive`

- [ ] **Step 3: Implement `FirestoreService`**
  - `listenActiveCars() -> AsyncStream<[CarDoc]>` (or Combine publisher)

- [ ] **Step 4: Update `MapView`**
  - Replace `@Query var cars: [CarModel]` with a view model fed by Firestore
  - Keep existing UI layout; swap data source

- [ ] **Step 5: Run app**
  - Expected: map loads cars from Firestore

- [ ] **Step 6: Commit**

```bash
git add rent-a-car/Models/Firestore/CarDoc.swift rent-a-car/Services/Firebase/FirestoreService.swift rent-a-car/MapView.swift rent-a-carTests
git commit -m "feat: load car inventory from Firestore"
```

---

## Chunk 5: Booking rules (availability) + Firestore booking documents

### Task 7: Define booking overlap logic and tests

**Files:**
- Create: `rent-a-car/Models/Firestore/BookingDoc.swift`
- Create: `rent-a-car/Services/Bookings/BookingService.swift`
- Test: `rent-a-carTests/AvailabilityTests.swift`

- [ ] **Step 1: Write failing overlap tests**
  - Same car, overlapping ranges → unavailable
  - Touching boundaries (end == start) → define rule and test it

- [ ] **Step 2: Implement overlap predicate**
  - Decide: treat rentals as half-open \([start, end)\) to avoid double-booking at boundaries.

- [ ] **Step 3: Implement `BookingDoc`**
  - `status` includes `pending_payment`
  - include pricing breakdown

- [ ] **Step 4: Implement booking read APIs**
  - Fetch user bookings
  - Fetch bookings for a car over a date range (server-side will do final enforcement)

- [ ] **Step 5: Commit**

```bash
git add rent-a-car/Models/Firestore/BookingDoc.swift rent-a-car/Services/Bookings/BookingService.swift rent-a-carTests/AvailabilityTests.swift
git commit -m "feat: add booking model and availability utilities"
```

---

## Chunk 6: Stripe + Cloud Functions for full prepaid checkout

### Task 8: Set up Cloud Functions project

**Files:**
- Create: `functions/package.json`
- Create: `functions/src/index.ts`
- Create: `functions/src/stripe.ts`
- Create: `functions/src/bookings.ts`

- [ ] **Step 1: Initialize Firebase Functions**

```bash
firebase init functions
```

- [ ] **Step 2: Add Stripe dependency**

```bash
cd functions && npm install stripe
```

- [ ] **Step 3: Store Stripe secrets**
  - Use Firebase environment config or Secret Manager (preferred).

- [ ] **Step 4: Commit**

```bash
git add functions
git commit -m "chore: initialize Firebase Cloud Functions for payments"
```

### Task 9: Implement booking + payment flow (server-authoritative)

**Files:**
- Modify: `functions/src/bookings.ts`
- Modify: `functions/src/stripe.ts`
- Modify: `functions/src/index.ts`

- [ ] **Step 1: Write unit tests for date overlap + idempotency (optional but recommended)**

- [ ] **Step 2: Implement callable/HTTPS function `createBookingPaymentIntent`**
Inputs:
- `carId`
- `startAt`, `endAt`
- client-calculated price fields are treated as *suggestions*; server recomputes totals.

Behavior:
- Validate auth
- Validate availability (query bookings for overlap; enforce canonical overlap rule)
- Create `bookings/{id}` with `pending_payment`
- Create Stripe PaymentIntent for **USD** total, with metadata `{bookingId, userId, carId}`
- Return `clientSecret`

- [ ] **Step 3: Implement Stripe webhook `payment_intent.succeeded`**
Behavior:
- Look up `bookingId` from metadata
- Transactionally update booking status to `confirmed`
- Ensure idempotency (webhook retries)

- [ ] **Step 4: Implement webhook failure/cancel handling**
- If PaymentIntent fails/canceled: mark booking `cancelled` (or delete pending booking) safely.

- [ ] **Step 5: Deploy Functions**

```bash
firebase deploy --only functions
```

- [ ] **Step 6: Commit**

```bash
git add functions/src
git commit -m "feat: create Stripe PaymentIntent and confirm bookings via webhook"
```

---

## Chunk 7: iOS checkout integration (real card payment)

### Task 10: Add Stripe iOS SDK + checkout service

**Files:**
- Create: `rent-a-car/Services/Payments/StripeCheckoutService.swift`
- Modify: `rent-a-car/RentCheckoutView.swift`
- Modify: `rent-a-car/AddCardView.swift` (or replace with Stripe PaymentSheet)

- [ ] **Step 1: Add Stripe SDK via SPM**
  - Add package: `https://github.com/stripe/stripe-ios`

- [ ] **Step 2: Implement `StripeCheckoutService`**
  - Calls Firebase Function `createBookingPaymentIntent`
  - Presents Stripe PaymentSheet using returned `clientSecret`

- [ ] **Step 3: Update `RentCheckoutView`**
  - Replace “Payment Method” with card-only for MVP
  - On “Reserve”: call `createBookingPaymentIntent`, present PaymentSheet
  - After success: navigate to `BookingDetailView` for that booking

- [ ] **Step 4: Run end-to-end on Stripe test mode**
  - Expected: payment succeeds, webhook confirms booking, booking shows confirmed.

- [ ] **Step 5: Commit**

```bash
git add rent-a-car/Services/Payments/StripeCheckoutService.swift rent-a-car/RentCheckoutView.swift rent-a-car/AddCardView.swift
git commit -m "feat: full prepaid booking checkout with Stripe"
```

---

## Chunk 8: Bookings UI + admin fleet management to Firestore

### Task 11: Booking detail + list

**Files:**
- Create: `rent-a-car/Views/Bookings/BookingDetailView.swift`
- Create: `rent-a-car/Views/Bookings/MyBookingsView.swift` (optional)
- Modify: `rent-a-car/WalletView.swift` (repurpose to account/bookings entry point)

- [ ] **Step 1: Implement booking detail timeline UI**
- [ ] **Step 2: Add “My bookings” list**
- [ ] **Step 3: Link from wallet/account area**
- [ ] **Step 4: Commit**

```bash
git add rent-a-car/Views/Bookings rent-a-car/WalletView.swift
git commit -m "feat: booking detail and history screens"
```

### Task 12: Admin: create/update cars in Firestore

**Files:**
- Modify: `rent-a-car/AdminView.swift`
- Modify: `rent-a-car/VehicleFormView.swift`

- [ ] **Step 1: Implement admin create car**
  - Uploading photos can be phase 2; MVP can store URLs or use bundled placeholders.

- [ ] **Step 2: Gate admin**
  - MVP: allowlist UID in app build config (temporary) + rules

- [ ] **Step 3: Commit**

```bash
git add rent-a-car/AdminView.swift rent-a-car/VehicleFormView.swift
git commit -m "feat: admin can manage fleet inventory in Firestore"
```

---

## Chunk 9: Cancellation + refunds (policy-enforced)

### Task 13: Cancellation endpoint + Stripe refunds

**Files:**
- Modify: `functions/src/bookings.ts`
- Modify: `functions/src/stripe.ts`
- Modify: `rent-a-car/Views/Bookings/BookingDetailView.swift`

- [ ] **Step 1: Define MVP cancellation policy**
  - Example: full refund within 24h of booking if pickup > 48h away; otherwise partial.
  - Encode as deterministic function in backend.

- [ ] **Step 2: Implement HTTPS callable `cancelBooking`**
  - Validate auth owns booking
  - Compute refund amount by policy
  - Create Stripe refund
  - Update booking `cancelled` + refund metadata

- [ ] **Step 3: Add UI to cancel**
  - Show refund amount before confirming

- [ ] **Step 4: Deploy + test**

- [ ] **Step 5: Commit**

```bash
git add functions/src rent-a-car/Views/Bookings/BookingDetailView.swift
git commit -m "feat: cancellation and Stripe refunds with policy enforcement"
```

---

## Final verification checklist

- [ ] Create at least 3 cars in Firestore (`isActive: true`) and confirm they appear on map.
- [ ] Complete a full prepaid booking using Stripe test card.
- [ ] Confirm booking becomes `confirmed` only after webhook runs.
- [ ] Attempt double-booking same car/overlapping dates and confirm it is blocked.
- [ ] Cancel a booking and confirm refund + booking state update.

---

## Notes / decisions locked in
- Currency: **USD**
- Auth: **Phone OTP**
- Data: **Firestore** as source of truth (SwiftData is demo-only unless later used as cache).

