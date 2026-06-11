# Production Readiness Report

## What Was Fixed / Prepared

### Domain architecture + routing

- Added a routing utility to support both `path` and `subdomain` deployments:
  - `NEXT_PUBLIC_HALLAQ_ROUTING_MODE=path|subdomain`
  - Central helper: `@hallaq/supabase/routing`
- Shop app now supports:
  - `path` mode: mounted at `/shop`
  - `subdomain` mode: mounted at `/` on `business.hallaq.com`

### Environment system & secrets

- Added:
  - `.env.development`
  - `.env.production`
  - Updated `.env.example`
- Tightened `.gitignore` so secrets stay local (`.env.local`, `*.local`), while allowing committed templates.
- Removed committed Supabase URL/keys from:
  - root `.env.local` and app `.env.local` files
  - Flutter `lib/config/app_config.dart` (replaced with placeholders)
  - Flutter `assets/config/app.env` (replaced with placeholders)
- Flutter now relies on `--dart-define` (and no longer auto-loads `assets/config/app.env` or `AppConfig` as a fallback).

### Authentication preparation

- Role-based redirect URLs are now environment-aware and support cross-subdomain redirects.
- Supabase local `config.toml` redirect URLs were expanded to include production callback endpoints for documentation parity.
- Updated QA magic-link generation to use `NEXT_PUBLIC_APP_URL` (no hardcoded domain).

### Business portal

- The desktop business portal UI shell already existed; the routing is now production-ready:
  - `/business/*` routes are implemented and connected to the existing shell and navigation.
  - Key sections are functional (dashboard/bookings/calendar/barbers/services/reels/products/offers/customers/notifications).

### SEO (Landing)

- Added a dedicated landing Next.js app (`apps/landing`) with:
  - metadata + OpenGraph + Twitter cards
  - `robots.txt` and `sitemap.xml`
  - structured data (Organization JSON-LD)
  - generated favicon + OG images (Next image routes)

### Security / Role System

Added migrations that harden roles and prevent role drift:

- `20260611170000_role_sync_and_shop_claim_hardening.sql`
  - Synces both old + new owners when shop ownership changes
  - Prevents “barber → shop_owner” via claim approval
- `20260611174000_barbers_shop_assignment_guard.sql`
  - Prevents a barber from self-assigning themselves to a shop via direct `barbers.shop_id` update

## Remaining Actions (Needs Credentials / Dashboard Access)

- Vercel: create 4 projects, configure domains, and set production environment variables.
- GoDaddy: create A/CNAME records.
- Supabase Dashboard:
  - Set Site URL to `https://app.hallaq.com`
  - Add redirect URLs for each subdomain `/auth/callback`
  - Confirm email template URLs
  - Verify Storage policies and buckets are applied in your production project
  - Apply new migrations in production

## Production Readiness Score

- Codebase readiness: High (routing/env/auth/business+admin portals ready)
- Deployment readiness: Pending (requires DNS + Vercel + Supabase dashboard settings)

