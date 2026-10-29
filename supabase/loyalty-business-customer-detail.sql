-- ONLY SadakatQR separate Supabase project.
-- One approved business owner can inspect only its own customer's campaign totals.
create or replace function public.loyalty_business_customer_detail(p_customer_code text)
returns table(campaign_name text,stamps_required smallint,stamp_count bigint,
 available_stamps bigint,redeemed_count bigint,last_stamp_at timestamptz,last_redeemed_at timestamptz)
language plpgsql stable security definer set search_path=''
as $$
declare v_customer uuid;v_business uuid;
begin
 if auth.uid() is null or p_customer_code !~ '^[1-9][0-9]{5}$' then
  raise exception 'Yetkisiz veya geçersiz müşteri numarası';
 end if;
 select id into v_business from public.loyalty_businesses
 where owner_user_id=auth.uid() and status='approved' limit 1;
 if v_business is null then raise exception 'İşletme onayı gerekli';end if;
 select user_id into v_customer from public.loyalty_short_codes where short_code=p_customer_code::integer;
 if v_customer is null then raise exception 'Müşteri bulunamadı';end if;
 return query
 with movements as (
  select c.id,c.name,c.stamps_required,
   (select count(*) from public.loyalty_stamps s where s.business_id=v_business and s.campaign_id=c.id and s.customer_user_id=v_customer)::bigint stamps,
   (select max(s.created_at) from public.loyalty_stamps s where s.business_id=v_business and s.campaign_id=c.id and s.customer_user_id=v_customer) stamped,
   (select count(*) from public.loyalty_redemptions r where r.business_id=v_business and r.campaign_id=c.id and r.customer_user_id=v_customer)::bigint redeemed,
   (select max(r.created_at) from public.loyalty_redemptions r where r.business_id=v_business and r.campaign_id=c.id and r.customer_user_id=v_customer) redeemed_at
  from public.loyalty_campaigns c where c.business_id=v_business
 )
 select m.name,m.stamps_required,m.stamps,
 greatest(0,m.stamps-m.redeemed*m.stamps_required)::bigint,m.redeemed,m.stamped,m.redeemed_at
 from movements m where m.stamps>0 or m.redeemed>0 order by m.stamped desc nulls last;
end;
$$;
revoke all on function public.loyalty_business_customer_detail(text) from public,anon;
grant execute on function public.loyalty_business_customer_detail(text) to authenticated;
