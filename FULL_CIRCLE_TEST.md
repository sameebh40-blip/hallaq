# Hallaq Full Circle Test (Supabase Source of Truth)

## 0) DB + Storage Prereqs
- Apply all migrations in `supabase/migrations` (including `0080_hallaq_master_compat_views_and_storage_admin.sql`).
- Run the DB readiness check: `supabase/db_readiness_check.sql`.
- Confirm compatibility views exist (for older client naming):
  - `public.shops`, `public.appointments`, `public.posts`, `public.post_likes`, `public.post_comments`, `public.post_saves`

## 1) Admin Flow (Create Shop Owner → Shop → Media)
- Login as admin.
- Create a shop owner (profiles.role = `shop_owner`).
- Create a shop (row in `public.barbershops`; view `public.shops` should also reflect it).
- Assign owner (`barbershops.owner_profile_id = owner profile id`).
- Upload shop logo + cover.
  - Expected:
    - Storage objects written to bucket `shop-images`
    - `barbershops.logo_path/cover_path` updated (URLs resolved in app)
  - If it fails:
    - Check `public.system_logs` for actions: `shop_logo_upload`, `shop_cover_upload`, `shop_profile_save`

## 2) Shop Owner Flow (Dashboard → Services/Products/Reels)
- Login as shop owner.
- Confirm shop dashboard loads only the owner shop (`barbershops.owner_profile_id = auth.uid()`).
- Add a service.
  - Expected:
    - Row in `public.services`
    - Service appears in customer booking flow immediately after refresh
- Add a product.
  - Expected:
    - Row in `public.products`
    - Images written to bucket `product-images` and stored as storage paths in DB
- Upload a reel.
  - Expected:
    - Row in `public.reels` (view `public.posts` reflects it)
    - Media in bucket `reels`

## 3) Barber Flow (Dashboard → Avatar/Cover/Portfolio/Reels)
- Admin creates barber and assigns to shop (or marks independent).
- Login as barber.
- Upload barber avatar + cover.
  - Expected:
    - Storage objects written to bucket `barber-images`
    - `public.barbers.avatar_path/cover_path` updated
  - If it fails:
    - Check `public.system_logs` actions: `upload_avatar`, `upload_cover` under pages `barber_media`
- Upload portfolio item.
  - Expected:
    - Storage object written to bucket `portfolio`
    - Row in `public.portfolio_items`
  - If it fails:
    - Check `public.system_logs` action: `upload_portfolio_image`
- Upload barber reel.
  - Expected:
    - Storage objects written to bucket `reels`
    - Row in `public.reels`
  - If it fails:
    - Check `public.system_logs` actions: `upload_reel_image`, `upload_reel_video`

## 4) Customer Flow (Flutter) (Discover → Profiles → Booking → Saved)
- Login as customer.
- Discover shows reels without crashes (empty state if none).
- Open shop profile:
  - Services/products render without broken images.
- Open barber profile:
  - Avatar/cover/portfolio/services render without broken images.
- Create booking:
  - Expected:
    - Row in `public.bookings` created
    - Customer bookings list shows it
    - Barber and Shop dashboards show it
    - Admin dashboard stats update
- Barber accepts/updates booking status:
  - Expected:
    - Customer sees status update without app restart
    - Shop owner sees status update in bookings-by-status list
    - Admin stats reflect updated totals
- Saved:
  - Save barber/shop/reel and confirm `public.saved_items` rows exist.

## 5) Where to Look When Anything Fails
- `public.system_logs` (admin can read everything):
  - Filter by `created_at desc`, `severity`, `action`
- Storage:
  - Confirm buckets exist: `avatars`, `profile-covers`, `shop-images`, `barber-images`, `service-images`, `product-images`, `portfolio`, `reels`, `offer-images`
- Compatibility:
  - If a client uses old table names, use the compat views:
    - `shops` → `barbershops`
    - `appointments` → `bookings`
    - `posts` → `reels`
