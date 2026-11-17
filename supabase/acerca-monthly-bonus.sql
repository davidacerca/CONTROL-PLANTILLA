-- ACERCA: derecho y recuperaciones del bono por mes natural.
-- Ejecutar después de acerca-workflow-updates.sql.

alter table public.bonus_recoveries
  add column if not exists bonus_month date;

-- Las recuperaciones anuales antiguas no indican mes; se conservan en enero
-- del año registrado y no se extienden automáticamente a los otros meses.
update public.bonus_recoveries
set bonus_month = make_date(bonus_year, 1, 1)
where bonus_month is null;

alter table public.bonus_recoveries
  alter column bonus_month set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid='public.bonus_recoveries'::regclass
      and conname='bonus_recoveries_month_first_day_check'
  ) then
    alter table public.bonus_recoveries
      add constraint bonus_recoveries_month_first_day_check
      check (extract(day from bonus_month)=1);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid='public.bonus_recoveries'::regclass
      and conname='bonus_recoveries_month_year_match_check'
  ) then
    alter table public.bonus_recoveries
      add constraint bonus_recoveries_month_year_match_check
      check (bonus_year=extract(year from bonus_month));
  end if;
end $$;

alter table public.bonus_recoveries
  drop constraint if exists bonus_recoveries_pkey;

create unique index if not exists bonus_recoveries_worker_month_uidx
  on public.bonus_recoveries(worker_id, bonus_month);

notify pgrst, 'reload schema';
