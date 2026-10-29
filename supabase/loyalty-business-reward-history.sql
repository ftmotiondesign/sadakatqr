-- Execute only in SadakatQR separate Supabase project.
-- Each reward redemption has a customer code, campaign title and delivery date.
create or replace function public.loyalty_business_reward_history()
returns table(reward_id uuid, customer_code text, campaign_name text, redeemed_at timestamptz)
language plpgsql stable security definer set search_path=''
as $$
begin
 if auth.uid() is null then raise exception 'Giriş gerekli';end if;
 return query
 select r.id,sc.short_code::text,c.name::text,r.created_at
 from public.loyalty_redemptions r
 join public.loyalty_businesses b on b.id=r.business_id
 join public.loyalty_campaigns c on c.id=r.campaign_id and c.business_id=r.business_id
 left join public.loyalty_short_codes sc on sc.user_id=r.customer_user_id
 where b.owner_user_id=auth.uid() and b.status='approved'
 order by r.created_at desc limit 500;
end;$$;
revoke all on function public.loyalty_business_reward_history() from public,anon;
grant execute on function public.loyalty_business_reward_history() to authenticated;
