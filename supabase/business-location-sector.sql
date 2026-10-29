-- ONLY project mplmmoehzsmohjikpqvj (SadakatQR). Idempotent.
alter table public.loyalty_businesses add column if not exists city text;
alter table public.loyalty_businesses add column if not exists district text;
alter table public.loyalty_businesses add column if not exists sector text;
-- Secure business listing with geographic information for admin.
create or replace function public.loyalty_admin_businesses_v3()
returns table(id uuid,name text,status text,phone text,owner_user_id uuid,created_at timestamptz,contact_full_name text,contact_email text,city text,district text,sector text)
language plpgsql security definer set search_path='' as $$
begin
 if (select auth.uid()) is null or not exists(select 1 from public.loyalty_admins a where a.user_id=(select auth.uid())) then
  raise exception 'Not authorized' using errcode='42501';
 end if;
 return query select b.id,b.name,b.status,b.phone,b.owner_user_id,b.created_at,b.contact_full_name,u.email::text,b.city,b.district,b.sector
 from public.loyalty_businesses b left join auth.users u on u.id=b.owner_user_id
 order by b.created_at desc limit 500;
end $$;
revoke all on function public.loyalty_admin_businesses_v3() from public,anon;
grant execute on function public.loyalty_admin_businesses_v3() to authenticated;
-- Admin edit (new version; does not replace existing RPC).
create or replace function public.loyalty_admin_update_business_v2(p_business_id uuid,p_name text,p_contact_full_name text,p_phone text,p_city text,p_district text,p_sector text)
returns void language plpgsql security definer set search_path='' as $$
begin
 if (select auth.uid()) is null or not exists(select 1 from public.loyalty_admins a where a.user_id=(select auth.uid())) then
  raise exception 'Not authorized' using errcode='42501';
 end if;
 if length(trim(coalesce(p_name,''))) not between 3 and 150 then raise exception 'İşletme adı 3-150 karakter olmalı'; end if;
 if length(trim(coalesce(p_city,''))) not between 2 and 80 or length(trim(coalesce(p_district,''))) not between 2 and 80 or length(trim(coalesce(p_sector,''))) not between 2 and 100 then
  raise exception 'İl, ilçe ve sektör zorunlu'; end if;
 update public.loyalty_businesses set name=trim(p_name),contact_full_name=nullif(trim(coalesce(p_contact_full_name,'')),''),
 phone=nullif(trim(coalesce(p_phone,'')),''),city=trim(p_city),district=trim(p_district),sector=trim(p_sector)
 where id=p_business_id;
 if not found then raise exception 'İşletme bulunamadı'; end if;
end $$;
revoke all on function public.loyalty_admin_update_business_v2(uuid,text,text,text,text,text,text) from public,anon;
grant execute on function public.loyalty_admin_update_business_v2(uuid,text,text,text,text,text,text) to authenticated;
-- Business can edit only own location/sector, never change status or ownership.
create or replace function public.loyalty_business_update_location(p_city text,p_district text,p_sector text)
returns void language plpgsql security invoker set search_path='' as $$
begin
 if (select auth.uid()) is null then raise exception 'Oturum gerekli' using errcode='42501'; end if;
 if length(trim(coalesce(p_city,''))) not between 2 and 80 or length(trim(coalesce(p_district,''))) not between 2 and 80 or length(trim(coalesce(p_sector,''))) not between 2 and 100 then
 raise exception 'İl, ilçe ve sektör zorunlu'; end if;
 update public.loyalty_businesses set city=trim(p_city),district=trim(p_district),sector=trim(p_sector) where owner_user_id=(select auth.uid());
 if not found then raise exception 'İşletme bulunamadı veya güncelleme izni yok' using errcode='42501'; end if;
end $$;
-- RLS update limited to owner; grant narrowly to location fields, no status update.
grant update(city,district,sector) on public.loyalty_businesses to authenticated;
drop policy if exists "loyalty_business_own_location_update" on public.loyalty_businesses;
create policy "loyalty_business_own_location_update" on public.loyalty_businesses for update to authenticated
using (owner_user_id=(select auth.uid())) with check(owner_user_id=(select auth.uid()));
revoke all on function public.loyalty_business_update_location(text,text,text) from public,anon;
grant execute on function public.loyalty_business_update_location(text,text,text) to authenticated;
