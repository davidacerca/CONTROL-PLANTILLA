-- ACERCA: búsqueda de trabajadores, pagos aplazados, horas extra y recuperación de bonos.
-- Ejecutar una vez después de acerca-payroll-analysis.sql.

alter table public.extra_hours alter column amount drop not null;
alter table public.pending_payments alter column amount drop not null;
alter table public.extra_hours
  add column if not exists import_source boolean not null default false;
alter table public.extra_hours
  add column if not exists import_key text;

alter table public.pending_payments
  add column if not exists source_obligation_id uuid;
alter table public.pending_payments
  add column if not exists source_extra_hours_id uuid;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid='public.pending_payments'::regclass
      and conname='pending_payments_source_obligation_id_fkey'
  ) then
    alter table public.pending_payments
      add constraint pending_payments_source_obligation_id_fkey
      foreign key (source_obligation_id)
      references public.additional_payment_obligations(id) on delete set null;
  end if;
  if not exists (
    select 1 from pg_constraint
    where conrelid='public.pending_payments'::regclass
      and conname='pending_payments_source_extra_hours_id_fkey'
  ) then
    alter table public.pending_payments
      add constraint pending_payments_source_extra_hours_id_fkey
      foreign key (source_extra_hours_id)
      references public.extra_hours(id) on delete set null;
  end if;
end $$;

create unique index if not exists pending_payments_source_obligation_uidx
  on public.pending_payments(source_obligation_id)
  where source_obligation_id is not null;
create unique index if not exists pending_payments_source_extra_hours_uidx
  on public.pending_payments(source_extra_hours_id)
  where source_extra_hours_id is not null;
create unique index if not exists extra_hours_import_key_uidx
  on public.extra_hours(import_key)
  where import_key is not null;

create table if not exists public.bonus_recoveries (
  worker_id uuid not null references public.workers(id) on delete restrict,
  bonus_year integer not null check (bonus_year between 2000 and 2100),
  recovered_at date not null default current_date,
  notes text,
  created_at timestamptz not null default now(),
  primary key (worker_id, bonus_year)
);

alter table public.bonus_recoveries enable row level security;
drop policy if exists "Admins manage bonus recoveries" on public.bonus_recoveries;
create policy "Admins manage bonus recoveries"
  on public.bonus_recoveries
  for all to authenticated
  using (public.is_acerca_admin())
  with check (public.is_acerca_admin());
grant select, insert, update, delete on public.bonus_recoveries to authenticated;

notify pgrst, 'reload schema';
