-- ACERCA: relaciona Partners con las fichas de las dos personas.
-- Ejecutar después de acerca-payroll-analysis.sql.

alter table public.partner_records
  add column if not exists employee_worker_id uuid;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid='public.partner_records'::regclass
      and conname='partner_records_employee_worker_id_fkey'
  ) then
    alter table public.partner_records
      add constraint partner_records_employee_worker_id_fkey
      foreign key (employee_worker_id) references public.workers(id)
      on delete set null;
  end if;
end $$;

-- Backfill only names that identify exactly one existing worker.
update public.partner_records p
set employee_worker_id=w.id
from public.workers w
where p.employee_worker_id is null
  and lower(btrim(p.referrer_name))=lower(btrim(w.agent))
  and (
    select count(*) from public.workers w2
    where lower(btrim(w2.agent))=lower(btrim(p.referrer_name))
  )=1;

create index if not exists partner_records_employee_worker_idx
  on public.partner_records(employee_worker_id);

-- Incentives belong to the referring employee. Older obligations used the
-- referred worker ID; reassign those obligations when the referrer is known.
drop index if exists public.additional_obligations_partner_worker_uidx;
update public.additional_payment_obligations o
set worker_id=p.employee_worker_id
from public.partner_records p
where o.partner_record_id=p.id
  and o.obligation_type='Incentivo Partner'
  and p.employee_worker_id is not null
  and o.worker_id is distinct from p.employee_worker_id;

notify pgrst, 'reload schema';
