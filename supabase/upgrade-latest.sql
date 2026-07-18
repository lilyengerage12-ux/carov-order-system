-- Carov Flow latest cloud upgrade

-- supabase/migration-v4-customer-deposit.sql
-- Customer conversion: intention -> measurement -> proposal -> quotation -> deposit customer
alter table public.customers add column if not exists deposit_amount numeric(14,2);
alter table public.customers add column if not exists deposit_at timestamptz;
alter table public.customers add column if not exists deposit_confirmed_by uuid references public.profiles(id);
comment on column public.customers.stage is '意向客户/已量房/方案沟通/报价确认/定金客户';


-- supabase/migration-v5-procurement.sql
create table if not exists public.procurement_items (
 id uuid primary key default gen_random_uuid(),
 order_id uuid not null references public.orders(id) on delete cascade,
 item_name text not null, brand_spec text, quantity numeric, unit text,
 supplier text, owner_id uuid references public.profiles(id),
 required_at date, received_at timestamptz, status text not null default '待采购',
 installation_node text, amount numeric(14,2), notes text,
 created_by uuid references public.profiles(id), created_at timestamptz not null default now()
);
alter table public.procurement_items enable row level security;
drop policy if exists "authenticated read procurement" on public.procurement_items;
create policy "authenticated read procurement" on public.procurement_items for select using (auth.uid() is not null);
drop policy if exists "authorized manage procurement" on public.procurement_items;
create policy "authorized manage procurement" on public.procurement_items for all
using ((select role from public.my_profile()) in ('owner','admin','manager') or owner_id=auth.uid())
with check (auth.uid() is not null);


-- supabase/migration-v6-finance.sql
create table if not exists public.quotations (id uuid primary key default gen_random_uuid(),order_id uuid references public.orders(id),version int default 1,items jsonb not null default '[]',total_amount numeric(14,2),status text default '草稿',created_by uuid references public.profiles(id),created_at timestamptz default now());
create table if not exists public.contracts (id uuid primary key default gen_random_uuid(),order_id uuid references public.orders(id),contract_no text unique,total_amount numeric(14,2),deposit_amount numeric(14,2),order_payment_amount numeric(14,2),final_payment_amount numeric(14,2),signed_at date,created_at timestamptz default now());
create table if not exists public.order_costs (id uuid primary key default gen_random_uuid(),order_id uuid references public.orders(id),cost_type text not null,amount numeric(14,2) not null,supplier text,status text default '待确认',created_by uuid references public.profiles(id),created_at timestamptz default now());
create table if not exists public.store_expenses (id uuid primary key default gen_random_uuid(),category text not null,amount numeric(14,2) not null,payee text,expense_date date not null,description text,status text default '待审核',created_by uuid references public.profiles(id),approved_by uuid references public.profiles(id),created_at timestamptz default now());
alter table public.quotations enable row level security;alter table public.contracts enable row level security;alter table public.order_costs enable row level security;alter table public.store_expenses enable row level security;
drop policy if exists "finance quotations" on public.quotations;create policy "finance quotations" on public.quotations for all using (auth.uid() is not null) with check (auth.uid() is not null);
drop policy if exists "finance contracts" on public.contracts;create policy "finance contracts" on public.contracts for all using ((select role from public.my_profile()) in ('owner','finance','admin','manager')) with check (auth.uid() is not null);
drop policy if exists "finance costs" on public.order_costs;create policy "finance costs" on public.order_costs for all using ((select role from public.my_profile()) in ('owner','finance')) with check ((select role from public.my_profile()) in ('owner','finance'));
drop policy if exists "finance expenses" on public.store_expenses;create policy "finance expenses" on public.store_expenses for all using ((select role from public.my_profile()) in ('owner','finance')) with check ((select role from public.my_profile()) in ('owner','finance'));
