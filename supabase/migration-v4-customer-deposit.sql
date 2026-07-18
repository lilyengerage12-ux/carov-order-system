-- Customer conversion: intention -> measurement -> proposal -> quotation -> deposit customer
alter table public.customers add column if not exists deposit_amount numeric(14,2);
alter table public.customers add column if not exists deposit_at timestamptz;
alter table public.customers add column if not exists deposit_confirmed_by uuid references public.profiles(id);
comment on column public.customers.stage is '意向客户/已量房/方案沟通/报价确认/定金客户';
