# Yalla Cash NestJS API

Production-oriented REST API for the Yalla Cash loyalty/cashback platform.

## Stack

- NestJS 11
- Prisma 6
- PostgreSQL 16
- JWT access/refresh tokens
- bcrypt password hashing for admin/merchant users
- Firebase Admin verification for Google/Facebook customer OAuth
- OTP challenge storage for phone login
- Global API throttling with tighter auth limits

## Local Setup

```bash
cd backend/nestjs
cp .env.example .env
docker compose up -d
pnpm install
pnpm prisma:generate
pnpm prisma:migrate
pnpm prisma:seed
pnpm start:dev
```

When using the bundled Codex runtime on Windows, prepend the bundled Node path before pnpm commands if `node` is not on PATH.

## Important Environment Variables

- `DATABASE_URL`: PostgreSQL connection string.
- `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`: separate token secrets.
- `QR_TOKEN_SECRET`: signs short-lived customer QR tokens.
- `SECRET_PEPPER`: server-side HMAC pepper for OTP, refresh-token hashes, and device fingerprints.
- `OTP_DEV_MODE`: returns `devCode` from OTP start in local development only.
- `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`: required for Google/Facebook OAuth token verification.
- `CORS_ORIGINS`: comma-separated origins allowed to call the API.

## Main API Areas

- `POST /auth/customer/phone/start`
- `POST /auth/customer/phone/verify`
- `POST /auth/customer/oauth`
- `POST /auth/merchant/login`
- `POST /auth/admin/login`
- `POST /auth/refresh`
- `POST /auth/logout`
- `GET /stores`
- `GET /customer/profile`
- `GET /customer/points`
- `POST /customer/qr-token`
- `GET /customer/transactions`
- `GET /customer/digital-products`
- `POST /customer/redemptions/cash`
- `POST /customer/redemptions/products`
- `GET /merchant/me`
- `POST /merchant/qr/resolve`
- `POST /merchant/invoices`
- `GET /merchant/summary`
- `GET /admin/overview`
- `GET /admin/customers`
- `POST /admin/customers/:customerId/points/grant`
- `POST /admin/customers/:customerId/points/deduct`
- `GET /admin/cash-requests`
- `POST /admin/cash-requests/:requestId/resolve`
- `GET|POST|PATCH /admin/stores`
- `GET|POST|PATCH /admin/products`
- `GET|POST /admin/merchant-accounts`
- `GET|PATCH /admin/settings`
- `GET /admin/settlements`
- `POST /admin/settlements/settle`

All authenticated endpoints return predictable JSON errors:

```json
{
  "statusCode": 400,
  "code": "bad_request",
  "message": "Validation failed",
  "path": "/customer/redemptions/cash",
  "timestamp": "2026-08-18T00:00:00.000Z"
}
```

## Business Rules

- Stores are exclusive: one active store per `city + category`.
- Merchant invoices are idempotent by `idempotencyKey`.
- Commission and customer points are calculated only on the backend.
- Each transaction stores commission-rate and point-value snapshots.
- Points changes are written to `PointsLedgerEntry`.
- Cash redemption requests reserve points while pending and deduct only after admin settlement.
- Customer QR tokens are signed and short-lived.

## Verification

```bash
pnpm build
pnpm test
```
