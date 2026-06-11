begin;

create or replace view public.posts as
select
  r.id,
  r.created_by,
  r.owner_type,
  r.shop_id,
  r.barber_id,
  r.media_url,
  r.media_path,
  r.thumbnail_url,
  r.thumbnail_path,
  r.media_type,
  r.caption,
  r.hashtags,
  r.location,
  r.status,
  r.is_featured,
  r.is_sponsored,
  r.likes_count,
  r.comments_count,
  r.saves_count,
  r.shares_count,
  r.video_url,
  r.image_url,
  r.approved_by,
  r.approved_at,
  r.rejected_by,
  r.rejected_at,
  r.rejection_reason,
  r.deleted_at,
  r.created_at,
  r.updated_at
from public.reels r;

commit;
