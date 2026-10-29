-- Yalnızca SadakatQR projesi: mplmmoehzsmohjikpqvj
-- Mevcut başvurular ve yönetici yetkileri korunur.
alter table public.loyalty_businesses add column if not exists contact_full_name text;
alter table public.loyalty_businesses add constraint loyalty_contact_full_name_length check (contact_full_name is null or char_length(contact_full_name)<=120);
-- Yeni kayıtlar başvuru sahibi tarafından yazılır; e-posta auth.users'dan okunur.
create or replace function public.loyalty_admin_businesses_v2()
returns table(id uuid,name text,status text,phone text,owner_user_id uuid,created_at timestamptz,contact_full_name text,contact_email text)
language plpgsql security definer set search_path=''
as $$
begin
 if (select auth.uid()) is null or not exists(select 1 from public.loyalty_admins a where a.user_id=(select auth.uid())) then
   raise exception 'Not authorized' using errcode='42501';
 end if;
 return query
 select b.id,b.name,b.status,b.phone,b.owner_user_id,b.created_at,
        b.contact_full_name,u.email::text
 from public.loyalty_businesses b
 left join auth.users u on u.id=b.owner_user_id
 order by b.created_at desc limit 300;
end $$;
revoke all on function public.loyalty_admin_businesses_v2() from public,anon;
grant execute on function public.loyalty_admin_businesses_v2() to authenticated;
-- Önceki fonksiyonun dönüş tipi değiştiği için CREATE OR REPLACE doğrudan hata verirse,
-- kontrollü geçiş için ayrı bir v2 adı kullanılır (aşağıdaki v2 güvenli ve bağımsızdır).
