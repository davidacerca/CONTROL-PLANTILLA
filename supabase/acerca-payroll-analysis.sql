-- ACERCA: pagos previstos por primera nómina completa e informes.
-- Ejecutar una vez en Supabase después de acerca-modules.sql.

alter table public.partner_records
  add column if not exists referred_worker_id uuid;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid='public.partner_records'::regclass
      and conname='partner_records_referred_worker_id_fkey'
  ) then
    alter table public.partner_records
      add constraint partner_records_referred_worker_id_fkey
      foreign key (referred_worker_id) references public.workers(id)
      on delete set null;
  end if;
end $$;

-- Enlaza registros antiguos solo cuando el nombre identifica a una única ficha.
update public.partner_records p
set referred_worker_id = w.id
from public.workers w
where p.referred_worker_id is null
  and lower(btrim(p.referred_name)) = lower(btrim(w.agent))
  and (
    select count(*) from public.workers w2
    where lower(btrim(w2.agent)) = lower(btrim(p.referred_name))
  ) = 1;

create table if not exists public.additional_payment_obligations (
  id uuid primary key default gen_random_uuid(),
  worker_id uuid not null references public.workers(id) on delete restrict,
  partner_record_id uuid references public.partner_records(id) on delete set null,
  obligation_type text not null check (obligation_type in ('Formación','Incentivo Partner')),
  payroll_month date not null check (extract(day from payroll_month)=1),
  amount numeric(12,2) check (amount is null or amount >= 0),
  status text not null default 'Previsto'
    check (status in ('Previsto','Pendiente','Abonado','No corresponde')),
  paid_at date,
  notes text,
  created_at timestamptz not null default now()
);

create unique index if not exists additional_obligations_training_worker_uidx
  on public.additional_payment_obligations(worker_id)
  where obligation_type='Formación';
create unique index if not exists additional_obligations_partner_record_uidx
  on public.additional_payment_obligations(partner_record_id)
  where obligation_type='Incentivo Partner' and partner_record_id is not null;
create unique index if not exists additional_obligations_partner_worker_uidx
  on public.additional_payment_obligations(worker_id)
  where obligation_type='Incentivo Partner';
create index if not exists additional_obligations_month_idx
  on public.additional_payment_obligations(payroll_month, status);

alter table public.additional_payment_obligations enable row level security;
drop policy if exists "Admins manage additional payment obligations"
  on public.additional_payment_obligations;
create policy "Admins manage additional payment obligations"
  on public.additional_payment_obligations
  for all to authenticated
  using (public.is_acerca_admin())
  with check (public.is_acerca_admin());
grant select, insert, update, delete
  on public.additional_payment_obligations to authenticated;

notify pgrst, 'reload schema';
