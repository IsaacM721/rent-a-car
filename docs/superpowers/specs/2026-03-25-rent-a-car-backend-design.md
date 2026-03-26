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

Single Hono monolith deployed as one Cloudflare Worker. Route modules are split by domain (auth, vehicles, bookings, payments, users). D1 and R2 are bound via `wrangler.toml` and accessed via `env.DB` and `env.BUCKET`.

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
    r2.ts           — image upload/delete helpers
    twilio.ts       — OTP send wrapper
    stripe.ts       — PaymentIntent + webhook helpers
  types.ts          — shared TypeScript types / Bindings
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
| dealer_id | INTEGER | stub for future dealer table |
| name | TEXT | |
| type | TEXT | e.g. "Sedan", "SUV", "Truck" |
| price_level | TEXT | e.g. "$", "$$", "$$$" |
| neighborhood | TEXT | |
| is_available | INTEGER | 0 or 1 |
| available_from | TEXT | e.g. "9:00 AM" |
| details | TEXT | description |
| schedule_json | TEXT | JSON array of DaySchedule |
| address | TEXT | |
| latitude | REAL | |
| longitude | REAL | |
| logo_color_r | REAL | 0.0–1.0 |
| logo_color_g | REAL | 0.0–1.0 |
| logo_color_b | REAL | 0.0–1.0 |
| logo_initials | TEXT | |
| created_at | TEXT | ISO 8601 |

### `vehicle_images`
| Column | Type | Notes |
|---|---|---|
| id | TEXT (UUID) | PK |
| vehicle_id | TEXT | FK → vehicles.id |
| r2_key | TEXT | R2 object key |
| display_order | INTEGER | for ordering images |

### `bookings`
| Column | Type | Notes |
|---|---|---|
| id | TEXT (UUID) | PK |
| user_id | TEXT | FK → users.id |
| vehicle_id | TEXT | FK → vehicles.id |
| start_date | TEXT | ISO 8601 date |
| end_date | TEXT | ISO 8601 date |
| status | TEXT | `pending`, `confirmed`, `cancelled`, `failed` |
| stripe_payment_intent_id | TEXT | nullable |
| total_amount_cents | INTEGER | in smallest currency unit |
| currency | TEXT | `"usd"` or `"dop"` |
| created_at | TEXT | ISO 8601 |

---

## API Endpoints

### Auth
| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/auth/otp/send` | None | Send SMS OTP via Twilio Verify |
| POST | `/auth/otp/verify` | None | Verify OTP → return signed JWT |

### Users
| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/users/me` | JWT | Get current user profile |
| PUT | `/users/me` | JWT | Update name or profile pic |

### Vehicles
| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/vehicles` | None | List all vehicles (filterable by type, is_available) |
| GET | `/vehicles/:id` | None | Get single vehicle with images and schedule |
| POST | `/vehicles` | Admin JWT | Create vehicle |
| PUT | `/vehicles/:id` | Admin JWT | Update vehicle |
| DELETE | `/vehicles/:id` | Admin JWT | Delete vehicle + its R2 images |

### Vehicle Images
| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/vehicles/:id/images` | Admin JWT | Upload image to R2, register in D1 |
| DELETE | `/vehicles/:id/images/:imageId` | Admin JWT | Delete image from R2 + D1 |

### Bookings
| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/bookings` | JWT | Create booking + Stripe PaymentIntent |
| GET | `/bookings/me` | JWT | List authenticated user's bookings |
| GET | `/bookings/:id` | JWT | Get booking detail |
| POST | `/bookings/:id/cancel` | JWT | Cancel booking |

### Payments
| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/payments/webhook` | Stripe-Signature | Confirm or fail bookings on Stripe events |

---

## Auth & Security

- Phone number → Twilio Verify → 6-digit OTP
- `POST /auth/otp/verify` returns a signed JWT (HS256, 24h expiry)
- JWT payload: `{ user_id, phone, role }`
- All protected routes use Hono's JWT middleware checking `Authorization: Bearer <token>`
- Admin endpoints return 403 if `role !== "admin"`
- Stripe webhook verifies `Stripe-Signature` header before processing any event

---

## iOS App Integration

The Swift app replaces SwiftData local reads with `URLSession` calls to this API. Response JSON shapes match the existing `CarModel` fields directly.

| Swift View | Backend Call |
|---|---|
| ContentView / WalletView offers | `GET /vehicles` |
| CarDetailView | `GET /vehicles/:id` |
| MapView | `GET /vehicles` (lat/lng in response) |
| AdminView | `POST/PUT/DELETE /vehicles` |
| VehicleFormView | `POST/PUT /vehicles` + image upload |
| PayWithDOPView | `POST /bookings` → Stripe |
| WalletView activity | `GET /bookings/me` |

Per-user private data (saved vehicles, wallet balance) stays in CloudKit.

---

## Scope Notes

- **V1 catalog:** 3 vehicle types, 1 model per type, seeded via D1 migration
- **No dealer table yet:** `dealer_id` is an integer stub on `vehicles` for future use
- **Business app:** A separate iOS app for dealers is planned for a future phase; the backend will add dealer auth (dealer JWT role) and dealer-scoped vehicle management at that point
- **Image storage:** Cloudflare R2, public bucket, URLs returned directly in vehicle responses
- **Currency:** Stripe handles USD; DOP display is client-side conversion only in v1
