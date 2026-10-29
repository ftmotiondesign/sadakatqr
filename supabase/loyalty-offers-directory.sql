-- SadakatQR separate Supabase project only. Requires loyalty_ad_requests and business location columns.
-- Public directory exposes approved campaign and business region only, no customer information.
create or replace function public.loyalty_public_sponsored_offers_directory()
returns table(campaign_id uuid,business_name text,campaign_name text,stamps_required integer,placement text,city text,district text,sector text)
language sql stable security definer set search_path=''
as $$
 with eligible as (
 select c.id as cid,b.name::text as bname,c.name::text as cname,c.stamps_required::integer as required,
 a.placement,b.city::text as bcity,b.district::text as bdistrict,b.sector::text as bsector,
 row_number() over(partition by c.id order by case a.placement when 'home' then 0 else 1 end,a.approved_at desc) as rn
 from public.loyalty_ad_requests a
 join public.loyalty_campaigns c on c.id=a.campaign_id and c.business_id=a.business_id
 join public.loyalty_businesses b on b.id=a.business_id
 where a.placement in ('home','offers') and a.status='approved'
 and a.approved_at<=now() and a.ends_at>now() and c.active=true and b.status='approved'
 )
 select e.cid,e.bname,e.cname,e.required,e.placement,e.bcity,e.bdistrict,e.bsector
 from eligible e where e.rn=1
 order by case e.placement when 'home' then 0 else 1 end,e.bname,e.cname limit 100;
$$;
revoke all on function public.loyalty_public_sponsored_offers_directory() from public;
grant execute on function public.loyalty_public_sponsored_offers_directory() to anon,authenticated;
