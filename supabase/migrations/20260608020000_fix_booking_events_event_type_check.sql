begin;

alter table if exists public.booking_events
  drop constraint if exists booking_events_event_type_check;

do $$
begin
  if to_regclass('public.booking_events') is null then
    return;
  end if;

  update public.booking_events
  set event_type = case
    when event_type = 'created' then 'booking_created'
    when event_type = 'rescheduled' then 'booking_rescheduled'
    when event_type = 'status_changed' then 'booking_status_changed'
    else event_type
  end;
end;
$$;

alter table if exists public.booking_events
  add constraint booking_events_event_type_check
  check (event_type in ('booking_created','booking_rescheduled','booking_status_changed','created','rescheduled','status_changed'));

commit;

