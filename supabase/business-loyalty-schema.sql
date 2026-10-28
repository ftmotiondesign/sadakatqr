-- SadakatQR işletme altyapısı — yeni/ayrı Supabase projesinin SQL Editor ekranında çalıştırın.
-- Bu dosya FTMotion'un eski Supabase projesine uygulanmamalıdır.
-- Başvurular otomatik onaylanmaz; yalnızca yetkili veritabanı yöneticisi onaylayabilir.
create extension if not exists pgcrypto;
create table if not exists public.loyalty_businesses (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 3 and 150),
  phone text,
  status text not null default 'pending' check (status in ('pending','approved','rejected','suspended')),
  created_at timestamptz not null default now(),
  approved_at timestamptz,
  unique(owner_user_id)
);
create table if not exists public.loyalty_campaigns (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.loyalty_businesses(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 3 and 120),
  stamps_required smallint not null check (stamps_required between 2 and 30),
  active boolean not null default false,
  created_at timestamptz not null default now()
);
create table if not exists public.loyalty_stamps (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.loyalty_businesses(id),
  campaign_id uuid not null references public.loyalty_campaigns(id),
  customer_user_id uuid not null references auth.users(id),
  issued_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);
create index if not exists loyalty_stamps_customer_idx on public.loyalty_stamps(customer_user_id,created_at desc);
create index if not exists loyalty_stamps_business_idx on public.loyalty_stamps(business_id,created_at desc);
create table if not exists public.loyalty_redemptions (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.loyalty_businesses(id),
  campaign_id uuid not null references public.loyalty_campaigns(id),
  customer_user_id uuid not null references auth.users(id),
  redeemed_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);
alter table public.loyalty_businesses enable row level security;
alter table public.loyalty_campaigns enable row level security;
alter table public.loyalty_stamps enable row level security;
alter table public.loyalty_redemptions enable row level security;
revoke all on public.loyalty_businesses,public.loyalty_campaigns,public.loyalty_stamps,public.loyalty_redemptions from anon;
grant select,insert on public.loyalty_businesses to authenticated;
grant select on public.loyalty_campaigns,public.loyalty_stamps,public.loyalty_redemptions to authenticated;
drop policy if exists loyalty_business_read_self on public.loyalty_businesses;
create policy loyalty_business_read_self on public.loyalty_businesses for select to authenticated using (owner_user_id=(select auth.uid()));
drop policy if exists loyalty_business_apply_self on public.loyalty_businesses;
create policy loyalty_business_apply_self on public.loyalty_businesses for insert to authenticated
  with check (owner_user_id=(select auth.uid()) and status='pending' and approved_at is null);
drop policy if exists loyalty_campaign_read_approved_owner on public.loyalty_campaigns;
create policy loyalty_campaign_read_approved_owner on public.loyalty_campaigns for select to authenticated
  using (exists(select 1 from public.loyalty_businesses b where b.id=business_id and b.owner_user_id=(select auth.uid()) and b.status='approved'));
drop policy if exists loyalty_stamp_read_customer on public.loyalty_stamps;
create policy loyalty_stamp_read_customer on public.loyalty_stamps for select to authenticated using(customer_user_id=(select auth.uid()));
drop policy if exists loyalty_stamp_read_business on public.loyalty_stamps;
create policy loyalty_stamp_read_business on public.loyalty_stamps for select to authenticated
  using (exists(select 1 from public.loyalty_businesses b where b.id=business_id and b.owner_user_id=(select auth.uid()) and b.status='approved'));
drop policy if exists loyalty_redemption_read_customer on public.loyalty_redemptions;
create policy loyalty_redemption_read_customer on public.loyalty_redemptions for select to authenticated using(customer_user_id=(select auth.uid()));
drop policy if exists loyalty_redemption_read_business on public.loyalty_redemptions;
create policy loyalty_redemption_read_business on public.loyalty_redemptions for select to authenticated
  using(exists(select 1 from public.loyalty_businesses b where b.id=business_id and b.owner_user_id=(select auth.uid()) and b.status='approved'));
-- Önce yöneticinin onay yöntemi ve damga RPC'si kurulmalı; bu aşamada istemciye INSERT/UPDATE/DELETE yetkisi VERİLMEZ.
-- Yönetici onayı için yalnızca Supabase SQL Editor'da ayrıcalıklı operatör tarafından örnek:
-- update public.loyalty_businesses set status='approved',approved_at=now() where id='<önceden doğrulanmış başvuru UUID>';
