# [OPEN] booking-flow-connection

## Summary
- Symptom: booking flow is not fully connected; barbers/services are not shown on booking screens and booking-related pages still surface runtime errors.
- Scope: customer booking flow, supporting booking RPCs/schema, and pages relying on shop memberships / booking-linked data.

## Hypotheses
1. Customer booking UI queries are hitting stale tables/views or mismatched column names, causing empty barber/service results.
2. A schema drift around `shop_memberships` breaks one or more pages before booking dependencies load.
3. Mobile booking flow state progresses to barber-selected, but the services fetch never completes into renderable state.
4. RLS/auth context prevents customer-mode reads for booking discovery queries.
5. Booking RPC/schema mismatches still exist and cascade into empty availability or failed booking setup.

## Evidence Plan
- Instrument web customer booking flow fetches for barber/service/day/time loading.
- Instrument Flutter booking flow service-loading path and render state.
- Inspect schema use of `shop_memberships` and booking discovery dependencies.

## Status
- Confirmed root cause 1: shop booking on client/mobile only surfaced shop-owned services, so shops with barber-owned services appeared empty.
- Confirmed root cause 2: booking flow did not switch service loading to the chosen barber once a barber was selected in shop-origin booking.
- Confirmed backend drift: `hold_booking_slot` had ambiguous `shop_id` usage and a missing emitted row.
- Applied fixes in customer web, Flutter booking, and booking migration files.
