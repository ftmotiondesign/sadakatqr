-- Yalnızca SadakatQR (mplmmoehzsmohjikpqvj).
-- Müşteri yalnızca kendi tavsiye kayıtlarının özetini görür.
-- Davet edilen kişinin kişisel verileri paylaşılmaz.
create or replace function public.loyalty_my_referral_history()
returns table (
  referral_id uuid,
  created_at timestamptz,
  rewarded_at timestamptz,
  points_awarded integer,
  business_name text,
  status text
)
language sql stable security definer set search_path=''
as $$
  select r.id, r.created_at, r.rewarded_at, r.points_awarded,
         case when r.rewarded_at is not null then b.name else null end,
         case when r.rewarded_at is not null then 'rewarded' else 'pending' end
  from public.loyalty_referrals r
  left join public.loyalty_businesses b on b.id=r.rewarded_business_id
  where auth.uid() is not null and r.referrer_id=auth.uid()
  order by r.created_at desc
  limit 100;
$$;
revoke all on function public.loyalty_my_referral_history() from public,anon;
grant execute on function public.loyalty_my_referral_history() to authenticated;
