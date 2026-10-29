-- SADECE SadakatQR Supabase projesinde çalıştırın.
-- Önkoşul: loyalty_businesses, loyalty_campaigns, loyalty_stamps,
-- loyalty_short_codes, loyalty_redemptions tabloları kurulu olmalı.
-- Ödüller geçmiş damgalardan silinmez. Kullanılabilir = toplam - (teslim x hedef).
-- Aktif/onaylı kampanya ve sahiplik doğrulanır; çift teslim transaction kilidiyle engellenir.
create or replace function public.loyalty_reward_status(
 p_campaign_id uuid, p_customer_input text
)
returns table(available_stamps bigint, stamps_required smallint, redeemed_count bigint, can_redeem boolean)
language plpgsql security definer set search_path='' as $$
declare v_customer uuid;v_business uuid;v_need smallint;v_total bigint;v_used bigint;
begin
 if auth.uid() is null then raise exception 'Giriş yapmalısınız';end if;
 select c.business_id,c.stamps_required into v_business,v_need
 from public.loyalty_campaigns c join public.loyalty_businesses b on b.id=c.business_id
 where c.id=p_campaign_id and c.active and b.status='approved' and b.owner_user_id=auth.uid();
 if v_business is null then raise exception 'Kampanya veya işletme yetkisi yok';end if;
 if p_customer_input ~ '^[1-9][0-9]{5}$' then
  select sc.user_id into v_customer from public.loyalty_short_codes sc where sc.short_code=p_customer_input::integer;
 elsif p_customer_input ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
  v_customer:=p_customer_input::uuid;
 else raise exception 'Geçersiz müşteri numarası';end if;
 if v_customer is null or not exists(select 1 from auth.users where id=v_customer) then
  raise exception 'Müşteri bulunamadı';
 end if;
 select count(*) into v_total from public.loyalty_stamps s
 where s.campaign_id=p_campaign_id and s.business_id=v_business and s.customer_user_id=v_customer;
 select count(*) into v_used from public.loyalty_redemptions r
 where r.campaign_id=p_campaign_id and r.business_id=v_business and r.customer_user_id=v_customer;
 return query select greatest(0,v_total-v_used*v_need),v_need,v_used,
 (v_total-v_used*v_need)>=v_need;
end;
$$;
revoke all on function public.loyalty_reward_status(uuid,text) from public,anon;
grant execute on function public.loyalty_reward_status(uuid,text) to authenticated;

create or replace function public.loyalty_redeem_reward(
 p_campaign_id uuid,p_customer_input text
)
returns table(available_stamps bigint,redeemed_count bigint)
language plpgsql security definer set search_path='' as $$
declare v_customer uuid;v_business uuid;v_need smallint;v_total bigint;v_used bigint;
begin
 if auth.uid() is null then raise exception 'Giriş yapmalısınız';end if;
 select c.business_id,c.stamps_required into v_business,v_need
 from public.loyalty_campaigns c join public.loyalty_businesses b on b.id=c.business_id
 where c.id=p_campaign_id and c.active and b.status='approved' and b.owner_user_id=auth.uid();
 if v_business is null then raise exception 'Kampanya veya işletme yetkisi yok';end if;
 if p_customer_input ~ '^[1-9][0-9]{5}$' then
  select sc.user_id into v_customer from public.loyalty_short_codes sc where sc.short_code=p_customer_input::integer;
 elsif p_customer_input ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
  v_customer:=p_customer_input::uuid;
 else raise exception 'Geçersiz müşteri numarası';end if;
 if v_customer is null or not exists(select 1 from auth.users where id=v_customer) then raise exception 'Müşteri bulunamadı';end if;
 -- Aynı müşteri + kampanya için eşzamanlı ödül teslimlerini sıraya koyar.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_campaign_id::text||':'||v_customer::text,0));
 select count(*) into v_total from public.loyalty_stamps s
 where s.campaign_id=p_campaign_id and s.business_id=v_business and s.customer_user_id=v_customer;
 select count(*) into v_used from public.loyalty_redemptions r
 where r.campaign_id=p_campaign_id and r.business_id=v_business and r.customer_user_id=v_customer;
 if v_total-v_used*v_need < v_need then raise exception 'Kullanılabilir ödül hakkı bulunmuyor';end if;
 insert into public.loyalty_redemptions(business_id,campaign_id,customer_user_id,redeemed_by)
 values(v_business,p_campaign_id,v_customer,auth.uid());
 return query select (v_total-(v_used+1)*v_need),(v_used+1);
end;
$$;
revoke all on function public.loyalty_redeem_reward(uuid,text) from public,anon;
grant execute on function public.loyalty_redeem_reward(uuid,text) to authenticated;
revoke insert,update,delete on public.loyalty_redemptions from anon,authenticated;
