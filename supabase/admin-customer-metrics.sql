-- SadakatQR: only approved administrators may list registered customer profiles.
-- Run in the SadakatQR Supabase project (mplmmoehzsmohjikpqvj), SQL Editor.
create or replace function public.loyalty_admin_customers()
returns table(user_id uuid, full_name text, created_at timestamptz)
language plpgsql security definer set search_path = ''
as $$
begin
  if (select auth.uid()) is null or not exists (
    select 1 from public.loyalty_admins a where a.user_id = (select auth.uid())
  ) then
    raise exception 'Unauthorized' using errcode = '42501';
  end if;
  return query
  select p.user_id, p.full_name, p.created_at
  from public.customer_profiles p
  order by p.created_at desc;
end;
$$;
revoke all on function public.loyalty_admin_customers() from public, anon;
grant execute on function public.loyalty_admin_customers() to authenticated;
