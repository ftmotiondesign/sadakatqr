-- ONLY SadakatQR project mplmmoehzsmohjikpqvj.
-- Fix UNION sorting error in customer activity RPC.
create or replace function public.loyalty_admin_customer_activity(p_customer_id uuid)
returns table(business_name text,campaign_name text,activity_type text,activity_at timestamptz)
language plpgsql security definer set search_path='' as $$
begin
 if (select auth.uid()) is null or not exists(select 1 from public.loyalty_admins a where a.user_id=(select auth.uid())) then
   raise exception 'Not authorized' using errcode='42501';
 end if;
 return query select q.business_name,q.campaign_name,q.activity_type,q.activity_at
 from (
  select b.name::text as business_name,c.name::text as campaign_name,'Damga'::text as activity_type,s.created_at as activity_at
  from public.loyalty_stamps s
  join public.loyalty_businesses b on b.id=s.business_id
  join public.loyalty_campaigns c on c.id=s.campaign_id
  where s.customer_user_id=p_customer_id
  union all
  select b.name::text,c.name::text,'Ödül Kullanımı'::text,r.created_at
  from public.loyalty_redemptions r
  join public.loyalty_businesses b on b.id=r.business_id
  join public.loyalty_campaigns c on c.id=r.campaign_id
  where r.customer_user_id=p_customer_id
 ) q order by q.activity_at desc limit 150;
end $$;
revoke all on function public.loyalty_admin_customer_activity(uuid) from public,anon;
grant execute on function public.loyalty_admin_customer_activity(uuid) to authenticated;

-- Admin-only edit of customer's display name; never edits identity, email or short code.
create or replace function public.loyalty_admin_update_customer_name(p_customer_id uuid,p_full_name text)
returns void language plpgsql security definer set search_path='' as $$
begin
 if (select auth.uid()) is null or not exists(select 1 from public.loyalty_admins a where a.user_id=(select auth.uid())) then
   raise exception 'Not authorized' using errcode='42501';
 end if;
 if char_length(trim(coalesce(p_full_name,''))) not between 3 and 120 then
  raise exception 'Ad soyad 3-120 karakter arasında olmalı';
 end if;
 update auth.users
 set raw_user_meta_data=jsonb_set(coalesce(raw_user_meta_data,'{}'::jsonb),'{full_name}',to_jsonb(trim(p_full_name)),true),
 updated_at=now()
 where id=p_customer_id;
 if not found then raise exception 'Müşteri bulunamadı'; end if;
end $$;
revoke all on function public.loyalty_admin_update_customer_name(uuid,text) from public,anon;
grant execute on function public.loyalty_admin_update_customer_name(uuid,text) to authenticated;
