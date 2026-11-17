-- ACERCA: sincronización centralizada e idempotente de previsiones de nómina.
-- Ejecutar después de acerca-partner-worker-links.sql.

create or replace function public.sync_acerca_payment_obligations()
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  -- Los incentivos se pagan al empleado referente; la elegibilidad depende
  -- de que la persona referida siga activa hasta el cierre de su mes completo.
  update public.additional_payment_obligations o
  set worker_id = p.employee_worker_id,
      payroll_month = (date_trunc('month', r.hire_date)::date
        + case when extract(day from r.hire_date)>1 then interval '1 month' else interval '0 month' end)::date
  from public.partner_records p
  join public.workers r on r.id=p.referred_worker_id
  where o.partner_record_id=p.id
    and o.obligation_type='Incentivo Partner'
    and o.status not in ('Abonado','No corresponde')
    and p.employee_worker_id is not null
    and r.hire_date is not null
    and (o.worker_id is distinct from p.employee_worker_id
      or o.payroll_month is distinct from (date_trunc('month',r.hire_date)::date
        + case when extract(day from r.hire_date)>1 then interval '1 month' else interval '0 month' end)::date);

  -- Conserva la previsión como no correspondiente si ya no cumple la regla.
  update public.additional_payment_obligations o
  set status='No corresponde'
  where o.status not in ('Abonado','No corresponde')
    and (
      (o.obligation_type='Formación' and not exists (
        select 1 from public.workers w
        where w.id=o.worker_id and w.hire_date is not null
          and o.payroll_month=(date_trunc('month',w.hire_date)::date
            + case when extract(day from w.hire_date)>1 then interval '1 month' else interval '0 month' end)::date
          and (w.termination_date is null or w.termination_date >= (o.payroll_month + interval '1 month - 1 day')::date)
      ))
      or
      (o.obligation_type='Incentivo Partner' and not exists (
        select 1 from public.partner_records p
        join public.workers r on r.id=p.referred_worker_id
        where p.id=o.partner_record_id and p.employee_worker_id is not null
          and p.status not in ('Cancelado','Abonado') and r.hire_date is not null
          and o.payroll_month=(date_trunc('month',r.hire_date)::date
            + case when extract(day from r.hire_date)>1 then interval '1 month' else interval '0 month' end)::date
          and (r.termination_date is null or r.termination_date >= (o.payroll_month + interval '1 month - 1 day')::date)
      ))
    );

  insert into public.additional_payment_obligations
    (worker_id, obligation_type, payroll_month, amount, notes)
  select w.id, 'Formación', m.payroll_month, null,
         'Pago de formación correspondiente a la primera nómina mensual completa.'
  from public.workers w
  cross join lateral (
    select (date_trunc('month',w.hire_date)::date
      + case when extract(day from w.hire_date)>1 then interval '1 month' else interval '0 month' end)::date as payroll_month
  ) m
  where w.hire_date is not null
    and (w.termination_date is null or w.termination_date >= (m.payroll_month + interval '1 month - 1 day')::date)
    and not exists (
      select 1 from public.additional_payment_obligations o
      where o.worker_id=w.id and o.obligation_type='Formación'
    )
  on conflict do nothing;

  insert into public.additional_payment_obligations
    (worker_id, partner_record_id, obligation_type, payroll_month, amount, notes)
  select p.employee_worker_id, p.id, 'Incentivo Partner', m.payroll_month, 100,
         'Incentivo de 100 € para el empleado referente cuando la persona referida completa su primer mes de nómina.'
  from public.partner_records p
  join public.workers r on r.id=p.referred_worker_id
  cross join lateral (
    select (date_trunc('month',r.hire_date)::date
      + case when extract(day from r.hire_date)>1 then interval '1 month' else interval '0 month' end)::date as payroll_month
  ) m
  where p.employee_worker_id is not null and p.status not in ('Cancelado','Abonado')
    and r.hire_date is not null
    and (r.termination_date is null or r.termination_date >= (m.payroll_month + interval '1 month - 1 day')::date)
    and not exists (
      select 1 from public.additional_payment_obligations o
      where o.partner_record_id=p.id and o.obligation_type='Incentivo Partner'
    )
  on conflict do nothing;
end;
$$;

grant execute on function public.sync_acerca_payment_obligations() to authenticated;
