-- Run ONLY in SadakatQR Supabase project mplmmoehzsmohjikpqvj.
-- Read-only business campaign details for verified admin accounts.
create or replace function public.loyalty_admin_campaigns(p_business_id uuid)
returns table(id uuid, name text, stamps_required smallint, active boolean, created_at timestamptz)
language plpgsql security definer set search_path=''
as $$
begin
  if (select auth.uid()) is null or not exists
    (select 1 from public.loyalty_admins a where a.user_id=(select auth.uid())) then
    raise exception 'Not authorized' using errcode='42501';
  end if;
  return query select c.id,c.name,c.stamps_required,c.active,c.created_at
  from public.loyalty_campaigns c
  where c.business_id=p_business_id
  order by c.created_at desc limit 200;
end $$;
revoke all on function public.loyalty_admin_campaigns(uuid) from public,anon;
grant execute on function public.loyalty_admin_campaigns(uuid) to authenticated;
