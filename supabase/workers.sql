create table if not exists public.workers (
  id uuid primary key default gen_random_uuid(),
  agent text not null,
  company text not null,
  email text not null,
  hire_date date not null,
  termination_date date,
  created_at timestamptz not null default now()
);

create index if not exists workers_email_lower_idx
  on public.workers (lower(email));

alter table public.workers enable row level security;

drop policy if exists "Admins can manage workers" on public.workers;
create policy "Admins can manage workers"
  on public.workers
  for all
  to authenticated
  using (public.is_acerca_admin())
  with check (public.is_acerca_admin());

grant select, insert, update, delete on public.workers to authenticated;
