alter table public.profiles
add column if not exists my_barber_id uuid references public.barbers (id) on delete set null;

create index if not exists profiles_my_barber_id_idx on public.profiles (my_barber_id);
