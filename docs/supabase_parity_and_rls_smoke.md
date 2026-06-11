# Supabase Parity + RLS Smoke

## Apply DB migrations (recommended)

Run the missing/updated migrations on your Supabase project (SQL Editor as `postgres`, or via Supabase CLI `supabase db push` if you use it).

Key fixes added/updated in this repo:

- `0043_fix_rls_helper_recursion.sql`: prevents `is_admin()`/RLS recursion stack overflow
- `0045_fix_create_booking_rpc_param_ambiguity.sql`: fixes `create_booking(...)` parameter ambiguity
- `0046_fix_notify_rls.sql`: makes `notify(...)` work from triggers by bypassing RLS safely
- `0037_booking_slot_settings_and_buffer.sql`: adds `buffer_minutes` columns required by booking RPCs (and fixes reserved keyword usage)

## Run the RLS smoke test

1. Supabase Dashboard → SQL Editor → New query
2. Paste the full file and run:
   - `supabase/tests/rls_smoke.sql`

Expected result:
- No errors
- You may see a NOTICE like: `RLS smoke test passed (rolled back).`

## Notes

- Don’t run snippets from the smoke test; run the whole script.
- Avoid pasting UI text like `Export / Source / Role / Run` into the SQL editor.
- Never paste or commit `SUPABASE_SERVICE_ROLE_KEY` anywhere in the repo. Keep it only in `.env.local` (ignored by git).
