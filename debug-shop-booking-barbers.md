[OPEN] shop-booking-barbers

- Symptom: Shop booking flow still shows "No barbers available" after assignment, migration, and backfill.
- Scope: Public shop page and booking flow for shop-based bookings.

## Hypotheses

1. The booking screen is receiving a different `shopId` than the one the barber is assigned to.
2. `barbersForShopProvider` is returning an empty list at runtime due to a query or RLS condition not covered by the static fixes.
3. The selected shop service is filtering barbers out through `shopEligibleBarbersForServiceProvider`.
4. The shop page is opening booking before provider invalidation/cache refresh, so stale empty data is shown.
5. The barber exists for the shop, but availability/working-hours logic removes them later and the UI collapses to the same empty state.

## Plan

1. Add instrumentation only to capture `shopId`, returned barber count, barber IDs, selected service ID, and eligible barber count.
2. Reproduce the issue and inspect logs.
3. Confirm or reject hypotheses with evidence.
4. Apply the smallest logic fix only after evidence points to the root cause.
