-- SadakatQR ayrı Supabase projesinde çalıştırın.
-- Yalnızca oturumdaki müşteri kendi damga ve ödül geçmişini görür.
create or replace function public.loyalty_my_reward_summary()
returns table (
 campaign_id uuid, campaign_name text, business_name text,
 stamps_required smallint, stamp_count bigint, available_stamps bigint,
 redeemed_count bigint, last_redeemed_at timestamptz, active boolean
)
language sql stable security definer set search_path = ''
as $$
 select c.id,c.name,b.name,c.stamps_required,
   coalesce(s.stamps,0)::bigint,
   greatest(0,coalesce(s.stamps,0)-coalesce(r.redeemed,0)*c.stamps_required)::bigint,
   coalesce(r.redeemed,0)::bigint,r.last_at,c.active
 from public.loyalty_campaigns c
 join public.loyalty_businesses b on b.id=c.business_id
 left join lateral (
   select count(*)::bigint stamps from public.loyalty_stamps ls
   where ls.campaign_id=c.id and ls.customer_user_id=auth.uid()
 ) s on true
 left join lateral (
   select count(*)::bigint redeemed,max(lr.created_at) last_at
   from public.loyalty_redemptions lr
   where lr.campaign_id=c.id and lr.customer_user_id=auth.uid()
 ) r on true
 where auth.uid() is not null
   and (coalesce(s.stamps,0)>0 or coalesce(r.redeemed,0)>0)
 order by c.name
$$;
revoke all on function public.loyalty_my_reward_summary() from public,anon;
grant execute on function public.loyalty_my_reward_summary() to authenticated;
