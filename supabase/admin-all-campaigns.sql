-- ONLY SadakatQR project mplmmoehzsmohjikpqvj.
-- Optional business geographic/sector fields. Existing records are preserved.
alter table public.loyalty_businesses add column if not exists city text;
alter table public.loyalty_businesses add column if not exists district text;
alter table public.loyalty_businesses add column if not exists sector text;
-- All campaigns: admin-only read RPC. No public access to private business data.
create or replace function public.loyalty_admin_all_campaigns()
returns table(campaign_id uuid, campaign_name text, stamps_required smallint, active boolean, campaign_created_at timestamptz,
business_id uuid, business_name text, business_status text, city text, district text, sector text)
language plpgsql security definer set search_path=''
as $$
begin
 if (select auth.uid()) is null or not exists
  (select 1 from public.loyalty_admins a where a.user_id=(select auth.uid())) then
  raise exception 'Not authorized' using errcode='42501';
 end if;
 return query select c.id,c.name,c.stamps_required,c.active,c.created_at,b.id,b.name,b.status,
 b.city,b.district,b.sector
 from public.loyalty_campaigns c join public.loyalty_businesses b on b.id=c.business_id
 order by c.created_at desc limit 2000;
end $$;
revoke all on function public.loyalty_admin_all_campaigns() from public,anon;
grant execute on function public.loyalty_admin_all_campaigns() to authenticated;
