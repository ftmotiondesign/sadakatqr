-- ONLY SadakatQR's separate Supabase project.
-- Business owner gets counts for own approved business, never email or sensitive customer data.
create or replace function public.loyalty_business_insights()
returns table(customer_code integer, stamp_count bigint, reward_count bigint, last_activity timestamptz)
language sql stable security definer set search_path=''
as $$
 with mine as (
   select b.id from public.loyalty_businesses b
   where b.owner_user_id=auth.uid() and b.status='approved'
 ), movements as (
  select s.customer_user_id,s.created_at,1::bigint stamps,0::bigint rewards
  from public.loyalty_stamps s join mine on mine.id=s.business_id
  union all
  select r.customer_user_id,r.created_at,0::bigint,1::bigint
  from public.loyalty_redemptions r join mine on mine.id=r.business_id
 )
 select sc.short_code,sum(m.stamps)::bigint,sum(m.rewards)::bigint,max(m.created_at)
 from movements m
 left join public.loyalty_short_codes sc on sc.user_id=m.customer_user_id
 group by m.customer_user_id,sc.short_code
 order by max(m.created_at) desc
$$;
revoke all on function public.loyalty_business_insights() from public,anon;
grant execute on function public.loyalty_business_insights() to authenticated;
