-- SadakatQR ayrı Supabase projesi. Önce loyalty-sponsored-gift-offers.sql kurulmuş olmalı.
-- Yalnızca public.loyalty_admins içindeki yetkili kullanıcılar sponsor onaylayabilir.
create or replace function public.loyalty_admin_sponsor_list()
returns table(campaign_id uuid,business_name text,campaign_name text,active boolean,approved boolean,starts_at timestamptz,ends_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not exists(select 1 from public.loyalty_admins a where a.user_id=auth.uid()) then
  raise exception 'Yönetici yetkisi gerekli';
 end if;
 return query select c.id,b.name,c.name,c.active,coalesce(p.approved,false),p.starts_at,p.ends_at
 from public.loyalty_campaigns c join public.loyalty_businesses b on b.id=c.business_id
 left join public.loyalty_sponsored_placements p on p.campaign_id=c.id
 order by c.created_at desc;
end;
$$;
revoke all on function public.loyalty_admin_sponsor_list() from public,anon;
grant execute on function public.loyalty_admin_sponsor_list() to authenticated;

create or replace function public.loyalty_admin_set_sponsor(p_campaign_id uuid,p_approved boolean)
returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not exists(select 1 from public.loyalty_admins a where a.user_id=auth.uid()) then
  raise exception 'Yönetici yetkisi gerekli';
 end if;
 if not exists(select 1 from public.loyalty_campaigns c where c.id=p_campaign_id) then raise exception 'Kampanya bulunamadı';end if;
 insert into public.loyalty_sponsored_placements(campaign_id,approved,starts_at,ends_at)
 values(p_campaign_id,p_approved,case when p_approved then now() else null end,case when p_approved then now()+interval '30 days' else null end)
 on conflict(campaign_id) do update set approved=excluded.approved,
 starts_at=case when excluded.approved then now() else public.loyalty_sponsored_placements.starts_at end,
 ends_at=case when excluded.approved then now()+interval '30 days' else public.loyalty_sponsored_placements.ends_at end;
end;
$$;
revoke all on function public.loyalty_admin_set_sponsor(uuid,boolean) from public,anon;
grant execute on function public.loyalty_admin_set_sponsor(uuid,boolean) to authenticated;
