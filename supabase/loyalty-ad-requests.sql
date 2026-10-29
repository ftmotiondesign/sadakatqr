-- ONLY separate SadakatQR Supabase project mplmmoehzsmohjikpqvj.
create table if not exists public.loyalty_ad_requests (
 id uuid primary key default gen_random_uuid(),
 business_id uuid not null references public.loyalty_businesses(id) on delete cascade,
 campaign_id uuid not null references public.loyalty_campaigns(id) on delete cascade,
 placement text not null check(placement in ('home','cards','gifts','regional_popup')),
 city text, district text,
 duration_days int not null check(duration_days in (30,90,365)),
 status text not null default 'pending' check(status in ('pending','approved','rejected','expired')),
 created_at timestamptz not null default now(),
 approved_at timestamptz,
 ends_at timestamptz,
 check(placement<>'regional_popup' or (city is not null and length(trim(city))>0))
);
alter table public.loyalty_ad_requests enable row level security;
revoke all on public.loyalty_ad_requests from anon,authenticated;

create or replace function public.loyalty_submit_ad_request(p_campaign_id uuid,p_placement text,p_city text default null,p_district text default null,p_duration_days int default 30)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_business uuid;v_id uuid;
begin
 select b.id into v_business from public.loyalty_businesses b
 join public.loyalty_campaigns c on c.business_id=b.id
 where b.owner_user_id=auth.uid() and b.status='approved' and c.id=p_campaign_id and c.active=true;
 if v_business is null then raise exception 'Onaylı işletmeye ait aktif kampanya gerekli';end if;
 if p_placement not in ('home','cards','gifts','regional_popup') or p_duration_days not in (30,90,365)
 then raise exception 'Geçersiz reklam alanı veya süre';end if;
 if p_placement='regional_popup' and nullif(trim(coalesce(p_city,'')),'') is null then raise exception 'İl zorunlu';end if;
 if length(coalesce(p_city,''))>80 or length(coalesce(p_district,''))>80 then raise exception 'Bölge alanı çok uzun';end if;
 insert into public.loyalty_ad_requests(business_id,campaign_id,placement,city,district,duration_days)
 values(v_business,p_campaign_id,p_placement,nullif(trim(p_city),''),nullif(trim(p_district),''),p_duration_days)
 returning id into v_id;
 return v_id;
end;$$;
revoke all on function public.loyalty_submit_ad_request(uuid,text,text,text,int) from public,anon;
grant execute on function public.loyalty_submit_ad_request(uuid,text,text,text,int) to authenticated;

create or replace function public.loyalty_my_ad_requests()
returns table(campaign_name text,placement text,city text,district text,duration_days int,status text,created_at timestamptz)
language sql stable security definer set search_path='' as $$
 select c.name,r.placement,r.city,r.district,r.duration_days,r.status,r.created_at
 from public.loyalty_ad_requests r join public.loyalty_campaigns c on c.id=r.campaign_id
 join public.loyalty_businesses b on b.id=r.business_id
 where b.owner_user_id=auth.uid() and auth.uid() is not null
 order by r.created_at desc limit 100;
$$;
revoke all on function public.loyalty_my_ad_requests() from public,anon;
grant execute on function public.loyalty_my_ad_requests() to authenticated;

create or replace function public.loyalty_admin_ad_requests()
returns table(id uuid,business_name text,campaign_name text,placement text,city text,district text,duration_days int,status text,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not exists(select 1 from public.loyalty_admins a where a.user_id=auth.uid()) then raise exception 'Yönetici yetkisi gerekli';end if;
 return query select r.id,b.name,c.name,r.placement,r.city,r.district,r.duration_days,r.status,r.created_at
 from public.loyalty_ad_requests r join public.loyalty_businesses b on b.id=r.business_id
 join public.loyalty_campaigns c on c.id=r.campaign_id order by r.created_at desc limit 500;
end;$$;
revoke all on function public.loyalty_admin_ad_requests() from public,anon;
grant execute on function public.loyalty_admin_ad_requests() to authenticated;

create or replace function public.loyalty_admin_decide_ad(p_id uuid,p_approve boolean)
returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not exists(select 1 from public.loyalty_admins a where a.user_id=auth.uid()) then raise exception 'Yönetici yetkisi gerekli';end if;
 update public.loyalty_ad_requests
 set status=case when p_approve then 'approved' else 'rejected' end,
 approved_at=case when p_approve then now() else null end,
 ends_at=case when p_approve then now()+duration_days*interval '1 day' else null end
 where id=p_id and status='pending';
 if not found then raise exception 'Bekleyen başvuru bulunamadı';end if;
end;$$;
revoke all on function public.loyalty_admin_decide_ad(uuid,boolean) from public,anon;
grant execute on function public.loyalty_admin_decide_ad(uuid,boolean) to authenticated;
