# HALLAQ Supabase Audit Report (Repo State)

Scope: This report audits the SQL migrations under [supabase/migrations](file:///c:/Users/k/Desktop/hallaq/supabase/migrations) and all frontend Supabase usage under `apps/*` + shared helpers under `packages/supabase/*`.

## Working

### Auth ↔ Profile Link
- `profiles.id` is the primary key and references `auth.users(id)` with `on delete cascade`: [0001_init.sql](file:///c:/Users/k/Desktop/hallaq/supabase/migrations/0001_init.sql#L15-L31)

### Role Routing Source
- All apps route based on a fresh `profiles.role` fetch (middleware), not a local cache:
  - Customer: [middleware.ts](file:///c:/Users/k/Desktop/hallaq/apps/customer/middleware.ts#L1-L141)
  - Shop: [middleware.ts](file:///c:/Users/k/Desktop/hallaq/apps/shop/middleware.ts#L1-L106)
  - Admin: [middleware.ts](file:///c:/Users/k/Desktop/hallaq/apps/admin/middleware.ts#L1-L89)

### Admin Role Change “Creates Links”
- When admin changes role:
  - `barber` role ensures a `barbers` row exists for `profile_id = profiles.id`
  - `shop_owner` role ensures a `barbershops` row exists for `owner_profile_id = profiles.id`
  - Implementation: [users/[id]/page.tsx](file:///c:/Users/k/Desktop/hallaq/apps/admin/src/app/(panel)/users/%5Bid%5D/page.tsx#L120-L168)

### Core Domain Tables (as implemented in this repo)
- Identity: `profiles`
- Shops: `barbershops`, `shop_branches`, `shop_staff`
- Barbers: `barbers`
- Services: `services`
- Bookings: `bookings`
- Social/Reels: `reels` + `reel_likes`, `reel_saves`, `reel_comments`
- Saved: `saved_items` (+ legacy `favorites`)
- Reviews: `reviews` (includes `reply_text` inline)
- Notifications: `notifications`
- Logs: `system_logs`, `admin_audit_logs`

Evidence: table definitions originate in [0001_init.sql](file:///c:/Users/k/Desktop/hallaq/supabase/migrations/0001_init.sql) and later migrations (notably [0070_system_logs_and_admin_audit_logs.sql](file:///c:/Users/k/Desktop/hallaq/supabase/migrations/0070_system_logs_and_admin_audit_logs.sql), [0075_multi_branch_and_reception.sql](file:///c:/Users/k/Desktop/hallaq/supabase/migrations/0075_multi_branch_and_reception.sql)).

### RPC Functions Used by Frontend Exist (by name)
- The frontend calls many `rpc(...)` functions (booking lifecycle, availability, settings/maintenance, social counts). These functions are present in migrations by name (e.g., `create_booking`, `confirm_booking`, `cancel_booking`, `reschedule_booking`, `get_available_days`, `get_available_times`, `get_setting_bool`).

## Missing (relative to your “required naming” checklist)

This repo’s schema is internally consistent but uses different canonical names than your prompt:

- `shops` table name: **not present**. The canonical table is `barbershops`.
- `appointments` table name: **not present**. The canonical table is `bookings`.
- `posts` table name: **not a table**. The canonical table is `reels`. A compatibility `posts` **view** exists: [0058_reels_posts_alignment.sql](file:///c:/Users/k/Desktop/hallaq/supabase/migrations/0058_reels_posts_alignment.sql#L265-L285)
- `post_likes`, `post_saves`, `post_comments`: **not present**. Canonical tables are `reel_likes`, `reel_saves`, `reel_comments`.
- `review_replies`: **not present**. The schema uses `reviews.reply_text` instead of a separate replies table.
- `repair_logs`: **not present** (there are `system_logs` and several admin activity/audit tables).

## Broken / High-Risk Mismatches

### Storage Bucket Drift (`reels` vs `reels-media`)
- Migrations evolve from `reels-media` → `reels`, but the code still contains both.
- The admin “permanent delete” fallback removes objects from `reels-media` for plain-path values, which will miss objects uploaded to `reels`: [posts-reels/[id]/page.tsx](file:///c:/Users/k/Desktop/hallaq/apps/admin/src/app/(panel)/posts-reels/%5Bid%5D/page.tsx#L186-L200)

### Profiles Column Set vs Your Required List
- Current `profiles` columns include: `email`, `full_name`, `phone`, `avatar_url`, `cover_url`, `role`, `status`, `verified`, `area`, `lat`, `lng`, timestamps. Evidence: [0001_init.sql](file:///c:/Users/k/Desktop/hallaq/supabase/migrations/0001_init.sql#L15-L31)
- Additional profile fields exist: `bio`, `location`, `membership_tier` and storage paths (`avatar_path`, `cover_path`) via migrations. Evidence: [0062_customer_membership_and_profile_fields.sql](file:///c:/Users/k/Desktop/hallaq/supabase/migrations/0062_customer_membership_and_profile_fields.sql#L3-L8)
- Your required fields that are not present (by exact name): `selected_area`, `last_latitude`, `last_longitude`.

### Bucket List vs Your Required List
- Your prompt expects buckets like: `profile-covers`, `product-images`, `service-images`, `offer-images`, `awards`, etc.
- The repo has migrations to create many of these, but the shared helper type list should include all in active use (e.g., it does not include `profile-covers` currently): [storage.ts](file:///c:/Users/k/Desktop/hallaq/packages/supabase/src/storage.ts#L5-L50)

## Needs Fix (Actionable Next Steps)

1. Standardize storage bucket usage across apps (especially `reels` vs `reels-media`) and make delete/cleanup consistently target the actual bucket.
2. Finalize “profiles required fields” strategy:
   - Either add the missing columns (`selected_area`, `last_latitude`, `last_longitude`) or update frontend to rely on existing `area/lat/lng/location`.
3. Decide whether to implement naming-compatibility objects:
   - Option A: Keep canonical tables and add **views** (`shops`, `appointments`, `post_*`) for compatibility.
   - Option B: Rename tables (higher risk; requires updating migrations + all frontend queries).
4. Re-verify RLS and storage policies against the exact write paths used by:
   - customer: profile updates, saves/likes/comments, booking creation
   - barber: portfolio and reels writes
   - shop_owner: shop images, services/products, reels, booking management
   - admin: global read/write + storage overrides

