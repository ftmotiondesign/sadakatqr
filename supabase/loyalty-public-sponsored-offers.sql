-- SadakatQR ayrı Supabase projesi. Ön koşul: loyalty-ad-requests.sql ve loyalty-ad-cards-to-offers.sql.
-- Kamuya yalnızca onaylı ve süresi dolmamış aktif kampanyaların sınırlı bilgileri sunulur.
create or replace function public.loyalty_public_sponsored_offers(p_placement text default 'offers')
returns table(campaign_id uuid,business_name text,campaign_name text,stamps_required integer)
language sql stable security definer set search_path=''
as $$
 select c.id,b.name::text,c.name::text,c.stamps_required::integer
 from public.loyalty_ad_requests a
 join public.loyalty_campaigns c on c.id=a.campaign_id and c.business_id=a.business_id
 join public.loyalty_businesses b on b.id=a.business_id
 where a.placement=p_placement
   and p_placement in ('home','offers','gifts','regional_popup')
   and a.status='approved' and a.approved_at <= now()
   and a.ends_at > now() and c.active=true and b.status='approved'
 order by a.approved_at desc,c.id
 limit 30;
$$;
revoke all on function public.loyalty_public_sponsored_offers(text) from public;
grant execute on function public.loyalty_public_sponsored_offers(text) to anon,authenticated;
