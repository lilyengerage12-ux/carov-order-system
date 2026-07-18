-- Carov Flow cloud database schema (Supabase/Postgres)
create extension if not exists pgcrypto;
create type public.app_role as enum ('owner','admin','finance','manager','employee');
create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 name text not null, phone text, department text not null,
 role public.app_role not null default 'employee',
 permissions text[] not null default '{}', active boolean not null default true,
 created_at timestamptz not null default now()
);
create table public.customers (
 id uuid primary key default gen_random_uuid(), customer_no text unique,
 name text not null, phone text, address text, budget numeric(14,2),
 source text, stage text not null default '意向客户',
 owner_id uuid references public.profiles(id), created_by uuid references public.profiles(id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.orders (
 id uuid primary key default gen_random_uuid(), order_no text unique not null,
 customer_id uuid references public.customers(id), contract_amount numeric(14,2),
 stage text not null default '意向客户', erp_system text check (erp_system in ('酷家乐','云熙') or erp_system is null),
 designer_id uuid references public.profiles(id), sales_id uuid references public.profiles(id),
 delivery_date date, created_by uuid references public.profiles(id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.order_steps (
 id uuid primary key default gen_random_uuid(), order_id uuid references public.orders(id) on delete cascade,
 step_no int not null, name text not null, department text not null, status text not null default '待开始',
 planned_at timestamptz, completed_at timestamptz, assignee_id uuid references public.profiles(id),
 notes text, unique(order_id,step_no)
);
create table public.payments (
 id uuid primary key default gen_random_uuid(), order_id uuid references public.orders(id),
 direction text not null check(direction in ('收款','付款')), payment_type text not null,
 amount numeric(14,2) not null, status text not null default '待审核',
 created_by uuid references public.profiles(id), approved_by uuid references public.profiles(id),
 paid_at timestamptz, created_at timestamptz not null default now()
);
create table public.after_sales (
 id uuid primary key default gen_random_uuid(), ticket_no text unique,
 order_id uuid references public.orders(id), issue_type text, description text,
 responsible_department text, priority text default '普通', status text default '待受理',
 assignee_id uuid references public.profiles(id), appointment_at timestamptz,
 cost_owner text, created_by uuid references public.profiles(id), created_at timestamptz default now()
);
alter table public.profiles enable row level security;
alter table public.customers enable row level security;
alter table public.orders enable row level security;
alter table public.order_steps enable row level security;
alter table public.payments enable row level security;
alter table public.after_sales enable row level security;
create or replace function public.my_profile() returns public.profiles language sql stable security definer set search_path=public as $$ select * from public.profiles where id=auth.uid() and active=true $$;
create policy "read own profile or admin" on public.profiles for select using (id=auth.uid() or (select role from public.my_profile()) in ('owner','admin'));
create policy "admin manages profiles" on public.profiles for all using ((select role from public.my_profile()) in ('owner','admin')) with check ((select role from public.my_profile()) in ('owner','admin'));
create policy "authenticated read customers" on public.customers for select using (auth.uid() is not null and (owner_id=auth.uid() or (select role from public.my_profile()) in ('owner','admin','manager','finance')));
create policy "sales create customers" on public.customers for insert with check (auth.uid() is not null);
create policy "owner or manager update customers" on public.customers for update using (owner_id=auth.uid() or (select role from public.my_profile()) in ('owner','admin','manager'));
create policy "authenticated read orders" on public.orders for select using (auth.uid() is not null);
create policy "authorized manage orders" on public.orders for all using ((select role from public.my_profile()) in ('owner','admin','manager') or sales_id=auth.uid() or designer_id=auth.uid()) with check (auth.uid() is not null);
create policy "authenticated read steps" on public.order_steps for select using (auth.uid() is not null);
create policy "department updates steps" on public.order_steps for all using ((select role from public.my_profile()) in ('owner','admin','manager') or department=(select department from public.my_profile())) with check (auth.uid() is not null);
create policy "finance only payments" on public.payments for all using ((select role from public.my_profile()) in ('owner','finance')) with check ((select role from public.my_profile()) in ('owner','finance'));
create policy "authenticated read aftersales" on public.after_sales for select using (auth.uid() is not null);
create policy "authorized manage aftersales" on public.after_sales for all using ((select role from public.my_profile()) in ('owner','admin','manager') or responsible_department=(select department from public.my_profile())) with check (auth.uid() is not null);

-- Automatically create the employee profile when a user signs up.
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin
 insert into public.profiles(id,name,department,role,active)
 values(new.id,coalesce(new.raw_user_meta_data->>'name',split_part(new.email,'@',1)),coalesce(new.raw_user_meta_data->>'department','待分配'),'employee',true)
 on conflict(id) do nothing;
 return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();
