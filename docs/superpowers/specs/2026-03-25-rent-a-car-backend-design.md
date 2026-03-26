# Rent-a-Car Backend Design Spec

**Date:** 2026-03-25
**Project:** MOTORES — Rent-a-Car Marketplace
**Status:** Approved

---

## Overview

A REST API backend for the MOTORES iOS rent-a-car marketplace app. The backend handles vehicle listings, bookings, payments, and user authentication. Per-user private data (saved vehicles, wallet balance, activity history) is handled by CloudKit on the iOS side.

The backend is a single Hono app deployed as a Cloudflare Worker, with Cloudflare D1 (SQLite) for the database and Cloudflare R2 for image storage.

---

## Stack

| Layer | Technology |
|---|---|
| Runtime | Cloudflare Workers |
| Framework | Hono |
| Database | Cloudflare D1 (SQLite) |
| Image storage | Cloudflare R2 |
| SMS OTP | Twilio Verify |
| Payments | Stripe |
| Auth | JWT (HS256) |
| Local dev | Wrangler + Multipass (Ubuntu VM) |
| Deploy | `wrangler deploy` → Cloudflare edge |

---

## Architecture

Single Hono monolith deployed as one Cloudflare Worker. Route modules are split by domain (auth, vehicles, bookings, payments, users). D1 and R2 are bound via `wrangler.toml` and accessed via `env.DB` (D1) and `env.BUCKET` (R2). The JWT signing secret is stored as a Cloudflare Worker secret via `wrangler secret put JWT_SECRET` — never committed to `wrangler.toml`.

```
wrangler.toml
src/
  index.ts          — app entry, registers all routers
  routes/
    auth.ts         — OTP send/verify, JWT issuance
    users.ts        — profile read/update
    vehicles.ts     — CRUD + image upload
    bookings.ts     — create, list, cancel
    payments.ts     — Stripe webhook
  middleware/
    auth.ts         — JWT verification, role check
  lib/
    d1.ts           — typed query helpers
    r2.ts           — pre-signed URL generation, delete helpers
    twilio.ts       — OTP send wrapper
    stripe.ts       — PaymentIntent + webhook helpers
  types.ts          — shared TypeScript types / Bindings
```

### wrangler.toml bindings

```toml
[[d1_databases]]
binding = "DB"
database_name = "motores-db"
database_id = "<uuid>"

[[r2_buckets]]
binding = "BUCKET"
bucket_name = "motores-images"
```

---

## Data Model (D1)

### `users`
| Column | Type | Notes |
|---|---|---|
| id | TEXT (UUID) | PK |
| phone | TEXT | unique, E.164 format |
| name | TEXT | nullable |
| profile_pic_url | TEXT | nullable, R2 public URL |
| role | TEXT | `"user"` or `"admin"` |
| created_at | TEXT | ISO 8601 |

### `vehicles`
| Column | Type | Notes |
|---|---|---|
| id | TEXT (UUID) | PK |
| dealer_id | INTEGER | nullable stub — null in v1; reserved for future dealer table |
| name | TEXT | |
| type | TEXT | e.g. "Sedan", "SUV", "Truck" |
| price_level | TEXT | e.g. "$", "$$", "$$$" |
| daily_rate_cents | INTEGER | authoritative price; server uses this for booking totals |
| neighborhood | TEXT | |
| is_active | INTEGER | 0 or 1 — controls visibility in listings (soft delete) |
| is_available | INTEGER | 0 or 1 — real-time availability badge |
| available_from | TEXT | e.g. "9:00 AM", shown when is_available = 0 |
| details | TEXT | description |
| schedule_json | TEXT | JSON array of DaySchedule (`[{day, open, close, closed}]`) |
| address | TEXT | |
| latitude | REAL | |
| longitude | REAL | |
| logo_color_r | REAL | 0.0–1.0 |
| logo_color_g | REAL | 0.0–1.0 |
| logo_color_b | REAL | 0.0–1.0 |
| logo_initials | TEXT | |
| created_at | TEXT | ISO 8601 |

`GET /vehicles` filters on `is_active = 1` only. `is_available` controls the availability badge but does not hide the listing.

### `vehicle_images`
| Column | Type | Notes |
|---|---|---|
| id | TEXT (UUID) | PK |
| vehicle_id | TEXT | FK → vehicles.id |
| r2_key | TEXT | R2 object key (e.g. `vehicles/{vehicle_id}/{uuid}.jpg`) |
| display_order | INTEGER | ascending sort order |
| is_confirmed | INTEGER | 0 or 1 (default 0) — set to 1 after client confirms upload. `GET /vehicles` only includes images where `is_confirmed = 1`. |

### `bookings`
| Column | Type | Notes |
|---|---|---|
| id | TEXT (UUID) | PK |
| user_id | TEXT | FK → users.id |
| vehicle_id | TEXT | FK → vehicles.id |
| start_date | TEXT | ISO 8601 date (`YYYY-MM-DD`) |
| end_date | TEXT | ISO 8601 date (`YYYY-MM-DD`) |
| status | TEXT | `pending`, `confirmed`, `cancelled`, `failed` |
| stripe_payment_intent_id | TEXT | unique; used for webhook idempotency |
| subtotal_cents | INTEGER | daily_rate_cents × days |
| service_fee_cents | INTEGER | 10% of subtotal_cents |
| total_amount_cents | INTEGER | subtotal + service_fee |
| currency | TEXT | always `"usd"` in v1 (DOP is client-side display conversion only) |
| created_at | TEXT | ISO 8601 |

---

## API Endpoints

### Auth
| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/auth/otp/send` | None | Send SMS OTP via Twilio Verify. Rate limited to 3 requests per phone per 10 minutes. |
| POST | `/auth/otp/verify` | None | Verify OTP → return signed JWT (24h). |

**`POST /auth/otp/send` body:**
```json
{ "phone": "+18095551234" }
```

**`POST /auth/otp/verify` body + response:**
```json
// Request
{ "phone": "+18095551234", "code": "123456" }

// Response 200
{ "token": "<jwt>", "user": { "id": "uuid", "phone": "+18095551234", "name": null, "role": "user" } }
```

---

### Users
| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/users/me` | JWT | Get current user profile |
| PUT | `/users/me` | JWT | Update name or profile pic URL |

**`GET /users/me` response:**
```json
{ "id": "uuid", "phone": "+18095551234", "name": "Isaac M", "profile_pic_url": null, "role": "user" }
```

**`PUT /users/me` body** (all fields optional):
```json
{ "name": "Isaac M", "profile_pic_url": "https://pub-xxx.r2.dev/users/uuid/avatar.jpg" }
```
`role` is not an accepted field and is ignored if sent.

---

### Vehicles
| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/vehicles` | None | List all active vehicles. Supports `?type=Sedan` and `?available=true` filters. |
| GET | `/vehicles/:id` | None | Get single vehicle with embedded images array and schedule. |
| POST | `/vehicles` | Admin JWT | Create vehicle. |
| PUT | `/vehicles/:id` | Admin JWT | Update vehicle fields. |
| DELETE | `/vehicles/:id` | Admin JWT | Soft-delete (`is_active = 0`) + delete all R2 images. |

**`GET /vehicles` response:**
```json
[
  {
    "id": "uuid",
    "name": "Toyota Corolla",
    "type": "Sedan",
    "price_level": "$",
    "daily_rate_cents": 3000,
    "neighborhood": "Piantini",
    "is_available": true,
    "available_from": "9:00 AM",
    "details": "...",
    "schedule": [...],
    "address": "Av. Abraham Lincoln 123",
    "latitude": 18.4861,
    "longitude": -69.9312,
    "logo": { "r": 0.2, "g": 0.2, "b": 0.8, "initials": "TC" },
    "images": [
      { "id": "uuid", "url": "https://pub-xxx.r2.dev/vehicles/uuid/img.jpg", "display_order": 0 }
    ]
  }
]
```

`GET /vehicles/:id` returns the same shape for a single object.

**`POST /vehicles` body:**
```json
{
  "name": "Toyota Corolla",
  "type": "Sedan",
  "price_level": "$",
  "daily_rate_cents": 3000,
  "neighborhood": "Piantini",
  "is_available": true,
  "available_from": "9:00 AM",
  "details": "...",
  "schedule": [...],
  "address": "Av. Abraham Lincoln 123",
  "latitude": 18.4861,
  "longitude": -69.9312,
  "logo": { "r": 0.2, "g": 0.2, "b": 0.8, "initials": "TC" }
}
```

---

### Vehicle Images

R2 images are uploaded directly from the iOS client using a pre-signed URL. The flow is:

1. **iOS → `POST /vehicles/:id/images/presign`** — server generates a pre-signed R2 PUT URL and returns it along with the future public URL and the image record ID.
2. **iOS → R2** — client PUTs the image binary directly to R2 using the pre-signed URL.
3. **iOS → `POST /vehicles/:id/images/confirm/:imageId`** — client confirms the upload; server marks the image as active.

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/vehicles/:id/images/presign` | Admin JWT | Returns a pre-signed R2 PUT URL + image record ID |
| POST | `/vehicles/:id/images/confirm/:imageId` | Admin JWT | Marks image upload as complete |
| DELETE | `/vehicles/:id/images/:imageId` | Admin JWT | Deletes image from R2 + D1 |
| PUT | `/vehicles/:id/images/reorder` | Admin JWT | Updates `display_order` for image array |

**`POST /vehicles/:id/images/presign` response:**
```json
{
  "image_id": "uuid",
  "upload_url": "https://...(pre-signed R2 PUT URL, expires 15min)...",
  "public_url": "https://pub-xxx.r2.dev/vehicles/uuid/img-uuid.jpg"
}
```

---

### Bookings
| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/bookings` | JWT | Create booking + Stripe PaymentIntent. Validates date overlap. |
| GET | `/bookings/me` | JWT | List authenticated user's bookings |
| GET | `/bookings/:id` | JWT | Get booking detail |
| POST | `/bookings/:id/cancel` | JWT | Cancel booking (only if status = `pending` or `confirmed` before pickup) |

**`POST /bookings` — server-side logic:**
1. Look up `vehicle.daily_rate_cents`.
2. Check no existing `confirmed` or `pending` booking for that vehicle overlaps `start_date`–`end_date`. Return 409 if conflict.
3. Compute: `subtotal = daily_rate_cents × days`, `service_fee = subtotal × 0.10`, `total = subtotal + service_fee`.
4. Create Stripe PaymentIntent for `total` in USD.
5. Insert booking with `status = "pending"`.
6. Return booking + `client_secret` for Stripe SDK on iOS.

**`POST /bookings` request:**
```json
{ "vehicle_id": "uuid", "start_date": "2026-04-01", "end_date": "2026-04-05" }
```

**`POST /bookings` response:**
```json
{
  "booking_id": "uuid",
  "subtotal_cents": 12000,
  "service_fee_cents": 1200,
  "total_amount_cents": 13200,
  "currency": "usd",
  "stripe_client_secret": "pi_xxx_secret_xxx",
  "status": "pending"
}
```

---

### Payments
| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/payments/webhook` | Stripe-Signature | Confirm or fail bookings on Stripe events |

**Webhook idempotency:** Before mutating any booking, the handler checks whether a booking with the given `stripe_payment_intent_id` is already in the target state. If so, it returns 200 immediately without re-processing. This prevents duplicate state changes from Stripe retries.

Handled events:
- `payment_intent.succeeded` → set booking `status = "confirmed"`
- `payment_intent.payment_failed` → set booking `status = "failed"`

---

## Auth & Security

- Phone number → Twilio Verify → 6-digit OTP (rate limited: 3 sends per phone per 10 min)
- `POST /auth/otp/verify` returns a signed JWT (HS256, 24h expiry)
- JWT payload: `{ user_id, phone, role }`
- JWT signing secret stored as a Cloudflare Worker secret (`wrangler secret put JWT_SECRET`) — not in `wrangler.toml`
- All protected routes use Hono's JWT middleware: `Authorization: Bearer <token>`
- Admin endpoints return 403 if `role !== "admin"`
- Stripe webhook validates `Stripe-Signature` header before processing any event
- **Token refresh:** deferred from v1. On 401, the iOS app re-triggers the OTP flow. This is acceptable for v1 given OTP is low-friction.

---

## iOS App Integration

The Swift app replaces SwiftData local reads with `URLSession` calls to this API. Response JSON shapes are designed to map directly to the existing `CarModel` Swift struct.

| Swift View | Backend Call |
|---|---|
| ContentView / WalletView offers | `GET /vehicles` |
| CarDetailView | `GET /vehicles/:id` |
| MapView | `GET /vehicles` (lat/lng in response) |
| AdminView | `POST/PUT/DELETE /vehicles` |
| VehicleFormView | `POST/PUT /vehicles` + presign/confirm image flow |
| PayWithDOPView | `POST /bookings` → Stripe client secret |
| WalletView activity | `GET /bookings/me` |

**DOP display:** The API always returns amounts in USD cents. The iOS client converts to DOP for display using a hardcoded or fetched exchange rate. No DOP amounts are stored on the backend.

Per-user private data (saved vehicles, wallet balance) stays in CloudKit.

---

## Scope Notes

- **V1 catalog:** 3 vehicle types, 1 model per type, seeded via D1 migration
- **`dealer_id`:** nullable INTEGER on `vehicles`, always null in v1. Not included in public API responses. Reserved for the future dealer table when the business app is built.
- **Business app:** A separate iOS app for dealers is planned for phase 2. The backend will add dealer auth (dealer JWT role) and dealer-scoped vehicle management at that point.
- **Image storage:** Cloudflare R2, public bucket, public URLs embedded in vehicle responses.
- **Token refresh:** deferred. iOS handles 401 by re-triggering OTP.
- **Pagination:** deferred. `GET /vehicles` returns all active vehicles. Acceptable for v1 with 3 vehicles; add `?limit=&cursor=` in phase 2.
