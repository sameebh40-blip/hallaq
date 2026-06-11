# Environment System

## Files

- `.env.development` (committed template)
- `.env.production` (committed template)
- `.env.example` (committed template)
- `.env.local` (developer-local only; ignored by git)

## Required Variables (Web)

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`

## Domain & Routing Variables (Web)

- `NEXT_PUBLIC_HALLAQ_ROUTING_MODE`
  - `path` for development
  - `subdomain` for production
- `NEXT_PUBLIC_LANDING_URL`
- `NEXT_PUBLIC_APP_URL`
- `NEXT_PUBLIC_BUSINESS_URL`
- `NEXT_PUBLIC_ADMIN_URL`
- `NEXT_PUBLIC_API_URL` (reserved / optional)
- `NEXT_PUBLIC_SHOP_BASE_PATH` (used only in `path` mode; default `/shop`)
- `NEXT_PUBLIC_ADMIN_BASE_PATH` (used only in `path` mode; default `/admin`)

## Admin-only Variables

- `SUPABASE_SERVICE_ROLE_KEY` (admin app server-side operations only)
- `FFMPEG_PATH` (optional, local development for media processing)

## Supabase Edge Functions

See `supabase/functions/.env.example` for required secrets:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `PUSH_SECRET`
- `FCM_SERVER_KEY`
- `FCM_SERVICE_ACCOUNT_JSON`
- `PUSH_WEBHOOK_SECRET`

## Flutter

Flutter reads config from `--dart-define` (preferred for production):

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_DEBUG`
- `ADMIN_PANEL_URL`

