-- Yalnızca AYRI SadakatQR Supabase projesinde çalıştırın.
-- Sponsor yayınları otomatik açılmaz; ödeme ve yönetici onayı sonrasında
-- yetkili yönetici tarafından veritabanı tarafında onaylanmalıdır.
create table if not exists public.loyalty_sponsored_placements(
 id uuid primary key default gen_random_uuid(),
 campaign_id uuid not null unique references public.loyalty_campaigns(id) on delete cascade,
 approved boolean not null default false,
 starts_at timestamptz,
 ends_at timestamptz,
 created_at timestamptz not null default now(),
 check (ends_at is null or starts_at is null or ends_at > starts_at)
);
alter table public.loyalty_sponsored_placements enable row level security;
revoke all on public.loyalty_sponsored_placements from anon,authenticated;

create or replace function public.loyalty_sponsored_offers_for_gift(p_gift_id uuid)
returns table(business_name text,campaign_name text,stamps_required smallint)
language plpgsql stable security definer set search_path=''
as $$
declare v_business_id uuid;
begin
 if auth.uid() is null then raise exception 'Oturum gerekli';end if;
 select r.business_id into v_business_id from public.loyalty_redemptions r
 where r.id=p_gift_id and r.customer_user_id=auth.uid();
 if v_business_id is null then raise exception 'Hediye bulunamadı';end if;
 return query
 select b.name,c.name,c.stamps_required
 from public.loyalty_campaigns c
 join public.loyalty_businesses b on b.id=c.business_id
 join public.loyalty_sponsored_placements p on p.campaign_id=c.id
 where c.business_id=v_business_id and c.active=true and b.status='approved'
 and p.approved=true and (p.starts_at is null or p.starts_at<=now())
 and (p.ends_at is null or p.ends_at>now())
 order by p.created_at desc;
end;
$$;
revoke all on function public.loyalty_sponsored_offers_for_gift(uuid) from public,anon;
grant execute on function public.loyalty_sponsored_offers_for_gift(uuid) to authenticated;
