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
