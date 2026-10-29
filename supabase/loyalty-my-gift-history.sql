-- Run only in the separate SadakatQR Supabase project.
-- Return every delivered gift individually, newest first, for the signed-in customer.
create or replace function public.loyalty_my_gift_history()
returns table(gift_id uuid, business_name text, campaign_name text, received_at timestamptz)
language sql stable security definer set search_path=''
as $$
 select r.id,b.name,c.name,r.created_at
 from public.loyalty_redemptions r
 join public.loyalty_businesses b on b.id=r.business_id
 join public.loyalty_campaigns c on c.id=r.campaign_id and c.business_id=r.business_id
 where auth.uid() is not null and r.customer_user_id=auth.uid()
 order by r.created_at desc,r.id desc;
$$;
revoke all on function public.loyalty_my_gift_history() from public,anon;
grant execute on function public.loyalty_my_gift_history() to authenticated;
