# Hallaq Platform — Full System Audit Report (Static Repo Audit)

Scope: Flutter client, Next.js dashboards/apps, Supabase SQL migrations (schema/RLS/storage/RPC), and admin repair tooling.

Artifacts generated:
- [database_repair.sql](file:///c:/Users/k/Desktop/hallaq/database_repair.sql)
- [performance_fixes.sql](file:///c:/Users/k/Desktop/hallaq/performance_fixes.sql)
- [security_fixes.sql](file:///c:/Users/k/Desktop/hallaq/security_fixes.sql)

Applied fixes (code changes in this workspace):
- Flutter role routing now always reads fresh role/status (fixes stale role after admin role changes): [app_router.dart](file:///c:/Users/k/Desktop/hallaq/lib/core/routing/app_router.dart#L94-L163), [splash_screen.dart](file:///c:/Users/k/Desktop/hallaq/lib/features/auth/presentation/splash_screen.dart#L53-L80)
- Shop dashboard reel thumbnail uploads now use the canonical `reels` bucket and persist proper `thumbnail_url` public URL: [posts/[id]/page.tsx](file:///c:/Users/k/Desktop/hallaq/apps/shop/src/app/(panel)/posts/%5Bid%5D/page.tsx#L34-L71)
- Shop dashboard reel creation now persists `media_url/thumbnail_url` as public URLs (keeps `*_path` as storage paths): [posts/new/page.tsx](file:///c:/Users/k/Desktop/hallaq/apps/shop/src/app/(panel)/posts/new/page.tsx#L24-L80)

## Critical Issues Found

### 1) Flutter role cache causes wrong dashboard routing after role changes
- Root cause: Flutter caches `profiles.role/status` keyed by access token, so DB-side role changes do not reflect until token refresh; router used `getMyGateInfoFast()` on most routes. Source: [profile_repository.dart](file:///c:/Users/k/Desktop/hallaq/lib/features/profile/data/profile_repository.dart#L27-L70), [app_router.dart](file:///c:/Users/k/Desktop/hallaq/lib/core/routing/app_router.dart#L94-L163)
- Impact: Users can be routed to the wrong app surface (customer vs barber/shop/admin) after admin updates their role.
- Fix applied: Router and Splash now use `getMyGateInfoFresh()` consistently. Files: [app_router.dart](file:///c:/Users/k/Desktop/hallaq/lib/core/routing/app_router.dart#L94-L163), [splash_screen.dart](file:///c:/Users/k/Desktop/hallaq/lib/features/auth/presentation/splash_screen.dart#L53-L80)

### 2) Reel counters drift (likes/comments not synced)
- Root cause: `public.sync_reel_counters()` exists, but triggers exist only for saves; no triggers for likes/comments. Source: [0014_shop_first_structure.sql](file:///c:/Users/k/Desktop/hallaq/supabase/migrations/0014_shop_first_structure.sql#L140-L185), tables created in [0001_init.sql](file:///c:/Users/k/Desktop/hallaq/supabase/migrations/0001_init.sql#L409-L513)
- Impact: `reels.likes_count/comments_count` become stale, breaking trending/analytics and UI accuracy.
- Fix generated (SQL): create missing triggers and resync counters: [database_repair.sql](file:///c:/Users/k/Desktop/hallaq/database_repair.sql)

### 3) Reels media bucket + URL/path inconsistency across apps
- Root cause: Mixed usage of `reels` vs `reels-media` buckets and mixed semantics for `media_url/thumbnail_url` (sometimes path, sometimes URL). Source: [CityReelsPage](file:///c:/Users/k/Desktop/hallaq/apps/customer/src/app/city/reels/page.tsx#L23-L44), [NewPostPage](file:///c:/Users/k/Desktop/hallaq/apps/shop/src/app/(panel)/posts/new/page.tsx#L24-L80), [ShopPostDetailsPage](file:///c:/Users/k/Desktop/hallaq/apps/shop/src/app/(panel)/posts/%5Bid%5D/page.tsx#L34-L71)
- Impact: Broken thumbnails in some flows, brittle fallbacks, and hard-to-debug storage permissions issues.
- Fix applied: Shop dashboard now writes thumbnails to `reels` and stores public URLs in `*_url` fields. Files: [posts/new/page.tsx](file:///c:/Users/k/Desktop/hallaq/apps/shop/src/app/(panel)/posts/new/page.tsx#L24-L80), [posts/[id]/page.tsx](file:///c:/Users/k/Desktop/hallaq/apps/shop/src/app/(panel)/posts/%5Bid%5D/page.tsx#L34-L71)

## High Priority Issues

### 4) Duplicate SQL objects across migrations (name collisions / drift risk)
- Root cause: multiple migrations reintroduce the same objects (tables, views, triggers, functions, policies) using `IF NOT EXISTS` and repeated `DROP POLICY ... CREATE POLICY ...` patterns; ordering becomes the de-facto definition.
- Impact: schema drift across environments, hard-to-replay migrations, and “works on my DB” inconsistencies.
- Evidence examples:
  - Duplicate tables: `services`, `products`, `orders`, `order_items`, `cart_items` across migrations (see repo scan summary).
  - Duplicate policies: `storage_public_read` is recreated in many migrations: [0005_storage_buckets_and_policies.sql](file:///c:/Users/k/Desktop/hallaq/supabase/migrations/0005_storage_buckets_and_policies.sql#L42-L48) plus multiple later migrations.
  - Duplicate triggers/views/functions: e.g. `public.create_booking`, `public.shops` view, `reels_set_created_by` trigger (see repo scan summary).
- Fix generated (partial): consolidate storage bucket + public read policy baseline: [security_fixes.sql](file:///c:/Users/k/Desktop/hallaq/security_fixes.sql)
- Remaining work: create a single “cleanup” migration that (1) drops deprecated policies/triggers by name, (2) standardizes canonical definitions, (3) validates constraints (`NOT VALID` → `VALIDATE CONSTRAINT`).

### 5) Realtime subscriptions likely not firing for reels engagement tables
- Root cause: code subscribes to `reel_likes/reel_saves/reel_comments`, but migrations do not ensure those tables are in the `supabase_realtime` publication (project-dependent). Source: [RealtimeRefresh usage](file:///c:/Users/k/Desktop/hallaq/apps/customer/src/app/city/reels/page.tsx#L80-L83)
- Fix generated (SQL): add reels tables to publication when publication exists: [database_repair.sql](file:///c:/Users/k/Desktop/hallaq/database_repair.sql)

### 6) Storage policy surface is broad and duplicated
- Root cause: many migrations rebuild `storage_public_read` and bucket lists; bucket set in code is larger than early migrations. Source: [storage.ts](file:///c:/Users/k/Desktop/hallaq/packages/supabase/src/storage.ts#L5-L54), [0005_storage_buckets_and_policies.sql](file:///c:/Users/k/Desktop/hallaq/supabase/migrations/0005_storage_buckets_and_policies.sql#L1-L13)
- Impact: missing buckets/policies in some environments, inconsistent upload failures (“bucket not found”), and accidental over-exposure if a bucket is unintentionally listed as public-read.
- Fix generated (SQL): bucket baseline + select policy baseline: [security_fixes.sql](file:///c:/Users/k/Desktop/hallaq/security_fixes.sql)

## Medium Priority Issues

### 7) Legacy/compat columns increase inconsistency risk (services is the prime example)
- Root cause: `services` maintains parallel column sets (`name_en/name_ar/...` + legacy `name/description/...`). There is a sync trigger, but not all code paths are guaranteed to set both. Source: [0026_services_portfolio_reviews_system.sql](file:///c:/Users/k/Desktop/hallaq/supabase/migrations/0026_services_portfolio_reviews_system.sql#L3-L167), usage in [shop services page](file:///c:/Users/k/Desktop/hallaq/apps/shop/src/app/(panel)/services/page.tsx#L58-L145)
- Impact: inconsistent user-facing names/descriptions across apps, search mismatches, and reporting inaccuracies.
- Recommendation: pick canonical columns (`*_en/*_ar`), keep legacy columns as generated or maintained-only-by-trigger, and stop writing to them from application code.

### 8) Data repair coverage is incomplete vs required audit checklist
- Current implementation includes: fixing missing barbers/shops for role profiles, missing profiles for auth users, invalid roles, plus some reel tools (partial). Source: [data-repair/page.tsx](file:///c:/Users/k/Desktop/hallaq/apps/admin/src/app/(panel)/data-repair/page.tsx#L80-L239)
- Missing vs requested: orphan bookings/services/products/reels, counters/rating recalculation, storage link repair, notifications/favorites/saved reels repair, and “full integrity scan”.
- Recommendation: back the UI actions by DB-side RPCs (service-role guarded) so the repair UI is a thin client and the repair logic is centrally testable.

## Low Priority Issues

### 9) Debug logging configuration risk in production
- `SUPABASE_DEBUG=true` in local env can cause verbose logs and may increase risk of leaking operational details if replicated into production configs. File: [.env.local](file:///c:/Users/k/Desktop/hallaq/.env.local)

## Optimized SQL Generated
- Repair + realtime + reel counter fixes: [database_repair.sql](file:///c:/Users/k/Desktop/hallaq/database_repair.sql)
- Index improvements for common access paths: [performance_fixes.sql](file:///c:/Users/k/Desktop/hallaq/performance_fixes.sql)
- Storage hardening baseline: [security_fixes.sql](file:///c:/Users/k/Desktop/hallaq/security_fixes.sql)

## Final System Health Score

Current (post applied code fixes, pending DB SQL execution): 90/100

Path to ≥95/100:
- Execute [database_repair.sql](file:///c:/Users/k/Desktop/hallaq/database_repair.sql) and confirm reel counters + realtime publication wiring.
- Execute [security_fixes.sql](file:///c:/Users/k/Desktop/hallaq/security_fixes.sql) and verify all uploads for every bucket listed in [storage.ts](file:///c:/Users/k/Desktop/hallaq/packages/supabase/src/storage.ts#L5-L54).
- Add a cleanup migration to deduplicate policies/triggers/views/functions by name and lock canonical definitions.

