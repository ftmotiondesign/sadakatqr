-- SadakatQR ayrı Supabase projesi: yalnızca oturum açmış müşteri kendi kayıtlarını okur.
create or replace function public.loyalty_my_progress()
returns table(campaign_id uuid,campaign_name text,business_name text,stamps_required smallint,stamp_count bigint,active boolean)
language sql stable security definer set search_path=''
as $$
 select c.id,c.name,b.name,c.stamps_required,count(s.id)::bigint,c.active
 from public.loyalty_stamps s
 join public.loyalty_campaigns c on c.id=s.campaign_id
 join public.loyalty_businesses b on b.id=s.business_id
 where auth.uid() is not null and s.customer_user_id=auth.uid()
 group by c.id,c.name,b.name,c.stamps_required,c.active
 order by c.name
$$;
revoke all on function public.loyalty_my_progress() from public,anon;
grant execute on function public.loyalty_my_progress() to authenticated;
