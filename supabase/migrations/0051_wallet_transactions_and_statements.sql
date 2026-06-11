begin;

create or replace view public.transactions as
select
  p.id,
  'payment'::text as kind,
  p.booking_id,
  p.payer_profile_id,
  p.payee_type,
  p.payee_id,
  p.amount,
  p.currency,
  p.status,
  p.provider,
  p.provider_reference,
  p.authorized_at,
  p.captured_at,
  p.created_at
from public.payments p
union all
select
  r.id,
  'refund'::text as kind,
  p.booking_id,
  p.payer_profile_id,
  p.payee_type,
  p.payee_id,
  -r.amount as amount,
  r.currency,
  r.status,
  r.provider,
  r.provider_reference,
  null::timestamptz as authorized_at,
  null::timestamptz as captured_at,
  r.created_at
from public.refunds r
join public.payments p on p.id = r.payment_id;

create or replace function public.get_my_wallet_statement(p_month date default current_date)
returns table(
  kind text,
  id uuid,
  booking_id uuid,
  amount numeric,
  currency text,
  status text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  with me as (
    select b.id as barber_id
    from public.barbers b
    where b.profile_id = auth.uid()
  ),
  bounds as (
    select date_trunc('month', p_month)::timestamptz as start_at,
           (date_trunc('month', p_month) + interval '1 month')::timestamptz as end_at
  )
  select
    t.kind,
    t.id,
    t.booking_id,
    t.amount,
    t.currency,
    t.status,
    t.created_at
  from public.transactions t
  join me on me.barber_id = t.payee_id
  join bounds b on t.created_at >= b.start_at and t.created_at < b.end_at
  where t.payee_type = 'barber'
  order by t.created_at desc;
$$;

do $$
begin
  if to_regprocedure('public.get_my_wallet_statement(date)') is not null
     and exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function public.get_my_wallet_statement(date) to authenticated;
  end if;
end;
$$;

commit;
