-- Run only in SadakatQR Supabase project mplmmoehzsmohjikpqvj.
-- Public endpoint returns only approved business and active campaign fields.
create or replace function public.loyalty_public_business_campaigns(p_business_id uuid)
returns table(business_name text,city text,district text,sector text,campaign_id uuid,campaign_name text,stamps_required smallint)
language sql security definer set search_path = ''
as $$
 select b.name,b.city,b.district,b.sector,c.id,c.name,c.stamps_required
 from public.loyalty_businesses b join public.loyalty_campaigns c on c.business_id=b.id
 where b.id=p_business_id and b.status='approved' and c.active=true
 order by c.created_at desc;
$$;
revoke all on function public.loyalty_public_business_campaigns(uuid) from public;
grant execute on function public.loyalty_public_business_campaigns(uuid) to anon,authenticated;
