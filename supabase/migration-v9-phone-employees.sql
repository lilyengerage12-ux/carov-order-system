alter table public.profiles add column if not exists staff_no text;
alter table public.profiles add column if not exists must_change_password boolean not null default false;
create unique index if not exists profiles_phone_key on public.profiles(phone) where phone is not null;
create unique index if not exists profiles_staff_no_key on public.profiles(staff_no) where staff_no is not null;
create table if not exists public.audit_logs (
 id bigint generated always as identity primary key,
 actor_id uuid references public.profiles(id), action text not null,
 target_type text, target_id uuid, details jsonb not null default '{}',
 created_at timestamptz not null default now()
);
alter table public.audit_logs enable row level security;
drop policy if exists "admins read audit logs" on public.audit_logs;
create policy "admins read audit logs" on public.audit_logs for select using ((select role from public.my_profile()) in ('owner','admin'));
