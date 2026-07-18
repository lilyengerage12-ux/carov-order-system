alter table public.profiles add column if not exists email text;
create unique index if not exists profiles_email_key on public.profiles(email) where email is not null;
update public.profiles p set email=u.email from auth.users u where p.id=u.id and p.email is null;
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin
 insert into public.profiles(id,email,name,department,role,active)
 values(new.id,new.email,coalesce(new.raw_user_meta_data->>'name',split_part(new.email,'@',1)),coalesce(new.raw_user_meta_data->>'department','待分配'),'employee',true)
 on conflict(id) do update set email=excluded.email;
 return new;
end; $$;
