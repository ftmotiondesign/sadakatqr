-- SADAKATQR AYRI SUPABASE PROJESİ İÇİNDİR (FTMotion ana projesinde ÇALIŞTIRMAYIN).
-- Gereken mevcut tablolar: public.loyalty_businesses, loyalty_campaigns,
-- loyalty_stamps ve auth.users (business-loyalty-schema.sql).
-- Bu fonksiyon yalnızca giriş yapmış, ONAYLI işletme sahibi için damga üretir.
-- Doğrulama ve kayıt tek veritabanı çağrısı içinde gerçekleştirilir.
create or replace function public.loyalty_issue_stamp(
 p_campaign_id uuid,
 p_customer_id uuid
)
returns table(stamp_count bigint, stamps_required smallint)
language plpgsql security definer
set search_path = ''
as $$
declare
 v_business_id uuid;
 v_required smallint;
 v_count bigint;
begin
 if auth.uid() is null then
  raise exception 'Oturum açılması gerekiyor';
 end if;
 select c.business_id, c.stamps_required into v_business_id, v_required
 from public.loyalty_campaigns c
 join public.loyalty_businesses b on b.id=c.business_id
 where c.id=p_campaign_id and c.active=true
 and b.status='approved' and b.owner_user_id=auth.uid();
 if v_business_id is null then
  raise exception 'Aktif kampanya bulunamadı veya işletme yetkisiz';
 end if;
 if not exists(select 1 from auth.users u where u.id=p_customer_id and u.email_confirmed_at is not null) then
  raise exception 'Doğrulanmış müşteri üyeliği bulunamadı';
 end if;
 -- Ödül/puan kullanımı başka bir işlemde hesaplanacak; bu fonksiyon yalnızca ham damgayı ekler.
 insert into public.loyalty_stamps(business_id,campaign_id,customer_user_id,issued_by)
 values(v_business_id,p_campaign_id,p_customer_id,auth.uid());
 select count(*) into v_count from public.loyalty_stamps s
 where s.campaign_id=p_campaign_id and s.customer_user_id=p_customer_id;
 return query select v_count,v_required;
end;
$$;
revoke all on function public.loyalty_issue_stamp(uuid,uuid) from public, anon;
grant execute on function public.loyalty_issue_stamp(uuid,uuid) to authenticated;
-- Damga tablosuna istemciden doğrudan INSERT yetkisi verilmez.
revoke insert, update, delete on public.loyalty_stamps from authenticated,anon;
