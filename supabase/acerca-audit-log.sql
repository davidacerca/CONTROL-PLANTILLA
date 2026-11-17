-- ACERCA: historial de altas, cambios y eliminaciones con usuario responsable.
-- Ejecutar después de acerca-modules.sql y acerca-workflow-updates.sql.

create table if not exists public.acerca_audit_log (
  id bigint generated always as identity primary key,
  table_name text not null,
  record_id text not null,
  operation text not null check (operation in ('INSERT','UPDATE','DELETE')),
  actor_id uuid,
  actor_email text,
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz not null default now()
);

create index if not exists acerca_audit_log_created_idx
  on public.acerca_audit_log(created_at desc);
create index if not exists acerca_audit_log_record_idx
  on public.acerca_audit_log(table_name, record_id, created_at desc);

alter table public.acerca_audit_log enable row level security;
drop policy if exists "Admins read audit log" on public.acerca_audit_log;
create policy "Admins read audit log"
  on public.acerca_audit_log for select to authenticated
  using (public.is_acerca_admin());
grant select on public.acerca_audit_log to authenticated;
revoke insert, update, delete on public.acerca_audit_log from anon, authenticated;

create or replace function public.acerca_audit_row_change()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  old_row jsonb;
  new_row jsonb;
  row_data jsonb;
  key_value text;
begin
  if tg_op = 'INSERT' then
    new_row := to_jsonb(new);
    row_data := new_row;
  elsif tg_op = 'UPDATE' then
    old_row := to_jsonb(old);
    new_row := to_jsonb(new);
    row_data := new_row;
  else
    old_row := to_jsonb(old);
    row_data := old_row;
  end if;

  key_value := coalesce(
    row_data->>'id',
    nullif(concat_ws(':', row_data->>'worker_id', row_data->>'bonus_month', row_data->>'bonus_year'), '::'),
    row_data->>'worker_id',
    row_data->>'name',
    row_data->>'email'
  );

  insert into public.acerca_audit_log
    (table_name, record_id, operation, actor_id, actor_email, old_data, new_data)
  values
    (tg_table_name, coalesce(nullif(key_value,''),'unknown'), tg_op,
     auth.uid(), auth.jwt()->>'email', old_row, new_row);

  return null;
end;
$$;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'workers','societies','vacation_records','leave_records','incident_records',
    'partner_records','extra_hours','additional_payments','additional_payment_obligations',
    'pending_payments','bonus_recoveries'
  ] loop
    execute format('drop trigger if exists acerca_audit_row_change on public.%I', table_name);
    execute format(
      'create trigger acerca_audit_row_change after insert or update or delete on public.%I for each row execute function public.acerca_audit_row_change()',
      table_name
    );
  end loop;
end;
$$;

notify pgrst, 'reload schema';
