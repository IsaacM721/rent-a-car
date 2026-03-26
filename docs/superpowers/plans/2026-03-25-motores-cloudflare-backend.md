# MOTORES Cloudflare Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the MOTORES REST API on Cloudflare Workers (Hono + D1 + R2 + Twilio + Stripe) and wire the existing iOS app to it, replacing Firebase/Firestore.

**Architecture:** Single Hono Worker in `motores-api/` handles auth, vehicles, bookings, and payments. D1 stores all shared data. R2 stores vehicle images uploaded via pre-signed URLs. The iOS app replaces `CarsRepository` (Firestore) with `MotoresAPIClient` (URLSession). Firebase Auth is replaced by phone OTP → JWT issued by the Worker.

**Tech Stack:** Hono 4, Cloudflare Workers, D1 (SQLite), R2, Twilio Verify, Stripe, `@cloudflare/vitest-pool-workers` for tests. iOS side: Swift Concurrency, URLSession, Keychain for JWT storage.

**Spec:** `docs/superpowers/specs/2026-03-25-rent-a-car-backend-design.md`

---

## File Map

### New: `motores-api/` (Cloudflare Worker)

| File | Responsibility |
|---|---|
| `wrangler.toml` | Worker name, D1 + R2 bindings, routes |
| `package.json` | Hono, Stripe, Twilio, Wrangler, Vitest deps |
| `tsconfig.json` | Worker-compatible TypeScript config |
| `vitest.config.ts` | `@cloudflare/vitest-pool-workers` setup |
| `src/types.ts` | `Env` bindings type + shared interfaces (`CarRow`, `BookingRow`, etc.) |
| `src/index.ts` | App entry — mounts all route modules |
| `src/middleware/auth.ts` | JWT verify middleware + admin role guard |
| `src/middleware/rateLimit.ts` | OTP send rate limiter (D1-backed: 3/phone/10min) |
| `src/lib/jwt.ts` | Sign + verify JWT using Web Crypto (HS256) |
| `src/lib/d1.ts` | Typed D1 query helpers (`getVehicle`, `listVehicles`, etc.) |
| `src/lib/r2.ts` | Pre-signed URL generation + delete helper |
| `src/lib/twilio.ts` | Twilio Verify send + check wrappers |
| `src/lib/stripe.ts` | PaymentIntent creation + webhook signature verify |
| `src/routes/auth.ts` | `POST /auth/otp/send`, `POST /auth/otp/verify` |
| `src/routes/users.ts` | `GET /users/me`, `PUT /users/me` |
| `src/routes/vehicles.ts` | `GET /vehicles`, `GET /vehicles/:id`, `POST/PUT/DELETE /vehicles/:id` |
| `src/routes/images.ts` | Presign, confirm, delete, reorder image routes |
| `src/routes/bookings.ts` | `POST/GET /bookings`, cancel |
| `src/routes/payments.ts` | `POST /payments/webhook` |
| `migrations/0001_init.sql` | D1 schema: all 4 tables |
| `migrations/0002_seed.sql` | 3 seed vehicles |
| `test/auth.test.ts` | OTP flow + JWT tests |
| `test/vehicles.test.ts` | CRUD + image flow tests |
| `test/bookings.test.ts` | Booking creation, conflict, cancel tests |
| `test/payments.test.ts` | Webhook idempotency tests |

### Modified: iOS `rent-a-car/rent-a-car/`

| File | Change |
|---|---|
| `Models/Car.swift` | Remove `@DocumentID`, add `dailyRateCents`, `schedule: [DaySchedule]`, `imageURLs: [String]` |
| `Services/MotoresAPI/MotoresAPIClient.swift` | **New** — URLSession base client, base URL, auth header injection |
| `Services/MotoresAPI/AuthAPIService.swift` | **New** — OTP send/verify, JWT save/load from Keychain |
| `Services/MotoresAPI/VehiclesAPIService.swift` | **New** — fetch all vehicles, fetch single, admin CRUD + image upload |
| `Services/MotoresAPI/BookingsAPIService.swift` | **New** — create booking, list, cancel |
| `Services/Firebase/CarsRepository.swift` | Replace Firestore calls with `VehiclesAPIService` calls (keep file, swap internals) |
| `Stores/CarsStore.swift` | Remove `ListenerRegistration`, use `async` fetch on `start()` |
| `Views/Auth/PhoneAuthView.swift` | **New** — phone entry + OTP code entry, calls `AuthAPIService` |
| `rent_a_carApp.swift` | Add `AuthAPIService` env object, show `PhoneAuthView` if no JWT |
| `RentCheckoutView.swift` | Read `dailyRateCents` from `car` instead of hardcoded switch; call `BookingsAPIService` on reserve |

---

## Part 1: Backend

---

### Task 1: Project scaffold

**Files:**
- Create: `motores-api/package.json`
- Create: `motores-api/tsconfig.json`
- Create: `motores-api/wrangler.toml`
- Create: `motores-api/vitest.config.ts`
- Create: `motores-api/src/types.ts`
- Create: `motores-api/src/index.ts`

- [ ] **Step 1: Create the directory and install deps**

```bash
cd ~/rent-a-car
mkdir motores-api && cd motores-api
npm init -y
npm install hono
npm install --save-dev wrangler typescript @cloudflare/workers-types \
  @cloudflare/vitest-pool-workers vitest
```

- [ ] **Step 2: Create `wrangler.toml`**

```toml
name = "motores-api"
main = "src/index.ts"
compatibility_date = "2024-09-23"
compatibility_flags = ["nodejs_compat"]

[[d1_databases]]
binding = "DB"
database_name = "motores-db"
database_id = "FILL_AFTER_CREATE"

[[r2_buckets]]
binding = "BUCKET"
bucket_name = "motores-images"
```

- [ ] **Step 3: Create `tsconfig.json`**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022"],
    "module": "ES2022",
    "moduleResolution": "bundler",
    "types": ["@cloudflare/workers-types"],
    "strict": true,
    "noEmit": true
  },
  "include": ["src", "test"]
}
```

- [ ] **Step 4: Create `vitest.config.ts`**

```typescript
import { defineWorkersConfig } from "@cloudflare/vitest-pool-workers/config";

export default defineWorkersConfig({
  test: {
    poolOptions: {
      workers: {
        wrangler: { configPath: "./wrangler.toml" },
        miniflare: {
          d1Databases: ["DB"],
          r2Buckets: ["BUCKET"],
          bindings: {
            JWT_SECRET: "test-jwt-secret-32-chars-minimum!",
            STRIPE_WEBHOOK_SECRET: "bypass-for-tests",
            CLOUDFLARE_ACCOUNT_ID: "test-account-id",
            R2_ACCESS_KEY_ID: "test-key-id",
            R2_SECRET_ACCESS_KEY: "test-secret-key",
            R2_BUCKET_NAME: "motores-images",
            R2_PUBLIC_BASE_URL: "https://pub-test.r2.dev",
            TWILIO_ACCOUNT_SID: "test-sid",
            TWILIO_AUTH_TOKEN: "test-token",
            TWILIO_VERIFY_SERVICE_SID: "test-verify-sid",
            STRIPE_SECRET_KEY: "sk_test_placeholder",
          },
        },
      },
    },
  },
});
```

- [ ] **Step 5: Create `src/types.ts`**

```typescript
export type Env = {
  DB: D1Database;
  BUCKET: R2Bucket;
  JWT_SECRET: string;
  TWILIO_ACCOUNT_SID: string;
  TWILIO_AUTH_TOKEN: string;
  TWILIO_VERIFY_SERVICE_SID: string;
  STRIPE_SECRET_KEY: string;
  STRIPE_WEBHOOK_SECRET: string;
};

export interface CarRow {
  id: string;
  dealer_id: number | null;
  name: string;
  type: string;
  price_level: string;
  daily_rate_cents: number;
  neighborhood: string;
  is_active: number;
  is_available: number;
  available_from: string;
  details: string;
  schedule_json: string;
  address: string;
  latitude: number;
  longitude: number;
  logo_color_r: number;
  logo_color_g: number;
  logo_color_b: number;
  logo_initials: string;
  created_at: string;
}

export interface ImageRow {
  id: string;
  vehicle_id: string;
  r2_key: string;
  display_order: number;
  is_confirmed: number;
}

export interface BookingRow {
  id: string;
  user_id: string;
  vehicle_id: string;
  start_date: string;
  end_date: string;
  status: "pending" | "confirmed" | "cancelled" | "failed";
  stripe_payment_intent_id: string | null;
  subtotal_cents: number;
  service_fee_cents: number;
  total_amount_cents: number;
  currency: string;
  created_at: string;
}

export interface UserRow {
  id: string;
  phone: string;
  name: string | null;
  profile_pic_url: string | null;
  role: "user" | "admin";
  created_at: string;
}
```

- [ ] **Step 6: Create `src/index.ts`**

```typescript
import { Hono } from "hono";
import { cors } from "hono/cors";
import type { Env } from "./types";

const app = new Hono<{ Bindings: Env }>();

app.use("*", cors());

app.get("/", (c) => c.json({ status: "ok" }));

export default app;
```

- [ ] **Step 7: Verify project compiles**

```bash
cd motores-api
npx tsc --noEmit
```
Expected: no errors.

- [ ] **Step 8: Create `.gitignore` for the backend**

```bash
cat > motores-api/.gitignore << 'EOF'
node_modules/
.wrangler/
dist/
*.env
.dev.vars
EOF
```

- [ ] **Step 9: Commit**

```bash
git add motores-api/
git commit -m "feat(api): scaffold Cloudflare Workers project"
```

---

### Task 2: D1 schema + seed

**Files:**
- Create: `motores-api/migrations/0001_init.sql`
- Create: `motores-api/migrations/0002_seed.sql`

- [ ] **Step 1: Create `migrations/0001_init.sql`**

```sql
CREATE TABLE IF NOT EXISTS otp_rate_limits (
  phone TEXT NOT NULL,
  count INTEGER NOT NULL DEFAULT 0,
  window_start INTEGER NOT NULL,
  PRIMARY KEY (phone)
);

CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  phone TEXT NOT NULL UNIQUE,
  name TEXT,
  profile_pic_url TEXT,
  role TEXT NOT NULL DEFAULT 'user',
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS vehicles (
  id TEXT PRIMARY KEY,
  dealer_id INTEGER,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  price_level TEXT NOT NULL,
  daily_rate_cents INTEGER NOT NULL,
  neighborhood TEXT NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 1,
  is_available INTEGER NOT NULL DEFAULT 1,
  available_from TEXT NOT NULL DEFAULT '9:00 AM',
  details TEXT NOT NULL DEFAULT '',
  schedule_json TEXT NOT NULL DEFAULT '[]',
  address TEXT NOT NULL DEFAULT '',
  latitude REAL NOT NULL DEFAULT 18.4861,
  longitude REAL NOT NULL DEFAULT -69.9312,
  logo_color_r REAL NOT NULL DEFAULT 0.2,
  logo_color_g REAL NOT NULL DEFAULT 0.2,
  logo_color_b REAL NOT NULL DEFAULT 0.8,
  logo_initials TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS vehicle_images (
  id TEXT PRIMARY KEY,
  vehicle_id TEXT NOT NULL REFERENCES vehicles(id),
  r2_key TEXT NOT NULL,
  display_order INTEGER NOT NULL DEFAULT 0,
  is_confirmed INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS bookings (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  vehicle_id TEXT NOT NULL REFERENCES vehicles(id),
  start_date TEXT NOT NULL,
  end_date TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  stripe_payment_intent_id TEXT UNIQUE,
  subtotal_cents INTEGER NOT NULL,
  service_fee_cents INTEGER NOT NULL,
  total_amount_cents INTEGER NOT NULL,
  currency TEXT NOT NULL DEFAULT 'usd',
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_bookings_vehicle ON bookings(vehicle_id, start_date, end_date, status);
CREATE INDEX IF NOT EXISTS idx_bookings_user ON bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_images_vehicle ON vehicle_images(vehicle_id, is_confirmed, display_order);
```

- [ ] **Step 2: Create `migrations/0002_seed.sql`** (3 v1 vehicles)

```sql
INSERT OR IGNORE INTO vehicles (
  id, name, type, price_level, daily_rate_cents, neighborhood,
  is_active, is_available, available_from, details, schedule_json,
  address, latitude, longitude,
  logo_color_r, logo_color_g, logo_color_b, logo_initials, created_at
) VALUES
(
  '11111111-1111-1111-1111-111111111111',
  'Toyota Corolla', 'Sedan', '$', 3000, 'Piantini',
  1, 1, '9:00 AM', 'Reliable daily driver, great on fuel.',
  '[{"day":"Monday","hours":"9:00 AM – 6:00 PM"},{"day":"Tuesday","hours":"9:00 AM – 6:00 PM"},{"day":"Wednesday","hours":"9:00 AM – 6:00 PM"},{"day":"Thursday","hours":"9:00 AM – 6:00 PM"},{"day":"Friday","hours":"9:00 AM – 6:00 PM"},{"day":"Saturday","hours":"10:00 AM – 4:00 PM"},{"day":"Sunday","hours":"Closed"}]',
  'Av. Abraham Lincoln 123, Piantini', 18.4748, -69.9399,
  0.1, 0.5, 0.1, 'TC', '2026-03-25T00:00:00Z'
),
(
  '22222222-2222-2222-2222-222222222222',
  'Toyota RAV4', 'SUV', '$$', 6000, 'Naco',
  1, 1, '9:00 AM', 'Spacious SUV, perfect for families.',
  '[{"day":"Monday","hours":"9:00 AM – 6:00 PM"},{"day":"Tuesday","hours":"9:00 AM – 6:00 PM"},{"day":"Wednesday","hours":"9:00 AM – 6:00 PM"},{"day":"Thursday","hours":"9:00 AM – 6:00 PM"},{"day":"Friday","hours":"9:00 AM – 6:00 PM"},{"day":"Saturday","hours":"10:00 AM – 4:00 PM"},{"day":"Sunday","hours":"Closed"}]',
  'Calle El Recodo 45, Naco', 18.4797, -69.9312,
  0.1, 0.3, 0.9, 'R4', '2026-03-25T00:00:00Z'
),
(
  '33333333-3333-3333-3333-333333333333',
  'Ford F-150', 'Truck', '$$$', 10000, 'Bella Vista',
  1, 1, '9:00 AM', 'Heavy-duty pickup, ideal for moving or work.',
  '[{"day":"Monday","hours":"9:00 AM – 6:00 PM"},{"day":"Tuesday","hours":"9:00 AM – 6:00 PM"},{"day":"Wednesday","hours":"9:00 AM – 6:00 PM"},{"day":"Thursday","hours":"9:00 AM – 6:00 PM"},{"day":"Friday","hours":"9:00 AM – 6:00 PM"},{"day":"Saturday","hours":"10:00 AM – 4:00 PM"},{"day":"Sunday","hours":"Closed"}]',
  'Av. Sarasota 200, Bella Vista', 18.4640, -69.9422,
  0.8, 0.1, 0.1, 'F1', '2026-03-25T00:00:00Z'
);
```

- [ ] **Step 3: Create D1 database and run migrations**

```bash
cd motores-api
npx wrangler d1 create motores-db
# Copy the database_id from output into wrangler.toml

npx wrangler d1 execute motores-db --local --file=migrations/0001_init.sql
npx wrangler d1 execute motores-db --local --file=migrations/0002_seed.sql
```

Expected: "Executed X queries"

- [ ] **Step 4: Verify seed data**

```bash
npx wrangler d1 execute motores-db --local --command="SELECT id, name, type FROM vehicles"
```
Expected: 3 rows.

- [ ] **Step 5: Commit**

```bash
git add motores-api/migrations/
git commit -m "feat(api): D1 schema and seed vehicles"
```

---

### Task 3: JWT + Auth middleware

**Files:**
- Create: `motores-api/src/lib/jwt.ts`
- Create: `motores-api/src/middleware/auth.ts`
- Create: `motores-api/test/auth.test.ts` (JWT tests only)

- [ ] **Step 1: Write failing tests**

```typescript
// test/auth.test.ts
import { describe, it, expect } from "vitest";
import { signJWT, verifyJWT } from "../src/lib/jwt";

describe("JWT", () => {
  const secret = "test-secret-32-chars-long-enough!";

  it("signs and verifies a payload", async () => {
    const token = await signJWT({ user_id: "abc", phone: "+18095550000", role: "user" }, secret);
    const payload = await verifyJWT(token, secret);
    expect(payload.user_id).toBe("abc");
    expect(payload.role).toBe("user");
  });

  it("throws on tampered token", async () => {
    const token = await signJWT({ user_id: "abc", phone: "+1", role: "user" }, secret);
    const [h, p] = token.split(".");
    await expect(verifyJWT(`${h}.${p}.badsig`, secret)).rejects.toThrow();
  });

  it("throws on expired token", async () => {
    const token = await signJWT({ user_id: "abc", phone: "+1", role: "user" }, secret, -1);
    await expect(verifyJWT(token, secret)).rejects.toThrow();
  });
});
```

- [ ] **Step 2: Run to verify failure**

```bash
cd motores-api && npx vitest run test/auth.test.ts
```
Expected: FAIL — `signJWT` not found.

- [ ] **Step 3: Create `src/lib/jwt.ts`**

```typescript
export interface JWTPayload {
  user_id: string;
  phone: string;
  role: "user" | "admin";
  exp?: number;
  iat?: number;
}

function b64url(buf: ArrayBuffer): string {
  return btoa(String.fromCharCode(...new Uint8Array(buf)))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
}

function encodeStr(s: string): string {
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
}

async function getKey(secret: string): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"]
  );
}

export async function signJWT(
  payload: Omit<JWTPayload, "exp" | "iat">,
  secret: string,
  expiresInSeconds = 86400
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const full: JWTPayload = { ...payload, iat: now, exp: now + expiresInSeconds };
  const header = encodeStr(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const body = encodeStr(JSON.stringify(full));
  const key = await getKey(secret);
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(`${header}.${body}`));
  return `${header}.${body}.${b64url(sig)}`;
}

export async function verifyJWT(token: string, secret: string): Promise<JWTPayload> {
  const parts = token.split(".");
  if (parts.length !== 3) throw new Error("Invalid token");
  const [header, body, sig] = parts;
  const key = await getKey(secret);
  const sigBytes = Uint8Array.from(atob(sig.replace(/-/g, "+").replace(/_/g, "/")), c => c.charCodeAt(0));
  const valid = await crypto.subtle.verify("HMAC", key, sigBytes, new TextEncoder().encode(`${header}.${body}`));
  if (!valid) throw new Error("Invalid signature");
  const payload: JWTPayload = JSON.parse(atob(body.replace(/-/g, "+").replace(/_/g, "/")));
  if (payload.exp && payload.exp < Math.floor(Date.now() / 1000)) throw new Error("Token expired");
  return payload;
}
```

- [ ] **Step 4: Run tests**

```bash
npx vitest run test/auth.test.ts
```
Expected: PASS (3 tests).

- [ ] **Step 5: Create `src/middleware/auth.ts`**

```typescript
import { createMiddleware } from "hono/factory";
import { verifyJWT, type JWTPayload } from "../lib/jwt";
import type { Env } from "../types";

type Variables = { jwtPayload: JWTPayload };

export const requireAuth = createMiddleware<{ Bindings: Env; Variables: Variables }>(
  async (c, next) => {
    const auth = c.req.header("Authorization");
    if (!auth?.startsWith("Bearer ")) return c.json({ error: "Unauthorized" }, 401);
    try {
      const payload = await verifyJWT(auth.slice(7), c.env.JWT_SECRET);
      c.set("jwtPayload", payload);
      await next();
    } catch {
      return c.json({ error: "Unauthorized" }, 401);
    }
  }
);

export const requireAdmin = createMiddleware<{ Bindings: Env; Variables: Variables }>(
  async (c, next) => {
    const payload = c.get("jwtPayload");
    if (!payload || payload.role !== "admin") return c.json({ error: "Forbidden" }, 403);
    await next();
  }
);
```

- [ ] **Step 6: Commit**

```bash
git add motores-api/src/ motores-api/test/
git commit -m "feat(api): JWT sign/verify + auth middleware"
```

---

### Task 4: OTP rate limiter + Twilio + auth routes

**Files:**
- Create: `motores-api/src/lib/twilio.ts`
- Create: `motores-api/src/middleware/rateLimit.ts`
- Create: `motores-api/src/routes/auth.ts`
- Modify: `motores-api/src/index.ts`

- [ ] **Step 1: Write failing test**

```typescript
// test/auth.test.ts — add this describe block
import { SELF } from "cloudflare:test";

describe("POST /auth/otp/send — rate limit", () => {
  it("allows up to 3 requests and blocks the 4th", async () => {
    for (let i = 0; i < 3; i++) {
      const res = await SELF.fetch("http://localhost/auth/otp/send", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ phone: "+18095550001" }),
      });
      // Will fail with 500 (no Twilio creds) but should NOT be 429
      expect(res.status).not.toBe(429);
    }
    const res = await SELF.fetch("http://localhost/auth/otp/send", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ phone: "+18095550001" }),
    });
    expect(res.status).toBe(429);
  });
});
```

- [ ] **Step 2: Run to verify failure**

```bash
npx vitest run test/auth.test.ts
```
Expected: FAIL — route not found.

- [ ] **Step 3: Create `src/lib/twilio.ts`**

```typescript
export async function sendOTP(phone: string, env: { TWILIO_ACCOUNT_SID: string; TWILIO_AUTH_TOKEN: string; TWILIO_VERIFY_SERVICE_SID: string }): Promise<void> {
  const res = await fetch(
    `https://verify.twilio.com/v2/Services/${env.TWILIO_VERIFY_SERVICE_SID}/Verifications`,
    {
      method: "POST",
      headers: {
        Authorization: `Basic ${btoa(`${env.TWILIO_ACCOUNT_SID}:${env.TWILIO_AUTH_TOKEN}`)}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({ To: phone, Channel: "sms" }),
    }
  );
  if (!res.ok) throw new Error(`Twilio send failed: ${res.status}`);
}

export async function checkOTP(phone: string, code: string, env: { TWILIO_ACCOUNT_SID: string; TWILIO_AUTH_TOKEN: string; TWILIO_VERIFY_SERVICE_SID: string }): Promise<boolean> {
  const res = await fetch(
    `https://verify.twilio.com/v2/Services/${env.TWILIO_VERIFY_SERVICE_SID}/VerificationCheck`,
    {
      method: "POST",
      headers: {
        Authorization: `Basic ${btoa(`${env.TWILIO_ACCOUNT_SID}:${env.TWILIO_AUTH_TOKEN}`)}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({ To: phone, Code: code }),
    }
  );
  if (!res.ok) return false;
  const data = await res.json() as { status: string };
  return data.status === "approved";
}
```

- [ ] **Step 4: Create `src/middleware/rateLimit.ts`**

```typescript
import { createMiddleware } from "hono/factory";
import type { Env } from "../types";

const WINDOW_SECONDS = 600; // 10 minutes
const MAX_REQUESTS = 3;

export const otpRateLimit = createMiddleware<{ Bindings: Env; Variables: { otpPhone: string } }>(async (c, next) => {
  const body = await c.req.json().catch(() => ({}));
  const phone: string = body?.phone ?? "";
  if (!phone) return c.json({ error: "phone required" }, 400);

  // Store parsed phone in context so the route handler doesn't need to re-parse body
  c.set("otpPhone", phone);

  const now = Math.floor(Date.now() / 1000);
  const row = await c.env.DB.prepare(
    "SELECT count, window_start FROM otp_rate_limits WHERE phone = ?"
  ).bind(phone).first<{ count: number; window_start: number }>();

  if (row && now - row.window_start < WINDOW_SECONDS) {
    if (row.count >= MAX_REQUESTS) return c.json({ error: "Too many requests" }, 429);
    await c.env.DB.prepare(
      "UPDATE otp_rate_limits SET count = count + 1 WHERE phone = ?"
    ).bind(phone).run();
  } else {
    await c.env.DB.prepare(
      "INSERT OR REPLACE INTO otp_rate_limits (phone, count, window_start) VALUES (?, 1, ?)"
    ).bind(phone, now).run();
  }

  await next();
});
```

- [ ] **Step 5: Create `src/routes/auth.ts`**

```typescript
import { Hono } from "hono";
import { otpRateLimit } from "../middleware/rateLimit";
import { requireAuth } from "../middleware/auth";
import { sendOTP, checkOTP } from "../lib/twilio";
import { signJWT } from "../lib/jwt";
import type { Env, UserRow } from "../types";

const auth = new Hono<{ Bindings: Env }>();

auth.post("/otp/send", otpRateLimit, async (c) => {
  const phone = c.get("otpPhone" as any) as string;
  if (!phone?.match(/^\+\d{10,15}$/)) return c.json({ error: "Invalid phone" }, 400);
  try {
    await sendOTP(phone, c.env);
    return c.json({ ok: true });
  } catch (e) {
    return c.json({ error: "Failed to send OTP" }, 500);
  }
});

auth.post("/otp/verify", async (c) => {
  const { phone, code } = await c.req.json<{ phone: string; code: string }>();
  if (!phone || !code) return c.json({ error: "phone and code required" }, 400);

  const approved = await checkOTP(phone, code, c.env);
  if (!approved) return c.json({ error: "Invalid code" }, 401);

  let user = await c.env.DB.prepare("SELECT * FROM users WHERE phone = ?").bind(phone).first<UserRow>();
  if (!user) {
    const id = crypto.randomUUID();
    await c.env.DB.prepare(
      "INSERT INTO users (id, phone, role, created_at) VALUES (?, ?, 'user', ?)"
    ).bind(id, phone, new Date().toISOString()).run();
    user = { id, phone, name: null, profile_pic_url: null, role: "user", created_at: new Date().toISOString() };
  }

  const token = await signJWT({ user_id: user.id, phone: user.phone, role: user.role }, c.env.JWT_SECRET);
  return c.json({ token, user: { id: user.id, phone: user.phone, name: user.name, role: user.role } });
});

export default auth;
```

- [ ] **Step 6: Mount route in `src/index.ts`**

```typescript
import { Hono } from "hono";
import { cors } from "hono/cors";
import authRoutes from "./routes/auth";
import type { Env } from "./types";

const app = new Hono<{ Bindings: Env }>();
app.use("*", cors());
app.get("/", (c) => c.json({ status: "ok" }));
app.route("/auth", authRoutes);

export default app;
```

- [ ] **Step 7: Run tests**

```bash
npx vitest run test/auth.test.ts
```
Expected: rate limit test passes; JWT tests pass.

- [ ] **Step 8: Commit**

```bash
git add motores-api/src/ motores-api/test/
git commit -m "feat(api): OTP rate limiter, Twilio lib, auth routes"
```

---

### Task 5: Vehicles routes

**Files:**
- Create: `motores-api/src/lib/d1.ts`
- Create: `motores-api/src/routes/vehicles.ts`
- Create: `motores-api/test/vehicles.test.ts`
- Modify: `motores-api/src/index.ts`

- [ ] **Step 1: Write failing tests**

```typescript
// test/vehicles.test.ts
import { describe, it, expect, beforeAll } from "vitest";
import { SELF, env } from "cloudflare:test";
import { applyD1Migrations } from "@cloudflare/vitest-pool-workers/config";

beforeAll(async () => {
  await applyD1Migrations(env.DB, [
    { name: "0001", sql: await (await import("fs/promises")).readFile("./migrations/0001_init.sql", "utf-8") },
    { name: "0002", sql: await (await import("fs/promises")).readFile("./migrations/0002_seed.sql", "utf-8") },
  ]);
});

describe("GET /vehicles", () => {
  it("returns 3 seeded vehicles", async () => {
    const res = await SELF.fetch("http://localhost/vehicles");
    expect(res.status).toBe(200);
    const data = await res.json() as any[];
    expect(data).toHaveLength(3);
    expect(data[0]).toMatchObject({ name: expect.any(String), type: expect.any(String), images: [] });
  });

  it("filters by type", async () => {
    const res = await SELF.fetch("http://localhost/vehicles?type=Sedan");
    const data = await res.json() as any[];
    expect(data.every((v: any) => v.type === "Sedan")).toBe(true);
  });
});

describe("GET /vehicles/:id", () => {
  it("returns a single vehicle", async () => {
    const res = await SELF.fetch("http://localhost/vehicles/11111111-1111-1111-1111-111111111111");
    expect(res.status).toBe(200);
    const data = await res.json() as any;
    expect(data.name).toBe("Toyota Corolla");
  });

  it("returns 404 for unknown id", async () => {
    const res = await SELF.fetch("http://localhost/vehicles/does-not-exist");
    expect(res.status).toBe(404);
  });
});
```

- [ ] **Step 2: Run to verify failure**

```bash
npx vitest run test/vehicles.test.ts
```
Expected: FAIL.

- [ ] **Step 3: Create `src/lib/d1.ts`**

```typescript
import type { CarRow, ImageRow } from "../types";

function formatVehicle(car: CarRow, images: ImageRow[], r2PublicBaseUrl: string) {
  return {
    id: car.id,
    name: car.name,
    type: car.type,
    price_level: car.price_level,
    daily_rate_cents: car.daily_rate_cents,
    neighborhood: car.neighborhood,
    is_available: car.is_available === 1,
    available_from: car.available_from,
    details: car.details,
    schedule: JSON.parse(car.schedule_json),
    address: car.address,
    latitude: car.latitude,
    longitude: car.longitude,
    logo: { r: car.logo_color_r, g: car.logo_color_g, b: car.logo_color_b, initials: car.logo_initials },
    images: images.map(img => ({
      id: img.id,
      url: `${r2PublicBaseUrl}/${img.r2_key}`,
      display_order: img.display_order,
    })),
  };
}

export async function listVehicles(db: D1Database, r2PublicBaseUrl: string, filters: { type?: string; available?: boolean }) {
  let query = "SELECT * FROM vehicles WHERE is_active = 1";
  const bindings: (string | number)[] = [];
  if (filters.type) { query += " AND type = ?"; bindings.push(filters.type); }
  if (filters.available !== undefined) { query += " AND is_available = ?"; bindings.push(filters.available ? 1 : 0); }
  query += " ORDER BY name ASC";

  const cars = await db.prepare(query).bind(...bindings).all<CarRow>();
  const ids = cars.results.map(c => c.id);
  if (ids.length === 0) return [];

  const placeholders = ids.map(() => "?").join(",");
  const images = await db.prepare(
    `SELECT * FROM vehicle_images WHERE vehicle_id IN (${placeholders}) AND is_confirmed = 1 ORDER BY display_order ASC`
  ).bind(...ids).all<ImageRow>();

  const imagesByVehicle = new Map<string, ImageRow[]>();
  for (const img of images.results) {
    if (!imagesByVehicle.has(img.vehicle_id)) imagesByVehicle.set(img.vehicle_id, []);
    imagesByVehicle.get(img.vehicle_id)!.push(img);
  }

  return cars.results.map(car => formatVehicle(car, imagesByVehicle.get(car.id) ?? [], r2PublicBaseUrl));
}

export async function getVehicle(db: D1Database, r2PublicBaseUrl: string, id: string) {
  const car = await db.prepare("SELECT * FROM vehicles WHERE id = ? AND is_active = 1").bind(id).first<CarRow>();
  if (!car) return null;
  const images = await db.prepare(
    "SELECT * FROM vehicle_images WHERE vehicle_id = ? AND is_confirmed = 1 ORDER BY display_order ASC"
  ).bind(id).all<ImageRow>();
  return formatVehicle(car, images.results, r2PublicBaseUrl);
}
```

- [ ] **Step 4: Create `src/routes/vehicles.ts`**

```typescript
import { Hono } from "hono";
import { requireAuth, requireAdmin } from "../middleware/auth";
import { listVehicles, getVehicle } from "../lib/d1";
import type { Env } from "../types";

const vehicles = new Hono<{ Bindings: Env }>();

vehicles.get("/", async (c) => {
  const type = c.req.query("type");
  const available = c.req.query("available");
  const data = await listVehicles(c.env.DB, c.env.R2_PUBLIC_BASE_URL, {
    type: type ?? undefined,
    available: available === "true" ? true : available === "false" ? false : undefined,
  });
  return c.json(data);
});

vehicles.get("/:id", async (c) => {
  const vehicle = await getVehicle(c.env.DB, c.env.R2_PUBLIC_BASE_URL, c.req.param("id"));
  if (!vehicle) return c.json({ error: "Not found" }, 404);
  return c.json(vehicle);
});

vehicles.post("/", requireAuth, requireAdmin, async (c) => {
  const body = await c.req.json<any>();
  const id = crypto.randomUUID();
  await c.env.DB.prepare(`
    INSERT INTO vehicles (id, name, type, price_level, daily_rate_cents, neighborhood,
      is_active, is_available, available_from, details, schedule_json, address,
      latitude, longitude, logo_color_r, logo_color_g, logo_color_b, logo_initials, created_at)
    VALUES (?,?,?,?,?,?,1,?,?,?,?,?,?,?,?,?,?,?,?)
  `).bind(
    id, body.name, body.type, body.price_level, body.daily_rate_cents, body.neighborhood,
    body.is_available ? 1 : 0, body.available_from ?? "9:00 AM",
    body.details ?? "", JSON.stringify(body.schedule ?? []),
    body.address ?? "", body.latitude ?? 18.4861, body.longitude ?? -69.9312,
    body.logo?.r ?? 0.2, body.logo?.g ?? 0.2, body.logo?.b ?? 0.8,
    body.logo?.initials ?? "", new Date().toISOString()
  ).run();
  return c.json({ id }, 201);
});

vehicles.put("/:id", requireAuth, requireAdmin, async (c) => {
  const body = await c.req.json<any>();
  const id = c.req.param("id");
  const fields: string[] = [];
  const vals: unknown[] = [];

  const map: Record<string, string> = {
    name: "name", type: "type", price_level: "price_level",
    daily_rate_cents: "daily_rate_cents", neighborhood: "neighborhood",
    is_available: "is_available", available_from: "available_from",
    details: "details", address: "address", latitude: "latitude", longitude: "longitude",
  };
  for (const [k, col] of Object.entries(map)) {
    if (k in body) { fields.push(`${col} = ?`); vals.push(k === "is_available" ? (body[k] ? 1 : 0) : body[k]); }
  }
  if (body.schedule) { fields.push("schedule_json = ?"); vals.push(JSON.stringify(body.schedule)); }
  if (body.logo) {
    fields.push("logo_color_r = ?, logo_color_g = ?, logo_color_b = ?, logo_initials = ?");
    vals.push(body.logo.r, body.logo.g, body.logo.b, body.logo.initials);
  }
  if (fields.length === 0) return c.json({ error: "Nothing to update" }, 400);
  vals.push(id);
  await c.env.DB.prepare(`UPDATE vehicles SET ${fields.join(", ")} WHERE id = ?`).bind(...vals).run();
  return c.json({ ok: true });
});

vehicles.delete("/:id", requireAuth, requireAdmin, async (c) => {
  const id = c.req.param("id");
  // Soft-delete + collect R2 keys for cleanup
  const images = await c.env.DB.prepare(
    "SELECT r2_key FROM vehicle_images WHERE vehicle_id = ?"
  ).bind(id).all<{ r2_key: string }>();
  for (const img of images.results) await c.env.BUCKET.delete(img.r2_key);
  await c.env.DB.prepare("DELETE FROM vehicle_images WHERE vehicle_id = ?").bind(id).run();
  await c.env.DB.prepare("UPDATE vehicles SET is_active = 0 WHERE id = ?").bind(id).run();
  return c.json({ ok: true });
});

export default vehicles;
```

- [ ] **Step 5: Mount in `src/index.ts`**

```typescript
import vehicleRoutes from "./routes/vehicles";
// ... add after auth:
app.route("/vehicles", vehicleRoutes);
```

- [ ] **Step 6: Run tests**

```bash
npx vitest run test/vehicles.test.ts
```
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add motores-api/src/ motores-api/test/
git commit -m "feat(api): vehicles CRUD routes + D1 query helpers"
```

---

### Task 6: Vehicle image routes (pre-signed R2 upload)

**Files:**
- Create: `motores-api/src/lib/r2.ts`
- Create: `motores-api/src/routes/images.ts`
- Modify: `motores-api/src/index.ts`

- [ ] **Step 1: Install AWS SDK (R2 pre-sign uses S3 compat)**

```bash
cd motores-api
npm install @aws-sdk/client-s3 @aws-sdk/s3-request-presigner
```

- [ ] **Step 2: Create `src/lib/r2.ts`**

```typescript
import { S3Client, PutObjectCommand, DeleteObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

function getS3Client(env: { CLOUDFLARE_ACCOUNT_ID: string; R2_ACCESS_KEY_ID: string; R2_SECRET_ACCESS_KEY: string }) {
  return new S3Client({
    region: "auto",
    endpoint: `https://${env.CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com`,
    credentials: { accessKeyId: env.R2_ACCESS_KEY_ID, secretAccessKey: env.R2_SECRET_ACCESS_KEY },
  });
}

export async function generatePresignedUploadUrl(
  key: string,
  contentType: string,
  env: { CLOUDFLARE_ACCOUNT_ID: string; R2_ACCESS_KEY_ID: string; R2_SECRET_ACCESS_KEY: string; R2_BUCKET_NAME: string; R2_PUBLIC_BASE_URL: string }
): Promise<{ uploadUrl: string; publicUrl: string }> {
  const client = getS3Client(env);
  const command = new PutObjectCommand({ Bucket: env.R2_BUCKET_NAME, Key: key, ContentType: contentType });
  const uploadUrl = await getSignedUrl(client, command, { expiresIn: 900 });
  return { uploadUrl, publicUrl: `${env.R2_PUBLIC_BASE_URL}/${key}` };
}

export async function deleteR2Object(key: string, env: { CLOUDFLARE_ACCOUNT_ID: string; R2_ACCESS_KEY_ID: string; R2_SECRET_ACCESS_KEY: string; R2_BUCKET_NAME: string }) {
  const client = getS3Client(env);
  await client.send(new DeleteObjectCommand({ Bucket: env.R2_BUCKET_NAME, Key: key }));
}
```

> **Note:** Add `CLOUDFLARE_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET_NAME`, `R2_PUBLIC_BASE_URL` to `Env` in `types.ts` and as Worker secrets.

- [ ] **Step 3: Update `src/types.ts`** — add R2 secret fields to `Env`

```typescript
export type Env = {
  DB: D1Database;
  BUCKET: R2Bucket;
  JWT_SECRET: string;
  TWILIO_ACCOUNT_SID: string;
  TWILIO_AUTH_TOKEN: string;
  TWILIO_VERIFY_SERVICE_SID: string;
  STRIPE_SECRET_KEY: string;
  STRIPE_WEBHOOK_SECRET: string;
  CLOUDFLARE_ACCOUNT_ID: string;
  R2_ACCESS_KEY_ID: string;
  R2_SECRET_ACCESS_KEY: string;
  R2_BUCKET_NAME: string;
  R2_PUBLIC_BASE_URL: string;
};
```

- [ ] **Step 4: Create `src/routes/images.ts`**

```typescript
import { Hono } from "hono";
import { requireAuth, requireAdmin } from "../middleware/auth";
import { generatePresignedUploadUrl, deleteR2Object } from "../lib/r2";
import type { Env, ImageRow } from "../types";

const images = new Hono<{ Bindings: Env }>();

// POST /vehicles/:id/images/presign
images.post("/presign", requireAuth, requireAdmin, async (c) => {
  const vehicleId = c.req.param("id");
  const { content_type = "image/jpeg" } = await c.req.json<{ content_type?: string }>();
  const imageId = crypto.randomUUID();
  const key = `vehicles/${vehicleId}/${imageId}`;

  const { uploadUrl, publicUrl } = await generatePresignedUploadUrl(key, content_type, c.env);

  await c.env.DB.prepare(
    "INSERT INTO vehicle_images (id, vehicle_id, r2_key, display_order, is_confirmed) VALUES (?, ?, ?, 0, 0)"
  ).bind(imageId, vehicleId, key).run();

  return c.json({ image_id: imageId, upload_url: uploadUrl, public_url: publicUrl });
});

// POST /vehicles/:id/images/confirm/:imageId
images.post("/confirm/:imageId", requireAuth, requireAdmin, async (c) => {
  const { imageId } = c.req.param();
  // Set is_confirmed = 1 and assign display_order = max + 1
  const maxOrder = await c.env.DB.prepare(
    "SELECT MAX(display_order) as m FROM vehicle_images WHERE vehicle_id = ? AND is_confirmed = 1"
  ).bind(c.req.param("id")).first<{ m: number | null }>();
  const nextOrder = (maxOrder?.m ?? -1) + 1;
  await c.env.DB.prepare(
    "UPDATE vehicle_images SET is_confirmed = 1, display_order = ? WHERE id = ?"
  ).bind(nextOrder, imageId).run();
  return c.json({ ok: true });
});

// DELETE /vehicles/:id/images/:imageId
images.delete("/:imageId", requireAuth, requireAdmin, async (c) => {
  const imageId = c.req.param("imageId");
  const img = await c.env.DB.prepare("SELECT r2_key FROM vehicle_images WHERE id = ?").bind(imageId).first<ImageRow>();
  if (!img) return c.json({ error: "Not found" }, 404);
  await deleteR2Object(img.r2_key, c.env);
  await c.env.DB.prepare("DELETE FROM vehicle_images WHERE id = ?").bind(imageId).run();
  return c.json({ ok: true });
});

// PUT /vehicles/:id/images/reorder
images.put("/reorder", requireAuth, requireAdmin, async (c) => {
  const { order } = await c.req.json<{ order: Array<{ id: string; display_order: number }> }>();
  for (const item of order) {
    await c.env.DB.prepare("UPDATE vehicle_images SET display_order = ? WHERE id = ?")
      .bind(item.display_order, item.id).run();
  }
  return c.json({ ok: true });
});

export default images;
```

- [ ] **Step 5: Mount in `src/index.ts`**

```typescript
import imageRoutes from "./routes/images";
// Mount under /vehicles/:id/images
app.route("/vehicles/:id/images", imageRoutes);
```

- [ ] **Step 6: Add image presign test to `test/vehicles.test.ts`**

Add this describe block (requires an admin JWT — create one with `signJWT` + `role: "admin"` like the bookings test):

```typescript
describe("POST /vehicles/:id/images/presign", () => {
  it("returns image_id, upload_url, and public_url", async () => {
    const adminToken = await signJWT(
      { user_id: "admin-id", phone: "+10000000000", role: "admin" },
      "test-jwt-secret-32-chars-minimum!"
    );
    // Insert admin user first
    await env.DB.prepare("INSERT OR IGNORE INTO users (id,phone,role,created_at) VALUES ('admin-id','+10000000000','admin',?)")
      .bind(new Date().toISOString()).run();

    const res = await SELF.fetch(
      "http://localhost/vehicles/11111111-1111-1111-1111-111111111111/images/presign",
      {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${adminToken}` },
        body: JSON.stringify({ content_type: "image/jpeg" }),
      }
    );
    expect(res.status).toBe(200);
    const data = await res.json() as any;
    expect(data).toMatchObject({
      image_id: expect.any(String),
      upload_url: expect.stringContaining("r2"),
      public_url: expect.stringContaining("vehicles/11111111"),
    });
  });
});
```

- [ ] **Step 7: Run test**

```bash
npx vitest run test/vehicles.test.ts
```
Expected: PASS (presign test may require mocking `generatePresignedUploadUrl` since test env has no real R2 API token — mock it in the test file with `vi.mock("../src/lib/r2", () => ({ generatePresignedUploadUrl: vi.fn().mockResolvedValue({ uploadUrl: "https://r2.example.com/upload", publicUrl: "https://pub-test.r2.dev/vehicles/test/img.jpg" }), deleteR2Object: vi.fn() }))`)

- [ ] **Step 8: Verify TypeScript compiles**

```bash
npx tsc --noEmit
```
Expected: no errors.

- [ ] **Step 9: Commit**

```bash
git add motores-api/src/ motores-api/test/
git commit -m "feat(api): vehicle image presign/confirm/delete routes"
```

---

### Task 7: Bookings routes

**Files:**
- Create: `motores-api/src/lib/stripe.ts`
- Create: `motores-api/src/routes/bookings.ts`
- Create: `motores-api/test/bookings.test.ts`
- Modify: `motores-api/src/index.ts`

- [ ] **Step 1: Write failing tests**

```typescript
// test/bookings.test.ts
import { describe, it, expect, beforeAll } from "vitest";
import { SELF, env } from "cloudflare:test";
import { applyD1Migrations } from "@cloudflare/vitest-pool-workers/config";
import { signJWT } from "../src/lib/jwt";
import { readFile } from "fs/promises";

let userToken: string;

beforeAll(async () => {
  await applyD1Migrations(env.DB, [
    { name: "0001", sql: await readFile("./migrations/0001_init.sql", "utf-8") },
    { name: "0002", sql: await readFile("./migrations/0002_seed.sql", "utf-8") },
  ]);
  await env.DB.prepare(
    "INSERT INTO users (id, phone, role, created_at) VALUES (?, ?, 'user', ?)"
  ).bind("user-test-id", "+18095550099", new Date().toISOString()).run();
  userToken = await signJWT({ user_id: "user-test-id", phone: "+18095550099", role: "user" }, "test-jwt-secret");
});

describe("POST /bookings — conflict detection", () => {
  it("returns 409 when dates overlap an existing confirmed booking", async () => {
    // Seed a confirmed booking
    await env.DB.prepare(`
      INSERT INTO bookings (id, user_id, vehicle_id, start_date, end_date, status,
        subtotal_cents, service_fee_cents, total_amount_cents, currency, created_at)
      VALUES ('b1','user-test-id','11111111-1111-1111-1111-111111111111','2026-06-01','2026-06-05','confirmed',9000,900,9900,'usd',?)
    `).bind(new Date().toISOString()).run();

    const res = await SELF.fetch("http://localhost/bookings", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${userToken}` },
      body: JSON.stringify({ vehicle_id: "11111111-1111-1111-1111-111111111111", start_date: "2026-06-03", end_date: "2026-06-07" }),
    });
    expect(res.status).toBe(409);
  });
});
```

- [ ] **Step 2: Run to verify failure**

```bash
npx vitest run test/bookings.test.ts
```
Expected: FAIL.

- [ ] **Step 3: Create `src/lib/stripe.ts`**

```typescript
export async function createPaymentIntent(
  amountCents: number,
  currency: string,
  metadata: Record<string, string>,
  secretKey: string
): Promise<{ id: string; clientSecret: string }> {
  const res = await fetch("https://api.stripe.com/v1/payment_intents", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${secretKey}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      amount: String(amountCents),
      currency,
      ...Object.fromEntries(Object.entries(metadata).map(([k, v]) => [`metadata[${k}]`, v])),
    }),
  });
  if (!res.ok) throw new Error(`Stripe error: ${res.status}`);
  const data = await res.json() as { id: string; client_secret: string };
  return { id: data.id, clientSecret: data.client_secret };
}

export async function verifyWebhookSignature(
  body: string,
  signature: string,
  secret: string
): Promise<boolean> {
  const parts = signature.split(",");
  const ts = parts.find(p => p.startsWith("t="))?.slice(2) ?? "";
  const v1 = parts.find(p => p.startsWith("v1="))?.slice(3) ?? "";
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(`${ts}.${body}`));
  const computed = Array.from(new Uint8Array(sig)).map(b => b.toString(16).padStart(2, "0")).join("");
  return computed === v1;
}
```

- [ ] **Step 4: Create `src/routes/bookings.ts`**

```typescript
import { Hono } from "hono";
import { requireAuth } from "../middleware/auth";
import { createPaymentIntent } from "../lib/stripe";
import type { Env, BookingRow, CarRow } from "../types";

const bookings = new Hono<{ Bindings: Env }>();

bookings.post("/", requireAuth, async (c) => {
  const { user_id } = c.get("jwtPayload" as any);
  const { vehicle_id, start_date, end_date } = await c.req.json<{ vehicle_id: string; start_date: string; end_date: string }>();

  const car = await c.env.DB.prepare("SELECT * FROM vehicles WHERE id = ? AND is_active = 1").bind(vehicle_id).first<CarRow>();
  if (!car) return c.json({ error: "Vehicle not found" }, 404);

  // Overlap check
  const conflict = await c.env.DB.prepare(`
    SELECT id FROM bookings
    WHERE vehicle_id = ? AND status IN ('pending','confirmed')
    AND start_date < ? AND end_date > ?
  `).bind(vehicle_id, end_date, start_date).first();
  if (conflict) return c.json({ error: "Vehicle not available for these dates" }, 409);

  // Compute price
  const start = new Date(start_date);
  const end = new Date(end_date);
  const days = Math.max(1, Math.ceil((end.getTime() - start.getTime()) / 86400000));
  const subtotal = car.daily_rate_cents * days;
  const fee = Math.round(subtotal * 0.1);
  const total = subtotal + fee;

  const pi = await createPaymentIntent(total, "usd", { booking_vehicle: vehicle_id, booking_user: user_id }, c.env.STRIPE_SECRET_KEY);

  const id = crypto.randomUUID();
  await c.env.DB.prepare(`
    INSERT INTO bookings (id, user_id, vehicle_id, start_date, end_date, status,
      stripe_payment_intent_id, subtotal_cents, service_fee_cents, total_amount_cents, currency, created_at)
    VALUES (?,?,?,?,?,'pending',?,?,?,?,'usd',?)
  `).bind(id, user_id, vehicle_id, start_date, end_date, pi.id, subtotal, fee, total, new Date().toISOString()).run();

  return c.json({ booking_id: id, subtotal_cents: subtotal, service_fee_cents: fee, total_amount_cents: total, currency: "usd", stripe_client_secret: pi.clientSecret, status: "pending" }, 201);
});

bookings.get("/me", requireAuth, async (c) => {
  const { user_id } = c.get("jwtPayload" as any);
  const rows = await c.env.DB.prepare("SELECT * FROM bookings WHERE user_id = ? ORDER BY created_at DESC").bind(user_id).all<BookingRow>();
  return c.json(rows.results);
});

bookings.get("/:id", requireAuth, async (c) => {
  const { user_id } = c.get("jwtPayload" as any);
  const booking = await c.env.DB.prepare("SELECT * FROM bookings WHERE id = ? AND user_id = ?").bind(c.req.param("id"), user_id).first<BookingRow>();
  if (!booking) return c.json({ error: "Not found" }, 404);
  return c.json(booking);
});

bookings.post("/:id/cancel", requireAuth, async (c) => {
  const { user_id } = c.get("jwtPayload" as any);
  const booking = await c.env.DB.prepare("SELECT * FROM bookings WHERE id = ? AND user_id = ?").bind(c.req.param("id"), user_id).first<BookingRow>();
  if (!booking) return c.json({ error: "Not found" }, 404);
  if (!["pending", "confirmed"].includes(booking.status)) return c.json({ error: "Cannot cancel" }, 400);
  await c.env.DB.prepare("UPDATE bookings SET status = 'cancelled' WHERE id = ?").bind(booking.id).run();
  return c.json({ ok: true });
});

export default bookings;
```

- [ ] **Step 5: Mount in `src/index.ts`**

```typescript
import bookingRoutes from "./routes/bookings";
app.route("/bookings", bookingRoutes);
```

- [ ] **Step 6: Run tests**

```bash
npx vitest run test/bookings.test.ts
```
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add motores-api/src/ motores-api/test/
git commit -m "feat(api): bookings routes with overlap check and Stripe"
```

---

### Task 8: Stripe webhook + users routes

**Files:**
- Create: `motores-api/src/routes/payments.ts`
- Create: `motores-api/src/routes/users.ts`
- Create: `motores-api/test/payments.test.ts`
- Modify: `motores-api/src/index.ts`

- [ ] **Step 1: Write failing webhook idempotency test**

```typescript
// test/payments.test.ts
import { describe, it, expect, beforeAll, vi } from "vitest";
import { SELF, env } from "cloudflare:test";
import { applyD1Migrations } from "@cloudflare/vitest-pool-workers/config";
import { readFile } from "fs/promises";

// Mock verifyWebhookSignature so tests don't need a real Stripe signature
vi.mock("../src/lib/stripe", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../src/lib/stripe")>();
  return { ...actual, verifyWebhookSignature: vi.fn().mockResolvedValue(true) };
});

beforeAll(async () => {
  await applyD1Migrations(env.DB, [
    { name: "0001", sql: await readFile("./migrations/0001_init.sql", "utf-8") },
  ]);
  await env.DB.prepare("INSERT INTO users (id,phone,role,created_at) VALUES ('u1','+1','user',?)")
    .bind(new Date().toISOString()).run();
  await env.DB.prepare(`
    INSERT INTO bookings (id,user_id,vehicle_id,start_date,end_date,status,
      stripe_payment_intent_id,subtotal_cents,service_fee_cents,total_amount_cents,currency,created_at)
    VALUES ('bk1','u1','11111111-1111-1111-1111-111111111111','2026-07-01','2026-07-05','pending','pi_test_123',9000,900,9900,'usd',?)
  `).bind(new Date().toISOString()).run();
});

describe("POST /payments/webhook idempotency", () => {
  it("confirms booking on payment_intent.succeeded", async () => {
    const payload = JSON.stringify({ type: "payment_intent.succeeded", data: { object: { id: "pi_test_123" } } });
    const res = await SELF.fetch("http://localhost/payments/webhook", {
      method: "POST",
      headers: { "Content-Type": "application/json", "stripe-signature": "t=1,v1=test" },
      body: payload,
    });
    expect(res.status).toBe(200);
    const booking = await env.DB.prepare("SELECT status FROM bookings WHERE id = 'bk1'").first<{ status: string }>();
    expect(booking?.status).toBe("confirmed");
  });

  it("is idempotent — second call does not error", async () => {
    const payload = JSON.stringify({ type: "payment_intent.succeeded", data: { object: { id: "pi_test_123" } } });
    const res = await SELF.fetch("http://localhost/payments/webhook", {
      method: "POST",
      headers: { "Content-Type": "application/json", "stripe-signature": "t=1,v1=test" },
      body: payload,
    });
    expect(res.status).toBe(200);
  });
});
```

- [ ] **Step 2: Create `src/routes/payments.ts`**

```typescript
import { Hono } from "hono";
import { verifyWebhookSignature } from "../lib/stripe";
import type { Env, BookingRow } from "../types";

const payments = new Hono<{ Bindings: Env }>();

payments.post("/webhook", async (c) => {
  const body = await c.req.text();
  const sig = c.req.header("stripe-signature") ?? "";
  const valid = await verifyWebhookSignature(body, sig, c.env.STRIPE_WEBHOOK_SECRET);
  if (!valid) return c.json({ error: "Invalid signature" }, 400);

  const event = JSON.parse(body) as { type: string; data: { object: { id: string } } };
  const paymentIntentId = event.data.object.id;

  const booking = await c.env.DB.prepare(
    "SELECT * FROM bookings WHERE stripe_payment_intent_id = ?"
  ).bind(paymentIntentId).first<BookingRow>();

  if (!booking) return c.json({ ok: true }); // Unknown PI — ignore

  if (event.type === "payment_intent.succeeded" && booking.status !== "confirmed") {
    await c.env.DB.prepare("UPDATE bookings SET status = 'confirmed' WHERE id = ?").bind(booking.id).run();
  } else if (event.type === "payment_intent.payment_failed" && booking.status !== "failed") {
    await c.env.DB.prepare("UPDATE bookings SET status = 'failed' WHERE id = ?").bind(booking.id).run();
  }
  // Already in target state — idempotent return
  return c.json({ ok: true });
});

export default payments;
```

- [ ] **Step 3: Create `src/routes/users.ts`**

```typescript
import { Hono } from "hono";
import { requireAuth } from "../middleware/auth";
import type { Env, UserRow } from "../types";

const users = new Hono<{ Bindings: Env }>();

users.get("/me", requireAuth, async (c) => {
  const { user_id } = c.get("jwtPayload" as any);
  const user = await c.env.DB.prepare("SELECT id, phone, name, profile_pic_url, role FROM users WHERE id = ?").bind(user_id).first<UserRow>();
  if (!user) return c.json({ error: "Not found" }, 404);
  return c.json(user);
});

users.put("/me", requireAuth, async (c) => {
  const { user_id } = c.get("jwtPayload" as any);
  const { name, profile_pic_url } = await c.req.json<{ name?: string; profile_pic_url?: string }>();
  const fields: string[] = [];
  const vals: unknown[] = [];
  if (name !== undefined) { fields.push("name = ?"); vals.push(name); }
  if (profile_pic_url !== undefined) { fields.push("profile_pic_url = ?"); vals.push(profile_pic_url); }
  if (fields.length === 0) return c.json({ error: "Nothing to update" }, 400);
  vals.push(user_id);
  await c.env.DB.prepare(`UPDATE users SET ${fields.join(", ")} WHERE id = ?`).bind(...vals).run();
  return c.json({ ok: true });
});

export default users;
```

- [ ] **Step 4: Mount both in `src/index.ts`**

```typescript
import paymentRoutes from "./routes/payments";
import userRoutes from "./routes/users";
app.route("/payments", paymentRoutes);
app.route("/users", userRoutes);
```

- [ ] **Step 5: Run all tests**

```bash
npx vitest run
```
Expected: all tests PASS.

- [ ] **Step 6: Commit**

```bash
git add motores-api/src/ motores-api/test/
git commit -m "feat(api): payments webhook, users routes, complete API"
```

---

### Task 9: Deploy to Cloudflare

**Files:**
- Modify: `motores-api/wrangler.toml` (fill real database_id)

- [ ] **Step 1: Verify `wrangler.toml` has `database_id` filled**

The D1 database was created in Task 2. Confirm `wrangler.toml` already has the real `database_id` UUID. If you skipped that step or are targeting a fresh production account (separate from local dev), run:

```bash
cd motores-api
npx wrangler d1 create motores-db
# Copy the output database_id into wrangler.toml
```

Otherwise skip this step.

- [ ] **Step 2: Create R2 bucket**

```bash
npx wrangler r2 bucket create motores-images
# Enable public access in Cloudflare dashboard → R2 → motores-images → Settings → Public Access
```

- [ ] **Step 3: Set Worker secrets**

```bash
npx wrangler secret put JWT_SECRET
npx wrangler secret put TWILIO_ACCOUNT_SID
npx wrangler secret put TWILIO_AUTH_TOKEN
npx wrangler secret put TWILIO_VERIFY_SERVICE_SID
npx wrangler secret put STRIPE_SECRET_KEY
npx wrangler secret put STRIPE_WEBHOOK_SECRET
npx wrangler secret put CLOUDFLARE_ACCOUNT_ID
npx wrangler secret put R2_ACCESS_KEY_ID
npx wrangler secret put R2_SECRET_ACCESS_KEY
npx wrangler secret put R2_BUCKET_NAME        # motores-images
npx wrangler secret put R2_PUBLIC_BASE_URL    # https://pub-<hash>.r2.dev
```

> To get `R2_ACCESS_KEY_ID` and `R2_SECRET_ACCESS_KEY`: Cloudflare Dashboard → R2 → Manage R2 API Tokens → Create API Token (Object Read & Write for motores-images bucket).

- [ ] **Step 4: Run production migrations**

```bash
npx wrangler d1 execute motores-db --remote --file=migrations/0001_init.sql
npx wrangler d1 execute motores-db --remote --file=migrations/0002_seed.sql
```

- [ ] **Step 5: Deploy**

```bash
npx wrangler deploy
```
Expected: `Deployed motores-api ... https://motores-api.<your-subdomain>.workers.dev`

- [ ] **Step 6: Smoke test**

```bash
curl https://motores-api.<subdomain>.workers.dev/vehicles
```
Expected: JSON array with 3 vehicles.

- [ ] **Step 7: Commit**

```bash
git add motores-api/wrangler.toml
git commit -m "feat(api): production deployment config"
```

---

## Part 2: iOS Integration

---

### Task 10: Replace `Car` model + add `MotoresAPIClient`

**Files:**
- Modify: `rent-a-car/rent-a-car/Models/Car.swift`
- Create: `rent-a-car/rent-a-car/Services/MotoresAPI/MotoresAPIClient.swift`

- [ ] **Step 1: Update `Models/Car.swift`** — remove Firestore dependency, align with API response

```swift
// Models/Car.swift
import CoreLocation
import Foundation
import SwiftUI

struct Car: Identifiable, Codable, Hashable {
    struct Logo: Codable, Hashable {
        var r: Double
        var g: Double
        var b: Double
        var initials: String
    }

    struct ImageItem: Codable, Hashable {
        var id: String
        var url: String
        var display_order: Int
    }

    var id: String
    var name: String
    var type: String
    var price_level: String
    var daily_rate_cents: Int
    var neighborhood: String
    var is_available: Bool
    var available_from: String
    var details: String
    var schedule: [DaySchedule]
    var address: String
    var latitude: Double
    var longitude: Double
    var logo: Logo
    var images: [ImageItem]
    var is_active: Bool = true

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var logoColor: Color {
        Color(red: logo.r, green: logo.g, blue: logo.b)
    }

    var logoInitials: String {
        let trimmed = logo.initials.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return String(trimmed.prefix(2)).uppercased() }
        return String(name.prefix(2)).uppercased()
    }

    /// Client-side display rate in USD (cents → dollars)
    var dailyRateUSD: Double { Double(daily_rate_cents) / 100.0 }

    var photoURLs: [String] { images.map(\.url) }
}
```

- [ ] **Step 2: Create `Services/MotoresAPI/MotoresAPIClient.swift`**

```swift
// Services/MotoresAPI/MotoresAPIClient.swift
import Foundation

enum APIError: Error, LocalizedError {
    case badStatus(Int)
    case noToken
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .badStatus(let code): return "Server error \(code)"
        case .noToken: return "Not authenticated"
        case .decodingError(let e): return "Decoding error: \(e.localizedDescription)"
        }
    }
}

final class MotoresAPIClient {
    static let shared = MotoresAPIClient()

    // Replace with your deployed Workers URL
    let baseURL = URL(string: "https://motores-api.<subdomain>.workers.dev")!

    private(set) var token: String? {
        get { KeychainHelper.load(key: "motores_jwt") }
        set {
            if let t = newValue { KeychainHelper.save(key: "motores_jwt", value: t) }
            else { KeychainHelper.delete(key: "motores_jwt") }
        }
    }

    var isAuthenticated: Bool { token != nil }

    func setToken(_ t: String) { token = t }
    func clearToken() { token = nil }

    func request<T: Decodable>(_ path: String, method: String = "GET", body: Encodable? = nil) async throws -> T {
        // Use URL(string:relativeTo:) to preserve slashes in paths like "vehicles/123"
        guard let url = URL(string: path, relativeTo: baseURL) else { throw APIError.badStatus(0) }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body { req.httpBody = try JSONEncoder().encode(body) }
        let (data, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw APIError.badStatus(status) }
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw APIError.decodingError(error) }
    }
}
```

- [ ] **Step 3: Create `Services/MotoresAPI/KeychainHelper.swift`**

```swift
import Foundation
import Security

enum KeychainHelper {
    static func save(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: key, kSecValueData: data]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(key: String) -> String? {
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: key, kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne]
        var item: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: key]
        SecItemDelete(query as CFDictionary)
    }
}
```

- [ ] **Step 4: Verify the Swift project still compiles** — open Xcode, build (`⌘B`). Errors will appear for Firebase references in `CarsRepository` because `Car` no longer has `@DocumentID`. That's expected — fixed in the next task.

- [ ] **Step 5: Commit**

```bash
git add rent-a-car/rent-a-car/Models/Car.swift rent-a-car/rent-a-car/Services/MotoresAPI/
git commit -m "feat(ios): update Car model for API, add MotoresAPIClient + Keychain"
```

---

### Task 11: Auth flow — OTP via Workers API

**Files:**
- Create: `rent-a-car/rent-a-car/Services/MotoresAPI/AuthAPIService.swift`
- Create: `rent-a-car/rent-a-car/Views/Auth/PhoneAuthView.swift`
- Modify: `rent-a-car/rent-a-car/rent_a_carApp.swift`

- [ ] **Step 1: Create `AuthAPIService.swift`**

```swift
import Foundation

final class AuthAPIService: ObservableObject {
    @Published var isAuthenticated: Bool = MotoresAPIClient.shared.isAuthenticated

    private let client = MotoresAPIClient.shared

    struct OTPResponse: Decodable { let ok: Bool }
    struct VerifyResponse: Decodable {
        let token: String
        struct User: Decodable { let id: String; let phone: String; let name: String?; let role: String }
        let user: User
    }

    func sendOTP(phone: String) async throws {
        struct Body: Encodable { let phone: String }
        let _: OTPResponse = try await client.request("auth/otp/send", method: "POST", body: Body(phone: phone))
    }

    func verifyOTP(phone: String, code: String) async throws {
        struct Body: Encodable { let phone: String; let code: String }
        let res: VerifyResponse = try await client.request("auth/otp/verify", method: "POST", body: Body(phone: phone, code: code))
        client.setToken(res.token)
        await MainActor.run { isAuthenticated = true }
    }

    func signOut() {
        client.clearToken()
        isAuthenticated = false
    }
}
```

- [ ] **Step 2: Create `Views/Auth/PhoneAuthView.swift`**

```swift
import SwiftUI

struct PhoneAuthView: View {
    @EnvironmentObject var auth: AuthAPIService
    @State private var phone = ""
    @State private var code = ""
    @State private var step: Step = .phone
    @State private var isLoading = false
    @State private var error: String?

    enum Step { case phone, otp }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "steeringwheel")
                    .font(.system(size: 52, weight: .semibold))

                Text(step == .phone ? "Enter your phone" : "Enter the code")
                    .font(.system(size: 24, weight: .bold))

                if step == .phone {
                    TextField("+1 809 555 0000", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .font(.system(size: 18))
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 40)
                } else {
                    TextField("6-digit code", text: $code)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .font(.system(size: 28, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 40)
                }

                if let error { Text(error).foregroundStyle(.red).font(.system(size: 14)).multilineTextAlignment(.center).padding(.horizontal, 40) }

                Button {
                    Task { await handleAction() }
                } label: {
                    Group {
                        if isLoading { ProgressView() }
                        else { Text(step == .phone ? "Send Code" : "Verify").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white) }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color.black).clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 40)
                }
                .disabled(isLoading)

                Spacer()
            }
        }
    }

    private func handleAction() async {
        isLoading = true; error = nil
        do {
            if step == .phone {
                try await auth.sendOTP(phone: phone)
                await MainActor.run { step = .otp }
            } else {
                try await auth.verifyOTP(phone: phone, code: code)
            }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
        await MainActor.run { isLoading = false }
    }
}
```

- [ ] **Step 3: Update `rent_a_carApp.swift`** — inject `AuthAPIService`, gate on auth state

Preserve the existing `init()` block (Firebase + RevenueCat configuration) and `carsStore` / `subscriptionService`. Add `auth` as a new `@StateObject` and gate `AppRootView` on `auth.isAuthenticated`:

```swift
import FirebaseCore
import RevenueCat
import SwiftUI

@main
struct rent_a_carApp: App {
    @StateObject private var carsStore = CarsStore()
    @StateObject private var subscriptionService = SubscriptionService()
    @StateObject private var auth = AuthAPIService()

    init() {
        FirebaseApp.configure()
        #if DEBUG
        assert(FirebaseApp.app() != nil, "Firebase failed to configure.")
        #endif
        SubscriptionService.configure()
    }

    var body: some Scene {
        WindowGroup {
            if auth.isAuthenticated {
                AppRootView()
                    .environmentObject(carsStore)
                    .environmentObject(subscriptionService)
                    .environmentObject(auth)
                    .onAppear { carsStore.start() }
                    .task { await subscriptionService.refresh() }
            } else {
                PhoneAuthView()
                    .environmentObject(auth)
            }
        }
    }
}
```

> **Note:** `FirebaseApp.configure()` and `SubscriptionService.configure()` are kept until Firebase Storage is fully removed (after Task 12). Remove them once you confirm no Firebase dependencies remain.

- [ ] **Step 4: Build in Xcode (`⌘B`)** — confirm no compile errors in new files.

- [ ] **Step 5: Commit**

```bash
git add rent-a-car/rent-a-car/Services/MotoresAPI/AuthAPIService.swift \
        rent-a-car/rent-a-car/Views/Auth/PhoneAuthView.swift \
        rent-a-car/rent-a-car/rent_a_carApp.swift
git commit -m "feat(ios): phone OTP auth flow via Workers API"
```

---

### Task 12: Replace `CarsRepository` with Workers API

**Files:**
- Create: `rent-a-car/rent-a-car/Services/MotoresAPI/VehiclesAPIService.swift`
- Modify: `rent-a-car/rent-a-car/Services/Firebase/CarsRepository.swift`
- Modify: `rent-a-car/rent-a-car/Stores/CarsStore.swift`

- [ ] **Step 1: Create `VehiclesAPIService.swift`**

```swift
import Foundation

final class VehiclesAPIService {
    private let client = MotoresAPIClient.shared

    func fetchAll(type: String? = nil, available: Bool? = nil) async throws -> [Car] {
        var path = "vehicles"
        var params: [String] = []
        if let type { params.append("type=\(type)") }
        if let available { params.append("available=\(available)") }
        if !params.isEmpty { path += "?" + params.joined(separator: "&") }
        return try await client.request(path)
    }

    func fetch(id: String) async throws -> Car {
        try await client.request("vehicles/\(id)")
    }

    func create(car: CarCreateRequest) async throws -> String {
        struct Res: Decodable { let id: String }
        let res: Res = try await client.request("vehicles", method: "POST", body: car)
        return res.id
    }

    func update(id: String, car: CarCreateRequest) async throws {
        struct Res: Decodable { let ok: Bool }
        let _: Res = try await client.request("vehicles/\(id)", method: "PUT", body: car)
    }

    func delete(id: String) async throws {
        struct Res: Decodable { let ok: Bool }
        let _: Res = try await client.request("vehicles/\(id)", method: "DELETE")
    }
}

struct CarCreateRequest: Encodable {
    var name: String
    var type: String
    var price_level: String
    var daily_rate_cents: Int
    var neighborhood: String
    var is_available: Bool
    var available_from: String
    var details: String
    var schedule: [DaySchedule]
    var address: String
    var latitude: Double
    var longitude: Double
    var logo: Car.Logo
}
```

- [ ] **Step 2: Replace `CarsRepository.swift` internals** — keep the file name (so existing callsites don't break) but swap Firestore for `VehiclesAPIService`

```swift
// CarsRepository.swift — now wraps VehiclesAPIService
import Foundation

final class CarsRepository {
    private let api = VehiclesAPIService()

    func fetchActiveCars() async throws -> [Car] {
        try await api.fetchAll()
    }

    func createCar(_ car: CarCreateRequest) async throws -> String {
        try await api.create(car: car)
    }

    func updateCar(id: String, _ car: CarCreateRequest) async throws {
        try await api.update(id: id, car: car)
    }

    func deleteCar(id: String) async throws {
        try await api.delete(id: id)
    }
}
```

- [ ] **Step 3: Update `CarsStore.swift`** — remove `ListenerRegistration`, use async fetch

```swift
import Foundation

@MainActor
final class CarsStore: ObservableObject {
    @Published private(set) var cars: [Car] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastErrorMessage: String?

    private let repo = CarsRepository()

    func start() {
        Task { await load() }
    }

    func load() async {
        isLoading = true
        do {
            cars = try await repo.fetchActiveCars()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func create(car: CarCreateRequest) async throws -> String {
        let id = try await repo.createCar(car)
        await load()
        return id
    }

    func update(id: String, car: CarCreateRequest) async throws {
        try await repo.updateCar(id: id, car)
        await load()
    }

    func delete(id: String) async throws {
        try await repo.deleteCar(id: id)
        await load()
    }

    func clearError() { lastErrorMessage = nil }
}
```

- [ ] **Step 4: Fix `VehicleFormView.swift` call sites**

`VehicleFormView` calls `carsStore.create(car:)` and `carsStore.update(car:)` with a `Car` and uses `StorageService` for image upload. Replace with `CarCreateRequest` and the R2 presign flow:

In `VehicleFormView`, find the `save()` or equivalent submit function and replace:

```swift
// OLD (Firestore):
// let id = try await carsStore.create(car: newCar)
// StorageService().uploadImages(...)

// NEW:
let request = CarCreateRequest(
    name: name, type: type, price_level: priceLevel,
    daily_rate_cents: Int(dailyRateCents) ?? 3000,
    neighborhood: neighborhood, is_available: isAvailable,
    available_from: availableFrom, details: details,
    schedule: schedule, address: address,
    latitude: latitude, longitude: longitude,
    logo: Car.Logo(r: logoR, g: logoG, b: logoB, initials: logoInitials)
)
if let existingCar = car {
    try await carsStore.update(id: existingCar.id, car: request)
} else {
    let newId = try await carsStore.create(car: request)
    // Image upload: call VehiclesAPIService presign/confirm for each picked image
    // (implement in a follow-up or Task 13 cleanup)
}
```

- [ ] **Step 5: Fix `AdminView.swift` call sites**

`AdminView` calls `carsStore.delete(id:)` using `car.docId`. Replace with `car.id` (the new `Car.id` is a plain `String`):

```swift
// OLD: context.delete(cars[index])  (SwiftData)
// NEW:
Task {
    try? await carsStore.delete(id: car.id)
}
```

- [ ] **Step 6: Build in Xcode (`⌘B`)** — resolve any remaining type errors.

- [ ] **Step 7: Commit**

```bash
git add rent-a-car/rent-a-car/Services/ rent-a-car/rent-a-car/Stores/ \
        rent-a-car/rent-a-car/VehicleFormView.swift rent-a-car/rent-a-car/AdminView.swift
git commit -m "feat(ios): replace Firestore CarsRepository with Workers API"
```

---

### Task 13: Wire bookings + fix `RentCheckoutView`

**Files:**
- Create: `rent-a-car/rent-a-car/Services/MotoresAPI/BookingsAPIService.swift`
- Modify: `rent-a-car/rent-a-car/RentCheckoutView.swift`

- [ ] **Step 1: Create `BookingsAPIService.swift`**

```swift
import Foundation

struct BookingResponse: Decodable {
    let booking_id: String
    let subtotal_cents: Int
    let service_fee_cents: Int
    let total_amount_cents: Int
    let currency: String
    let stripe_client_secret: String
    let status: String
}

final class BookingsAPIService {
    private let client = MotoresAPIClient.shared

    func createBooking(vehicleId: String, startDate: String, endDate: String) async throws -> BookingResponse {
        struct Body: Encodable { let vehicle_id: String; let start_date: String; let end_date: String }
        return try await client.request("bookings", method: "POST", body: Body(vehicle_id: vehicleId, start_date: startDate, end_date: endDate))
    }
}
```

- [ ] **Step 2: Update `RentCheckoutView.swift`** — replace hardcoded price switch with server-side `daily_rate_cents`, call API on reserve

Replace:
```swift
private var dailyRate: Double {
    switch car.priceLevel {
    case "$":    return 30
    case "$$":   return 60
    case "$$$":  return 100
    default:     return 50
    }
}
```

With:
```swift
private var dailyRate: Double { car.dailyRateUSD }
```

Add state + booking call:
```swift
@State private var isBooking = false
@State private var bookingError: String?
@StateObject private var bookingsService = BookingsAPIService()
// (declare as let and use .shared or pass in)

private var dateFormatter: DateFormatter {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
}
```

Replace the Reserve button action:
```swift
Button {
    Task {
        isBooking = true
        bookingError = nil
        do {
            let res = try await BookingsAPIService().createBooking(
                vehicleId: car.id,
                startDate: dateFormatter.string(from: startDate),
                endDate: dateFormatter.string(from: endDate)
            )
            // TODO Task 14: present Stripe payment sheet with res.stripe_client_secret
            showConfirmation = true
        } catch {
            bookingError = error.localizedDescription
        }
        isBooking = false
    }
} label: { ... }
```

- [ ] **Step 3: Build (`⌘B`)** — no errors.

- [ ] **Step 4: Commit**

```bash
git add rent-a-car/rent-a-car/Services/MotoresAPI/BookingsAPIService.swift \
        rent-a-car/rent-a-car/RentCheckoutView.swift
git commit -m "feat(ios): wire bookings API, fix dailyRate to use server value"
```

---

### Task 14: Stripe iOS SDK payment sheet

**Files:**
- Modify: `rent-a-car/rent-a-car.xcodeproj` (add Stripe package)
- Modify: `rent-a-car/rent-a-car/RentCheckoutView.swift`

- [ ] **Step 1: Add Stripe iOS SDK in Xcode**

In Xcode: File → Add Package Dependencies → `https://github.com/stripe/stripe-ios` → Add `StripePaymentSheet`

- [ ] **Step 2: Update `RentCheckoutView` to present PaymentSheet**

```swift
import StripePaymentSheet

// Add state
@State private var paymentSheet: PaymentSheet?

// After createBooking succeeds, configure and present:
var config = PaymentSheet.Configuration()
config.merchantDisplayName = "MOTORES"
let sheet = PaymentSheet(paymentIntentClientSecret: res.stripe_client_secret, configuration: config)
paymentSheet = sheet
```

Add `.paymentSheet` modifier to the view:
```swift
.paymentSheet(isPresented: Binding(get: { paymentSheet != nil }, set: { if !$0 { paymentSheet = nil } }),
               paymentSheet: paymentSheet ?? PaymentSheet(paymentIntentClientSecret: "", configuration: .init())) { result in
    switch result {
    case .completed: showConfirmation = true
    case .failed(let error): bookingError = error.localizedDescription
    case .canceled: break
    }
    paymentSheet = nil
}
```

- [ ] **Step 3: Set Stripe publishable key** — in `rent_a_carApp.swift`:

```swift
import StripeCore

// Inside App.init() or first scene:
STPAPIClient.shared.publishableKey = "pk_live_YOUR_KEY"
```

- [ ] **Step 4: Build and test on simulator** — tap Reserve, Stripe sheet should appear with test card `4242 4242 4242 4242`.

- [ ] **Step 5: Commit**

```bash
git add rent-a-car/
git commit -m "feat(ios): Stripe PaymentSheet for booking checkout"
```

---

## Done

At this point:
- The Cloudflare Workers API is live at `https://motores-api.<subdomain>.workers.dev`
- The iOS app authenticates via phone OTP, loads vehicles from D1, and creates bookings paid via Stripe
- Firebase/Firestore is no longer used for vehicles or auth (Firebase package can be removed in a cleanup pass)
