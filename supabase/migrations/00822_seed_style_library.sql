begin;

insert into public.style_library (slug, name_en, name_ar, description_en, description_ar, category, ai_style_key, is_active)
values
  ('skin-fade', 'Skin Fade', 'سكن فيد', 'A clean skin fade with sharp finishing and premium detailing.', 'سكن فيد نظيف مع تحديد حاد وتشطيب فاخر.', 'Fade', 'skin_fade', true),
  ('mid-fade', 'Mid Fade', 'ميد فيد', 'A balanced mid fade that works for everyday Bahrain grooming.', 'ميد فيد متوازن يناسب إطلالتك اليومية في البحرين.', 'Fade', 'mid_fade', true),
  ('burst-fade', 'Burst Fade', 'بيرست فيد', 'A burst fade that curves around the ear for a bold silhouette.', 'بيرست فيد يلتف حول الأذن لإطلالة جريئة.', 'Fade', 'burst_fade', true),
  ('french-crop', 'French Crop', 'فرنش كروب', 'A textured crop with a modern fringe and clean edges.', 'قصة كروب بتكستشر مع غرة عصرية وحدود نظيفة.', 'Crop', 'french_crop', true),
  ('buzz-cut', 'Buzz Cut', 'بز كت', 'A sharp, low-maintenance buzz cut with a premium finish.', 'بز كت حاد وسهل العناية بتشطيب فاخر.', 'Classic', 'buzz_cut', true),
  ('mullet', 'Mullet', 'موليت', 'A modern mullet with controlled volume and clean fade lines.', 'موليت عصري بحجم متوازن وخطوط فيد نظيفة.', 'Trending', 'mullet', true),
  ('slick-back', 'Slick Back', 'سليك باك', 'A slick back style with a clean taper and polished finish.', 'سليك باك مع تيبر نظيف وتشطيب أنيق.', 'Classic', 'slick_back', true),
  ('taper-fade', 'Taper Fade', 'تيبر فيد', 'A taper fade with subtle blending and natural shape.', 'تيبر فيد بدمج ناعم وشكل طبيعي.', 'Fade', 'taper_fade', true)
on conflict (slug) do update
set
  name_en = excluded.name_en,
  name_ar = excluded.name_ar,
  description_en = excluded.description_en,
  description_ar = excluded.description_ar,
  category = excluded.category,
  ai_style_key = excluded.ai_style_key,
  is_active = excluded.is_active;

commit;

