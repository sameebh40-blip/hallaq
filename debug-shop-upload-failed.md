[OPEN] Debug Session: shop-upload-failed

## Scope
- Shop Manage Profile: change cover/logo → shows "Upload failed."
- Related: bookings still failing for shop/barber (secondary after upload root cause)

## Environment
- Flutter Web (localhost)
- Supabase backend (RLS + Storage)

## Hypotheses
- H1 (RLS): Storage upload is rejected by RLS (403) because auth user is not recognized as shop owner / wrong owner_profile_id mapping.
- H2 (Auth): Supabase session is missing/expired in web build, so storage upload returns 401.
- H3 (Bucket/Path): Upload path or bucket doesn't match storage policies (e.g., path prefix not `shops/<uuid>/...`).
- H4 (CORS/Network): Browser blocks the storage upload (CORS/mixed-content) or request never reaches Supabase.
- H5 (Processing): Image processing fails before upload (decode/encode), throwing an exception that gets humanized to "Upload failed."

## Evidence Plan
- Reproduce on Flutter Web and capture:
  - Browser console errors + network request status
  - Supabase storage request response (status + body)
  - Any thrown exception message/stack (Flutter console)

## Runs
- pre: pending
- post: pending

