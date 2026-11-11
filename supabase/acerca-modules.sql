-- ACERCA: esquema funcional de gestión laboral y económica
-- Ejecutar una sola vez en Supabase > SQL Editor > New query.
-- Conserva la tabla workers y sus registros existentes.

alter table public.workers alter column email drop not null;
alter table public.workers alter column email set default '-';
alter table public.workers add column if not exists termination_reason text;
update public.workers set email='-' where email is null or btrim(email)='';

create table if not exists public.vacation_records (
  id uuid primary key default gen_random_uuid(),
  worker_id uuid not null references public.workers(id) on delete cascade,
  start_date date not null,
  end_date date not null,
  kind text not null default 'week' check (kind in ('week','single')),
  days_count numeric(6,2) not null default 1 check (days_count > 0),
  notes text,
  created_at timestamptz not null default now(),
  check (end_date >= start_date)
);
create table if not exists public.leave_records (
  id uuid primary key default gen_random_uuid(),
  worker_id uuid not null references public.workers(id) on delete cascade,
  leave_type text not null,
  category text not null default 'Justificado',
  start_date date not null,
  end_date date not null,
  days_count numeric(6,2) not null default 1,
  hours_count numeric(6,2),
  is_paid boolean not null default false,
  is_justified boolean not null default true,
  counts_for_bonus boolean not null default false,
  status text not null default 'Registrado',
  notes text,
  created_at timestamptz not null default now(),
  check (end_date >= start_date)
);
create table if not exists public.incident_records (
  id uuid primary key default gen_random_uuid(),
  worker_id uuid not null references public.workers(id) on delete cascade,
  incident_type text not null check (incident_type in ('Impuntualidad','Abandono de puesto')),
  incident_date date not null,
  incident_time time,
  planned_time time,
  end_time time,
  duration_minutes integer not null default 0 check (duration_minutes >= 0),
  is_justified boolean not null default false,
  counts_for_bonus boolean not null default false,
  notes text,
  created_at timestamptz not null default now()
);
create table if not exists public.partner_records (
  id uuid primary key default gen_random_uuid(),
  referrer_name text not null,
  referred_name text not null,
  incorporation_date date not null,
  incentive numeric(12,2) not null default 0,
  status text not null default 'Pendiente',
  notes text,
  created_at timestamptz not null default now()
);
create table if not exists public.extra_hours (
  id uuid primary key default gen_random_uuid(),
  worker_id uuid not null references public.workers(id) on delete cascade,
  work_date date not null,
  concept text not null,
  hours numeric(8,2) not null check (hours > 0),
  amount numeric(12,2) not null default 0,
  status text not null default 'Pendiente',
  notes text,
  created_at timestamptz not null default now()
);
create table if not exists public.additional_payments (
  id uuid primary key default gen_random_uuid(),
  worker_id uuid not null references public.workers(id) on delete cascade,
  concept text not null,
  reference text,
  amount numeric(12,2) not null check (amount >= 0),
  payment_date date not null,
  status text not null default 'Pendiente',
  notes text,
  created_at timestamptz not null default now()
);
create table if not exists public.pending_payments (
  id uuid primary key default gen_random_uuid(),
  worker_id uuid not null references public.workers(id) on delete cascade,
  concept text not null,
  amount numeric(12,2) not null check (amount >= 0),
  expected_date date not null,
  status text not null default 'Pendiente' check (status in ('Pendiente','Abonado','Cancelado')),
  paid_at date,
  additional_payment_id uuid references public.additional_payments(id) on delete set null,
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists vacation_records_worker_dates_idx on public.vacation_records(worker_id,start_date,end_date);
create index if not exists leave_records_worker_dates_idx on public.leave_records(worker_id,start_date,end_date);
create index if not exists incident_records_worker_date_idx on public.incident_records(worker_id,incident_date);
create index if not exists extra_hours_worker_date_idx on public.extra_hours(worker_id,work_date);
create index if not exists additional_payments_worker_date_idx on public.additional_payments(worker_id,payment_date);
create index if not exists pending_payments_worker_date_idx on public.pending_payments(worker_id,expected_date);

alter table public.vacation_records enable row level security;
alter table public.leave_records enable row level security;
alter table public.incident_records enable row level security;
alter table public.partner_records enable row level security;
alter table public.extra_hours enable row level security;
alter table public.additional_payments enable row level security;
alter table public.pending_payments enable row level security;

do $$
declare t text;
begin
  foreach t in array array['vacation_records','leave_records','incident_records','partner_records','extra_hours','additional_payments','pending_payments']
  loop
    execute format('drop policy if exists %I on public.%I', 'Admins manage ' || t, t);
    execute format('create policy %I on public.%I for all to authenticated using (public.is_acerca_admin()) with check (public.is_acerca_admin())', 'Admins manage ' || t, t);
    execute format('grant select, insert, update, delete on public.%I to authenticated',t);
  end loop;
end $$;

grant select, insert, update, delete on public.workers to authenticated;


-- Compatibilidad con instalaciones anteriores: añade los campos de cálculo horario
-- sin borrar incidencias existentes.
alter table public.incident_records add column if not exists planned_time time;
alter table public.incident_records add column if not exists end_time time;

-- Permite a PostgREST descubrir las tablas y columnas recién creadas.
grant usage on schema public to authenticated;
grant execute on function public.is_acerca_admin() to authenticated;
notify pgrst, 'reload schema';
