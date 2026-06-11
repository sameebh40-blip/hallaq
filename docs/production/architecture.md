# HALLAQ Production Architecture

## Domains

- https://hallaq.com
  - Landing site (Next.js app: `apps/landing`)
- https://app.hallaq.com
  - Customer web app (Next.js app: `apps/customer`)
- https://business.hallaq.com
  - Shop/business desktop portal (Next.js app: `apps/shop`)
- https://admin.hallaq.com
  - Admin portal (Next.js app: `apps/admin`)
- https://api.hallaq.com
  - Reserved for future API gateway (Supabase remains the current backend)

## Routing Modes

The codebase supports two modes controlled by `NEXT_PUBLIC_HALLAQ_ROUTING_MODE`.

### Subdomain Mode (Production)

- `landing` runs on `hallaq.com`
- `customer` runs on `app.hallaq.com`
- `shop` runs on `business.hallaq.com`
- `admin` runs on `admin.hallaq.com`
- Role-based navigation redirects across subdomains using:
  - `NEXT_PUBLIC_LANDING_URL`
  - `NEXT_PUBLIC_APP_URL`
  - `NEXT_PUBLIC_BUSINESS_URL`
  - `NEXT_PUBLIC_ADMIN_URL`

### Path Mode (Development / Staging)

All apps can still run locally without relying on subdomains.

- Customer app: `/`
- Shop app: `/shop` (Next `basePath`)
- Admin app: optional `/admin` path behavior remains supported

## Authentication (Supabase)

- Web apps use Supabase Auth with `/auth/callback` implemented in:
  - `apps/customer/src/app/auth/callback/route.ts`
  - `apps/shop/src/app/auth/callback/route.ts`
  - `apps/admin/src/app/auth/callback/route.ts`

## Projects

- Web monorepo (Next.js): `apps/*` + shared packages `packages/*`
- Mobile/web client (Flutter): root `lib/*` and `web/*`
- Backend (Supabase): `supabase/migrations/*` and `supabase/functions/*`

