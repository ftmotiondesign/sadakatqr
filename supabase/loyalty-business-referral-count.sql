-- SadakatQR project only. Business acquisition attributed to a verified first stamp.
create or replace function public.loyalty_business_referral_count()
returns bigint language sql stable security definer set search_path='' as $$
select count(*)::bigint from public.loyalty_referrals r
join public.loyalty_businesses b on b.id=r.rewarded_business_id
where b.owner_user_id=auth.uid() and b.status='approved' and r.rewarded_at is not null
$$;
revoke all on function public.loyalty_business_referral_count() from public,anon;
grant execute on function public.loyalty_business_referral_count() to authenticated;
