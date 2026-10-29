-- SadakatQR participation: approval by business, separate from stamp issuance.
create table if not exists public.loyalty_enrollments(
 id uuid primary key default gen_random_uuid(),
 business_id uuid not null references public.loyalty_businesses(id) on delete cascade,
 campaign_id uuid not null references public.loyalty_campaigns(id) on delete cascade,
 customer_user_id uuid not null references auth.users(id) on delete cascade,
 approved_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 unique(campaign_id,customer_user_id)
);
alter table public.loyalty_enrollments enable row level security;
revoke all on public.loyalty_enrollments from public,anon,authenticated;
create or replace function public.loyalty_approve_enrollment(p_campaign_id uuid,p_customer_code text)
returns text language plpgsql security definer set search_path='' as $$
declare v_business uuid;v_customer uuid;v_status text;v_code text;
begin
 if auth.uid() is null then raise exception 'Giriş gerekli';end if;
 select c.business_id,b.status into v_business,v_status from public.loyalty_campaigns c join public.loyalty_businesses b on b.id=c.business_id
 where c.id=p_campaign_id and c.active=true and b.owner_user_id=auth.uid();
 if v_business is null or v_status<>'approved' then raise exception 'Aktif kampanya veya işletme yetkisi bulunamadı';end if;
 v_code:=trim(p_customer_code);
 if v_code ~* '^SADAKATQR:[0-9a-f-]{36}$' then v_code:=substring(v_code from 11);end if;
 if v_code ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
   select id into v_customer from auth.users where id=v_code::uuid;
 elsif v_code ~ '^[0-9]{6}$' then
   select user_id into v_customer from public.loyalty_customer_codes where customer_code=v_code;
 else raise exception 'Geçerli müşteri QR veya kodu girin'; end if;
 if v_customer is null then raise exception 'Müşteri bulunamadı';end if;
 insert into public.loyalty_enrollments(business_id,campaign_id,customer_user_id,approved_by)
 values(v_business,p_campaign_id,v_customer,auth.uid())
 on conflict(campaign_id,customer_user_id) do nothing;
 if found then return 'Müşteri kampanyaya katıldı';else return 'Müşteri zaten bu kampanyaya katılmış';end if;
end $$;
revoke all on function public.loyalty_approve_enrollment(uuid,text) from public,anon;
grant execute on function public.loyalty_approve_enrollment(uuid,text) to authenticated;
create or replace function public.loyalty_my_enrollments()
returns table(campaign_id uuid,campaign_name text,business_name text,stamps_required smallint,created_at timestamptz)
language sql stable security definer set search_path='' as $$
 select c.id,c.name,b.name,c.stamps_required,e.created_at
 from public.loyalty_enrollments e join public.loyalty_campaigns c on c.id=e.campaign_id
 join public.loyalty_businesses b on b.id=e.business_id
 where auth.uid() is not null and e.customer_user_id=auth.uid()
 order by e.created_at desc
$$;
revoke all on function public.loyalty_my_enrollments() from public,anon;
grant execute on function public.loyalty_my_enrollments() to authenticated;
