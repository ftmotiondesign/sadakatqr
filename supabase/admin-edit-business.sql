-- Apply ONLY to SadakatQR project mplmmoehzsmohjikpqvj.
-- Allow only explicitly approved FTMotion admins to edit business profile fields.
create or replace function public.loyalty_admin_update_business(
  p_business_id uuid, p_name text, p_contact_full_name text, p_phone text
) returns void language plpgsql security definer set search_path=''
as $$
begin
 if (select auth.uid()) is null or not exists
   (select 1 from public.loyalty_admins a where a.user_id=(select auth.uid())) then
  raise exception 'Not authorized' using errcode='42501';
 end if;
 if char_length(trim(coalesce(p_name,''))) not between 3 and 150 then
  raise exception 'İşletme adı 3-150 karakter olmalıdır';
 end if;
 if char_length(coalesce(p_contact_full_name,''))>120 or char_length(coalesce(p_phone,''))>30 then
  raise exception 'Bilgi uzunluğu sınırı aşıldı';
 end if;
 update public.loyalty_businesses
 set name=trim(p_name),
     contact_full_name=nullif(trim(coalesce(p_contact_full_name,'')),''),
     phone=nullif(trim(coalesce(p_phone,'')),'')
 where id=p_business_id;
 if not found then raise exception 'İşletme bulunamadı'; end if;
end $$;
revoke all on function public.loyalty_admin_update_business(uuid,text,text,text) from public,anon;
grant execute on function public.loyalty_admin_update_business(uuid,text,text,text) to authenticated;
