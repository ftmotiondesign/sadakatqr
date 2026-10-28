-- SadakatQR bağımsız müşteri profilleri
-- Supabase > SQL Editor > New query bölümünde çalıştırın.
-- Sadece yeni SadakatQR projesinde uygulayın.
create table if not exists public.customer_profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null check (char_length(trim(full_name)) between 3 and 120),
 created_at timestamptz not null default now()
);
alter table public.customer_profiles enable row level security;
revoke all on public.customer_profiles from anon;
grant select, insert, update on public.customer_profiles to authenticated;
create policy "customer_select_own" on public.customer_profiles
 for select to authenticated using ((select auth.uid()) = user_id);
create policy "customer_insert_own" on public.customer_profiles
 for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "customer_update_own" on public.customer_profiles
 for update to authenticated using ((select auth.uid()) = user_id)
 with check ((select auth.uid()) = user_id);
-- Profil tablosu henüz arayüze bağlanmadı. Üyelik Supabase Auth üzerinden çalışır.
