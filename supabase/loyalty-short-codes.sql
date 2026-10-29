-- SADAKATQR'NİN AYRI SUPABASE PROJESİNE UYGULAYIN.
-- Mevcut UUID tabanlı QR kodları ve damga kayıtları korunur.
create table if not exists public.loyalty_short_codes (
 user_id uuid primary key references auth.users(id) on delete cascade,
 short_code integer not null unique check (short_code between 100000 and 999999),
 created_at timestamptz not null default now()
);
alter table public.loyalty_short_codes enable row level security;
revoke all on public.loyalty_short_codes from anon,authenticated;
grant select on public.loyalty_short_codes to authenticated;
drop policy if exists loyalty_short_code_self on public.loyalty_short_codes;
create policy loyalty_short_code_self on public.loyalty_short_codes
 for select to authenticated using (user_id=(select auth.uid()));

create or replace function public.loyalty_my_short_code()
returns integer language plpgsql security definer set search_path='' as $$
declare v_user uuid := auth.uid(); v_code integer;
begin
 if v_user is null then raise exception 'Giriş yapmalısınız'; end if;
 select short_code into v_code from public.loyalty_short_codes where user_id=v_user;
 if v_code is not null then return v_code; end if;
 -- Benzersiz numara eşzamanlı yeni üyeliklerde de güvenle atanır.
 for i in 1..30 loop
  v_code := floor(100000 + random()*900000)::integer;
  insert into public.loyalty_short_codes(user_id,short_code)
   values(v_user,v_code) on conflict do nothing;
  select short_code into v_code from public.loyalty_short_codes where user_id=v_user;
  if v_code is not null then return v_code; end if;
 end loop;
 raise exception 'Müşteri numarası üretilemedi, lütfen tekrar deneyin';
end;
$$;
revoke all on function public.loyalty_my_short_code() from public,anon;
grant execute on function public.loyalty_my_short_code() to authenticated;

-- Yalnızca onaylı işletmeler, aktif kampanyalarında numarayı damgaya dönüştürebilir.
-- Bu, önce kurulmuş olan loyalty_issue_stamp(uuid,uuid) fonksiyonunu çağırır.
create or replace function public.loyalty_issue_stamp_code(
 p_campaign_id uuid,p_customer_code text
)
returns table(stamp_count bigint,stamps_required smallint)
language plpgsql security invoker set search_path='' as $$
declare v_customer_id uuid;
begin
 if p_customer_code !~ '^[1-9][0-9]{5}$' then
  raise exception 'Altı haneli müşteri numarası girin';
 end if;
 -- Lookup is confined to the definer helper, which itself checks approved ownership.
 return query select * from public.loyalty_issue_stamp_by_code(p_campaign_id,p_customer_code);
end;
$$;
-- Lookup helper keeps short-code table private, checks campaign ownership first.
create or replace function public.loyalty_issue_stamp_by_code(
 p_campaign_id uuid,p_customer_code text
)
returns table(stamp_count bigint,stamps_required smallint)
language plpgsql security definer set search_path='' as $$
declare v_customer_id uuid;
begin
 if auth.uid() is null or not exists(
  select 1 from public.loyalty_campaigns c join public.loyalty_businesses b on b.id=c.business_id
  where c.id=p_campaign_id and c.active and b.status='approved' and b.owner_user_id=auth.uid()
 ) then raise exception 'İşletme veya kampanya yetkisi yok'; end if;
 select sc.user_id into v_customer_id from public.loyalty_short_codes sc
 where sc.short_code=p_customer_code::integer;
 if v_customer_id is null then raise exception 'Müşteri numarası bulunamadı'; end if;
 return query select * from public.loyalty_issue_stamp(p_campaign_id,v_customer_id);
end;
$$;
revoke all on function public.loyalty_issue_stamp_by_code(uuid,text) from public,anon,authenticated;
revoke all on function public.loyalty_issue_stamp_code(uuid,text) from public,anon;
grant execute on function public.loyalty_issue_stamp_code(uuid,text) to authenticated;
