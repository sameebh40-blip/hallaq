do $$
begin
  if to_regclass('storage.buckets') is not null then
    insert into storage.buckets (id, name, public)
    values ('backups', 'backups', false)
    on conflict (id) do nothing;
  end if;
end $$;

alter table public.backup_logs add column if not exists object_path text;

