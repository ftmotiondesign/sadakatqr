-- SADAKATQR ONLY: Run in project mplmmoehzsmohjikpqvj SQL Editor.
-- Explicit allowlist; no user can grant their own admin role.
create table if not exists public.loyalty_admins (
 user_id uuid primary key references auth.users(id) on delete cascade,
 created_at timestamptz not null default now()
);
alter table public.loyalty_admins enable row level security;
revoke all on public.loyalty_admins from anon,authenticated;
grant select on public.loyalty_admins to authenticated;
drop policy if exists loyalty_admin_self on public.loyalty_admins;
create policy loyalty_admin_self on public.loyalty_admins for select to authenticated using (user_id=(select auth.uid()));

-- Admin API uses a privileged, tightly checked RPC. Grant explicitly.
create or replace function public.loyalty_admin_businesses()
returns table(id uuid,name text,status text,phone text,owner_user_id uuid,created_at timestamptz)
language plpgsql security definer set search_path=''
as $$
begin
 if (select auth.uid()) is null or not exists(select 1 from public.loyalty_admins a where a.user_id=(select auth.uid())) then
  raise exception 'Not authorized' using errcode='42501';
 end if;
 return query select b.id,b.name,b.status,b.phone,b.owner_user_id,b.created_at from public.loyalty_businesses b order by b.created_at desc limit 300;
end $$;
revoke all on function public.loyalty_admin_businesses() from public,anon;
grant execute on function public.loyalty_admin_businesses() to authenticated;
create or replace function public.loyalty_admin_set_status(p_business_id uuid,p_status text)
returns void language plpgsql security definer set search_path=''
as $$
begin
 if (select auth.uid()) is null or not exists(select 1 from public.loyalty_admins a where a.user_id=(select auth.uid())) then
  raise exception 'Not authorized' using errcode='42501';
 end if;
 if p_status not in ('approved','rejected','suspended','pending') then raise exception 'Invalid status'; end if;
 update public.loyalty_businesses b set status=p_status,approved_at=case when p_status='approved' then now() else null end where b.id=p_business_id;
 if not found then raise exception 'Business not found'; end if;
end $$;
revoke all on function public.loyalty_admin_set_status(uuid,text) from public,anon;
grant execute on function public.loyalty_admin_set_status(uuid,text) to authenticated;
-- One-time admin setup: ONLY from SQL editor after confirming correct admin account email:
-- insert into public.loyalty_admins(user_id)
-- select id from auth.users where email='YOUR-ADMIN-EMAIL-HERE';
-- Never enable admin signup through frontend.
