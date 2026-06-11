# Production Deployment Checklist (hallaq.com)

## 1) GoDaddy DNS (Vercel)

### Apex domain

- A record
  - Name: `@`
  - Type: `A`
  - Value: `76.76.21.21`
  - TTL: default

### Subdomains

Create CNAME records:

- `app` → `cname.vercel-dns.com`
- `business` → `cname.vercel-dns.com`
- `admin` → `cname.vercel-dns.com`
- `api` → (reserved; point later to the API gateway of your choice)

## 2) Vercel Projects (Monorepo)

Create 4 separate Vercel projects pointing to the same repo.

- **Landing**
  - Root Directory: `apps/landing`
  - Build Command: `npm run build`
  - Output Directory: `.next`
  - Domains: `hallaq.com`, `www.hallaq.com` (optional)
- **Customer**
  - Root Directory: `apps/customer`
  - Build Command: `npm run build`
  - Output Directory: `.next`
  - Domain: `app.hallaq.com`
- **Business**
  - Root Directory: `apps/shop`
  - Build Command: `npm run build`
  - Output Directory: `.next`
  - Domain: `business.hallaq.com`
- **Admin**
  - Root Directory: `apps/admin`
  - Build Command: `npm run build`
  - Output Directory: `.next-build`
  - Domain: `admin.hallaq.com`

## 3) Vercel Environment Variables (Production)

Set these in each web project (Production environment):

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `NEXT_PUBLIC_HALLAQ_ROUTING_MODE=subdomain`
- `NEXT_PUBLIC_LANDING_URL=https://hallaq.com`
- `NEXT_PUBLIC_APP_URL=https://app.hallaq.com`
- `NEXT_PUBLIC_BUSINESS_URL=https://business.hallaq.com`
- `NEXT_PUBLIC_ADMIN_URL=https://admin.hallaq.com`
- `NEXT_PUBLIC_API_URL=https://api.hallaq.com`

Admin project only:

- `SUPABASE_SERVICE_ROLE_KEY`
- `FFMPEG_PATH` (optional; typically not needed on Vercel)

## 4) Supabase Auth Settings

In Supabase Dashboard:

- **Site URL**
  - Set to `https://app.hallaq.com`
- **Redirect URLs**
  - Add:
    - `https://app.hallaq.com/auth/callback`
    - `https://business.hallaq.com/auth/callback`
    - `https://admin.hallaq.com/auth/callback`
    - `https://hallaq.com/auth/callback`

Email templates (confirm / invite / reset):

- Ensure links use one of the domains above and land on `/auth/callback` (or the corresponding reset route used by your UI).

## 5) Supabase Storage

Verify buckets and policies are applied via migrations:

- Public media buckets: `avatars`, `profile-covers`, `shop-images`, `service-images`, `products`, `product-images`, `brand-assets`
- Private moderated media buckets: `reels`, `reels-media`, `post-media`

Optional hardening (if you want to prevent anonymous listing/enumeration):

- Restrict `storage.objects` SELECT policies to `authenticated` only, while keeping `bucket.public=true` for public asset fetch.

## 6) SSL / Redirects

- Vercel automatically provisions SSL for all assigned domains.
- Optional:
  - Redirect `www.hallaq.com` → `hallaq.com`

## 7) Post-deploy Validation

- Visit each domain:
  - `https://hallaq.com`
  - `https://app.hallaq.com`
  - `https://business.hallaq.com`
  - `https://admin.hallaq.com`
- Verify role routing:
  - customer → app
  - shop_owner/receptionist → business
  - admin → admin

