-- Run only in SadakatQR project mplmmoehzsmohjikpqvj.
-- Read-only customer directory; only verified administrators can access Auth contact data.
create or replace function public.loyalty_admin_customers()
returns table(customer_id uuid,full_name text,email text,joined_at timestamptz,last_sign_in_at timestamptz,stamp_count bigint,reward_count bigint,business_count bigint)
language plpgsql security definer set search_path='' as $$
begin
 if (select auth.uid()) is null or not exists(select 1 from public.loyalty_admins a where a.user_id=(select auth.uid())) then
   raise exception 'Not authorized' using errcode='42501';
 end if;
 return query
 select u.id,coalesce(nullif(u.raw_user_meta_data->>'full_name',''),nullif(u.raw_user_meta_data->>'name',''))::text,u.email::text,u.created_at,u.last_sign_in_at,
 (select count(*) from public.loyalty_stamps s where s.customer_user_id=u.id),
 (select count(*) from public.loyalty_redemptions r where r.customer_user_id=u.id),
 (select count(distinct s.business_id) from public.loyalty_stamps s where s.customer_user_id=u.id)
 from auth.users u
 where not exists(select 1 from public.loyalty_businesses b where b.owner_user_id=u.id)
 and not exists(select 1 from public.loyalty_admins a where a.user_id=u.id)
 order by u.created_at desc limit 2000;
end $$;
revoke all on function public.loyalty_admin_customers() from public,anon;
grant execute on function public.loyalty_admin_customers() to authenticated;
create or replace function public.loyalty_admin_customer_activity(p_customer_id uuid)
returns table(business_name text,campaign_name text,activity_type text,activity_at timestamptz)
language plpgsql security definer set search_path='' as $$
begin
 if (select auth.uid()) is null or not exists(select 1 from public.loyalty_admins a where a.user_id=(select auth.uid())) then
  raise exception 'Not authorized' using errcode='42501';
 end if;
 return query
 select b.name,c.name,'Damga'::text,s.created_at from public.loyalty_stamps s
 join public.loyalty_businesses b on b.id=s.business_id
 join public.loyalty_campaigns c on c.id=s.campaign_id where s.customer_user_id=p_customer_id
 union all
 select b.name,c.name,'Ödül Kullanımı'::text,r.created_at from public.loyalty_redemptions r
 join public.loyalty_businesses b on b.id=r.business_id
 join public.loyalty_campaigns c on c.id=r.campaign_id where r.customer_user_id=p_customer_id
 order by activity_at desc limit 150;
end $$;
revoke all on function public.loyalty_admin_customer_activity(uuid) from public,anon;
grant execute on function public.loyalty_admin_customer_activity(uuid) to authenticated;
