# Yalla Cash Architecture

## Domain

Yalla Cash is a Syrian SYP loyalty/cashback system:

- Customers collect points after showing a QR at checkout.
- Merchants scan QR codes and enter invoice amounts.
- Admins manage stores, products, customers, point value, cash requests, and monthly settlements.
- One active store is exclusive per city/category.

## Backend

`backend/nestjs` is the source of truth for money, points, and permissions.

Main modules:

- `AuthModule`: phone OTP, Firebase OAuth token verification, merchant/admin password login, refresh-token rotation.
- `CustomerModule`: profile, points, QR issuing, transactions, cash/product redemptions.
- `MerchantModule`: device registration, QR resolution, idempotent invoices, summaries.
- `AdminModule`: operations, settings, stores, products, merchant accounts, settlements.
- `StoresModule`: public active-store listing.
- `PrismaModule`: PostgreSQL access.

Database highlights:

- `CustomerProfile.pointsBalance` stores the full balance.
- Pending cash requests reserve points without deducting them.
- `PointsLedgerEntry` records every balance-affecting action.
- `LoyaltyTransaction` stores commission-rate and point-value snapshots.
- Partial indexes enforce exclusivity and one pending cash request per customer.

## Flutter

The original app files remain the visual/UX reference. The shared package now contains a production integration layer:

```text
packages/yalla_cash_core/lib/src/
  config/
  core/
  data/
  domain/
  presentation/
```

- `domain/yalla_cash_repository.dart`: repository contract, DTO-like app models, feature snapshots.
- `data/remote_yalla_cash_repository.dart`: REST implementation for NestJS.
- `data/in_memory_yalla_cash_repository.dart`: demo/offline implementation for previews and tests.
- `data/yalla_cash_api_client.dart`: HTTP, token storage, refresh retry, error mapping.
- `presentation/yalla_cash_cubits.dart`: Customer, Merchant, and Admin Cubits with loading/success/empty/failure states.
- `yalla_cash_runtime.dart`: composition root that selects remote or demo repository.

Build-time Flutter flags:

```bash
--dart-define=YALLA_CASH_USE_REMOTE=true
--dart-define=YALLA_CASH_API_BASE_URL=http://localhost:3000
```

The existing screens can now be migrated incrementally from `YallaCashStore.demo()` to the Cubits while preserving the current layout and Arabic visual identity.
