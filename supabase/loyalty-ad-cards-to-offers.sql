-- SadakatQR separate Supabase project only.
-- Change the advertising placement 'cards' into 'offers', preserving existing applications.
do $$
declare constraint_name text;
begin
 for constraint_name in
   select conname from pg_constraint
   where conrelid='public.loyalty_ad_requests'::regclass
     and contype='c' and pg_get_constraintdef(oid) ilike '%placement%'
 loop
   execute format('alter table public.loyalty_ad_requests drop constraint %I',constraint_name);
 end loop;
 update public.loyalty_ad_requests set placement='offers' where placement='cards';
 alter table public.loyalty_ad_requests
   add constraint loyalty_ad_requests_placement_check
   check(placement in ('home','offers','gifts','regional_popup'));
end $$;

create or replace function public.loyalty_submit_ad_request(
 p_campaign_id uuid,p_placement text,p_city text default null,
 p_district text default null,p_duration_days int default 30)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_business uuid;v_id uuid;
begin
 select b.id into v_business from public.loyalty_businesses b
 join public.loyalty_campaigns c on c.business_id=b.id
 where b.owner_user_id=auth.uid() and b.status='approved' and c.id=p_campaign_id and c.active=true;
 if v_business is null then raise exception 'Onaylı işletmeye ait aktif kampanya gerekli';end if;
 if p_placement not in ('home','offers','gifts','regional_popup') or p_duration_days not in (30,90,365)
 then raise exception 'Geçersiz reklam alanı veya süre';end if;
 if p_placement='regional_popup' and nullif(trim(coalesce(p_city,'')),'') is null then raise exception 'İl zorunlu';end if;
 if length(coalesce(p_city,''))>80 or length(coalesce(p_district,''))>80 then raise exception 'Bölge alanı çok uzun';end if;
 insert into public.loyalty_ad_requests(business_id,campaign_id,placement,city,district,duration_days)
 values(v_business,p_campaign_id,p_placement,nullif(trim(p_city),''),nullif(trim(p_district),''),p_duration_days)
 returning id into v_id;
 return v_id;
end;$$;
revoke all on function public.loyalty_submit_ad_request(uuid,text,text,text,int) from public,anon;
grant execute on function public.loyalty_submit_ad_request(uuid,text,text,text,int) to authenticated;
