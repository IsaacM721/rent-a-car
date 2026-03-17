# MotoresRD — Spec
**Uber Moto for the Dominican Republic. 5% commission per ride.**

---

## Stack
- **iOS** SwiftUI + Swift (single app, no Android)
- **Backend** Firebase: Auth (phone OTP), Firestore, Realtime Database, Cloud Functions, FCM
- **Maps** MapKit (Apple, free, built-in)
- **Payments** Stripe iOS SDK + Stripe Connect (card); manual weekly settlement (cash)
- **Domain** motores.rd (Namecheap)

---

## App Structure
One iOS app. Rider mode is default. Driver mode is hidden — unlocked by tapping the logo 7 times then entering a secret driver code.

### Rider Flow
1. Onboarding: phone number → SMS OTP → profile (name, photo)
2. Home: MapKit map showing available driver dots
3. Request: tap destination → auto-detect zone → show fixed price → confirm
4. Matching: Cloud Function assigns nearest available driver
5. Tracking: live driver location on map via Realtime DB
6. Arrival → ride → completion
7. Payment: cash or card (Stripe)
8. Rate driver (1–5 stars)

### Driver Flow
1. Same auth as rider (phone OTP)
2. Registration: name, cedula, moto plate, photo — requires admin approval
3. Go online/offline toggle
4. Incoming request: push notification with pickup + dropoff + price → accept or decline (30s)
5. Navigate to rider (MapKit directions)
6. Start ride → end ride
7. Earnings dashboard: per-ride breakdown, weekly balance, 5% owed (cash) or auto-deducted (card)

---

## Pricing
- **Model**: Fixed zones — Santo Domingo only at launch
- **Zone matrix**: Firestore collection `zones` maps zone pairs to RD$ prices
- **Example**: Zona Colonial → Piantini = RD$250, within same zone = RD$150
- Prices editable by admin without app update

---

## Monetization
- **5% per ride**, always
- **Card rides**: Stripe Connect splits instantly — 95% to driver, 5% to MotoresRD Stripe account
- **Cash rides**: Firestore tracks driver balance. Weekly: drivers pay balance via card/transfer. If unpaid, account suspended.

---

## Data Models (Firestore)

```
users/{uid}
  name, phone, photoURL, role: "rider"|"driver", createdAt

drivers/{uid}
  cedula, motoPlate, approved: bool, online: bool, rating, totalRides, balance (cash owed)

rides/{rideId}
  riderId, driverId, pickupZone, dropoffZone, price, status, paymentMethod, createdAt, completedAt

zones/{zoneId}
  name, polygon (GeoJSON), neighborhoodNames[]

pricing/{pairId}
  fromZone, toZone, priceDOP

/locations/{driverId}  ← Realtime DB (not Firestore)
  lat, lng, updatedAt
```

---

## Firebase Cloud Functions
- `matchRide(rideId)` — finds nearest online driver within 3km, sends FCM
- `completeRide(rideId)` — calculates 5%, updates balances, triggers Stripe if card
- `approveDriver(uid)` — admin-callable, flips approved flag

---

## Push Notifications (FCM)
- Driver: new ride request (30s to accept)
- Rider: driver accepted, driver arrived, ride started, ride completed
- Both: system messages

---

## MVP Scope (v1.0)
**In:**
- Phone auth, rider home + request flow, driver accept + navigate flow
- Live map tracking, fixed zone pricing, cash + card payment
- Driver approval, ratings, earnings dashboard

**Out (post-launch):**
- Surge pricing, scheduled rides, multiple stops, chat, referral codes, Santiago zones

---

## Project Location
`/Users/isaacmendezrosario/rent-a-car/` — existing Xcode project (SwiftUI + SwiftData)
Reference files: `CarModel.swift`, `MapView.swift`, `WalletView.swift`, `PayWithDOPView.swift`
