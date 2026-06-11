# Ops + Health

## Health Pages
- Admin: `/health`
- Shop: `/shop/health`
- Customer: `/health`

These pages show:
- Whether Supabase env vars are configured
- Whether Supabase is reachable

## Maintenance Mode
- Flag key: `maintenance_mode` in `public.admin_settings`
- Enforcement:
  - Shop middleware redirects non-admins to `/shop/maintenance`
  - Customer middleware redirects to `/maintenance`

## Customer Signup Gate
- Flag key: `allow_customer_signup`
- Enforcement:
  - Customer web sign-up blocks when disabled
  - Flutter sign-up blocks when disabled

## Supabase Migrations
- Link the repo to your Supabase project:
  - `supabase link`
- Push all pending migrations:
  - `supabase db push`

### Booking release minimum
- The booking flow depends on these newer migrations being present in the target project:
  - `20260610150000_create_booking_safely_with_hold.sql`
  - `20260611100000_booking_reminders_catchup_safe.sql`
  - `20260611123000_admin_push_health_and_booking_qa.sql`
- The linked project checked during final QA was still behind these migrations, so the new admin QA and push health pages will not work there until migrations are applied.

### Expected booking RPCs
- `create_booking_safely(...)`
- `hold_booking_slot(...)`
- `get_available_days(...)`
- `get_available_times(...)`
- `cancel_booking(...)`
- `reschedule_booking(...)`
- `send_booking_reminders(...)`
- `claim_push_queue(...)`
- `run_push_worker_http()`

## Booking QA pages
- Admin: `/booking-qa`
  - Uses `admin_booking_qa_report()`
  - Confirms required tables, booking RPCs, and cron availability
- Admin: `/push-health`
  - Uses `admin_get_push_delivery_health()`
  - Shows queue backlog, oldest pending age, and whether push config/cron are set

### Interpreting failures
- If `/booking-qa` fails with missing RPCs, the database is behind the repo migrations.
- If `/push-health` shows `push_url_set = false` or `push_secret_set = false`, reminder and push delivery is not fully configured.
- If cron is unavailable or the `push_worker` / `booking_reminders` jobs are missing, notifications may queue without being delivered.

## PostgREST Schema Cache
Run this in Supabase SQL editor after schema changes (new columns/policies/views), then refresh the app:

```sql
notify pgrst, 'reload schema';
```

## DB Health Check
Run the health check SQL after applying migrations:
- File: [db_health.sql](file:///c:/Users/k/Desktop/hallaq/supabase/tests/db_health.sql)
- Run it in Supabase SQL editor.

## Release verification sequence
- 1. Apply all pending migrations.
- 2. Reload PostgREST schema cache.
- 3. Open `/booking-qa` and verify all required checks pass.
- 4. Open `/push-health` and verify:
  - queue is not stuck
  - push config flags are set
  - cron jobs exist
- 5. Book, cancel, and reschedule one real test booking.
- 6. Confirm customer, shop, and admin views all update.
