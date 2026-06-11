# Hallaq E2E Checklist (Booking + Ops Final Pass)

## Release gate
- Apply all pending Supabase migrations before running this checklist.
- The linked project checked during QA was behind the repo and did **not** yet contain:
  - `20260610150000_create_booking_safely_with_hold.sql`
  - `20260611100000_booking_reminders_catchup_safe.sql`
  - `20260611123000_admin_push_health_and_booking_qa.sql`
- Customer/Admin/Shop web builds pass locally.
- Targeted Flutter analyzer pass is clean for the touched booking/dashboard files.

## Required env + config
- Customer/Admin/Shop web apps have working Supabase URL + anon key env vars.
- Supabase `app_config` contains:
  - `push_url`
  - `push_secret`
- Cron jobs expected:
  - `push_worker`
  - `booking_reminders`

## Booking entry points
- Home: Book Now opens booking flow and carries the correct IDs.
- Discover reel: Book With Barber carries reel + barber/shop context.
- Barber profile: Book Now preselects the barber.
- Shop profile: Book Now preselects the shop.
- Search result: booking opens with the selected entity context.
- Hallaq City: booking opens with the selected entity context.
- QR-scanned barber profile: booking opens with that barber.
- QR-scanned shop profile: booking opens with that shop.

## Booking flow
- Select barber/shop works with real data.
- Service list only shows valid/active services.
- Date picker disables past/closed/fully booked dates.
- Time slots come from real availability RPCs.
- Review step shows barber, shop, service, date, time, and total.
- Payment step allows `cash` and keeps other methods as coming soon.
- Confirm action creates bookings only through `create_booking_safely(...)`.
- If the slot is lost, the UI shows a clean retry message instead of a crash.

## Availability + double-booking protection
- Working hours are respected.
- Breaks and blocked times are respected.
- Barber time off / vacation is respected.
- Existing bookings block overlapping slots.
- Slot holds are consumed once a booking is created.
- The same slot cannot be booked twice from two clients.

## Cross-surface sync
- After booking creation, the booking appears in:
  - Customer My Bookings
  - Shop dashboard
  - Admin appointments
  - Flutter booking surfaces tied to the same profile
- After cancellation/reschedule/completion, all surfaces refresh correctly.

## Cancellation
- Customer can cancel.
- Barber can cancel.
- Shop can cancel.
- Admin can cancel.
- Cancel flow stores:
  - `status = cancelled`
  - `cancelled_by_profile_id`
  - `cancel_reason` / `cancelled_reason` fallback-safe display
  - `cancelled_at`
- UI clearly labels origin:
  - Cancelled by You / Client / Barber / Shop / HALLAQ

## Reschedule
- Customer/Admin/Shop reschedule screens open correctly.
- New time is revalidated before commit.
- Old reminder log entries are cleared when `start_at` changes.
- Rescheduled bookings keep a consistent visible status across surfaces.

## Notifications + reminders
- Booking confirmed notifications are created.
- Cancellation notifications are created.
- Reschedule notifications are created.
- Completion notifications are created.
- Reminder worker only targets `confirmed` / `rescheduled` bookings.
- Reminder windows are catch-up safe for 2h / 1h / 15m.
- Rescheduled bookings do not keep stale reminder dedupe entries.

## Admin QA pages
- `/booking-qa` loads and shows PASS/FAIL data from `admin_booking_qa_report()`.
- `/push-health` loads and shows queue counts, config flags, and cron status from `admin_get_push_delivery_health()`.
- If either page fails with missing RPCs, migrations are not fully applied in the target project.

## Non-booking regression checks
- Admin creates/approves a shop and barber successfully.
- Posts/reels approval flow still works.
- Maintenance mode still redirects customer/shop correctly.
- Soft delete + restore still works for shop/barber/reel records.
