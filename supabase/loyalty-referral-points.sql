-- ONLY SadakatQR Supabase project mplmmoehzsmohjikpqvj.
-- 10 points for a referred member's FIRST confirmed purchase (stamp).
-- Existing stamp, reward and account records remain untouched.
create table if not exists public.loyalty_referrals (
 id uuid primary key default gen_random_uuid(),
 referrer_id uuid not null references auth.users(id) on delete cascade,
 referred_id uuid not null unique references auth.users(id) on delete cascade,
 created_at timestamptz not null default now(),
 rewarded_at timestamptz,
 rewarded_business_id uuid references public.loyalty_businesses(id),
 points_awarded integer not null default 0 check(points_awarded in (0,10)),
 check(referrer_id <> referred_id)
);
create index if not exists loyalty_referrals_referrer_idx on public.loyalty_referrals(referrer_id);
alter table public.loyalty_referrals enable row level security;
revoke all on public.loyalty_referrals from anon,authenticated;

create or replace function public.loyalty_claim_referral(p_referrer_code text)
returns text language plpgsql security definer set search_path='' as $$
declare v_inviter uuid;v_user uuid:=auth.uid();
begin
 if v_user is null then raise exception 'Önce giriş yapmalısın'; end if;
 if p_referrer_code !~ '^[1-9][0-9]{5}$' then raise exception 'Geçersiz referans kodu'; end if;
 select user_id into v_inviter from public.loyalty_short_codes where short_code=p_referrer_code::integer;
 if v_inviter is null then raise exception 'Referans kodu bulunamadı'; end if;
 if v_user=v_inviter then raise exception 'Kendi kodunu kullanamazsın'; end if;
 if exists(select 1 from public.loyalty_stamps where customer_user_id=v_user)
    or exists(select 1 from public.loyalty_redemptions where customer_user_id=v_user) then
   raise exception 'Referans yalnızca ilk alışverişten önce kullanılabilir';
 end if;
 insert into public.loyalty_referrals(referrer_id,referred_id) values(v_inviter,v_user)
 on conflict(referred_id) do nothing;
 if not found then raise exception 'Bu hesapta referans zaten kullanılmış'; end if;
 return 'Referans kabul edildi. İlk doğrulanmış alışverişinden sonra davet eden 10 puan kazanacak.';
end $$;
revoke all on function public.loyalty_claim_referral(text) from public,anon;
grant execute on function public.loyalty_claim_referral(text) to authenticated;

create or replace function public.loyalty_reward_referrer_on_stamp()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 -- Only trigger on a legitimate completed stamp, one award per referred user.
 update public.loyalty_referrals r
 set rewarded_at=now(),rewarded_business_id=new.business_id,points_awarded=10
 where r.referred_id=new.customer_user_id and r.rewarded_at is null
 and not exists(select 1 from public.loyalty_stamps s where s.customer_user_id=new.customer_user_id and s.id<>new.id);
 return new;
end $$;
drop trigger if exists loyalty_referrer_first_stamp on public.loyalty_stamps;
create trigger loyalty_referrer_first_stamp after insert on public.loyalty_stamps
for each row execute function public.loyalty_reward_referrer_on_stamp();

create or replace function public.loyalty_my_referral_stats()
returns table(referral_count bigint,approved_count bigint,total_points bigint)
language sql stable security definer set search_path='' as $$
 select count(*)::bigint,count(*) filter(where rewarded_at is not null)::bigint,
 coalesce(sum(points_awarded),0)::bigint from public.loyalty_referrals where referrer_id=auth.uid()
$$;
revoke all on function public.loyalty_my_referral_stats() from public,anon;
grant execute on function public.loyalty_my_referral_stats() to authenticated;
