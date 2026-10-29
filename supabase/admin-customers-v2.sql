-- ONLY SadakatQR project mplmmoehzsmohjikpqvj.
-- Includes accounts with a real customer number even when also business owners.
create or replace function public.loyalty_admin_customers_v2()
returns table(customer_id uuid,full_name text,email text,joined_at timestamptz,last_sign_in_at timestamptz,stamp_count bigint,reward_count bigint,business_count bigint,customer_number integer,account_type text)
language plpgsql security definer set search_path='' as $$
begin
 if (select auth.uid()) is null or not exists(select 1 from public.loyalty_admins a where a.user_id=(select auth.uid())) then
   raise exception 'Not authorized' using errcode='42501';
 end if;
 return query
 select u.id,
 coalesce(nullif(u.raw_user_meta_data->>'full_name',''),nullif(u.raw_user_meta_data->>'name',''))::text,
 u.email::text,u.created_at,u.last_sign_in_at,
 (select count(*) from public.loyalty_stamps s where s.customer_user_id=u.id),
 (select count(*) from public.loyalty_redemptions r where r.customer_user_id=u.id),
 (select count(distinct s.business_id) from public.loyalty_stamps s where s.customer_user_id=u.id),
 sc.short_code,
 case when exists(select 1 from public.loyalty_businesses b where b.owner_user_id=u.id) then 'İşletme + Müşteri'
      when exists(select 1 from public.loyalty_admins a where a.user_id=u.id) then 'Yönetici + Müşteri'
      else 'Müşteri' end::text
 from auth.users u
 left join public.loyalty_short_codes sc on sc.user_id=u.id
 where sc.short_code is not null
 or (not exists(select 1 from public.loyalty_businesses b where b.owner_user_id=u.id)
 and not exists(select 1 from public.loyalty_admins a where a.user_id=u.id))
 order by u.created_at desc limit 2000;
end $$;
revoke all on function public.loyalty_admin_customers_v2() from public,anon;
grant execute on function public.loyalty_admin_customers_v2() to authenticated;
