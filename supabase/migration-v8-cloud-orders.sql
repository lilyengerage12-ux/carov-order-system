alter table public.orders add column if not exists project_type text;
create index if not exists orders_stage_idx on public.orders(stage);
create index if not exists order_steps_status_idx on public.order_steps(status);
