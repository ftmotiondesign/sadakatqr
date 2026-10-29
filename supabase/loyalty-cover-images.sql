-- SADECE SadakatQR projesi mplmmoehzsmohjikpqvj içinde çalıştırılmalıdır.
-- Her kullanıcı kendi kapağını, işletme sahibi yalnızca kendi işletme kapağını değiştirebilir.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('loyalty-covers','loyalty-covers',true,3145728,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=true,file_size_limit=3145728,allowed_mime_types=array['image/jpeg','image/png','image/webp'];

create table if not exists public.loyalty_cover_images(
 owner_type text not null check(owner_type in ('customer','business')),
 owner_id uuid not null,
 image_path text not null,
 updated_at timestamptz not null default now(),
 primary key(owner_type,owner_id)
);
alter table public.loyalty_cover_images enable row level security;
revoke all on public.loyalty_cover_images from anon,authenticated;

create or replace function public.loyalty_set_cover(p_owner_type text,p_image_path text default null)
returns void language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_prefix text;
begin
 if auth.uid() is null then raise exception 'Giriş gerekli';end if;
 if p_owner_type='customer' then v_id:=auth.uid();
 elsif p_owner_type='business' then
  select id into v_id from public.loyalty_businesses where owner_user_id=auth.uid() and status='approved' limit 1;
 else raise exception 'Geçersiz hesap türü';end if;
 if v_id is null then raise exception 'Bu işletme için işlem yetkisi yok';end if;
 v_prefix:=p_owner_type||'/'||v_id::text||'/';
 if p_image_path is not null and
 (left(p_image_path,length(v_prefix))<>v_prefix or p_image_path !~ '^((customer)|(business))/[0-9a-f-]{36}/cover[.]((jpg)|(png)|(webp))$')
 then raise exception 'Geçersiz kapak dosyası';end if;
 if p_image_path is null then
  delete from public.loyalty_cover_images where owner_type=p_owner_type and owner_id=v_id;
 else
  insert into public.loyalty_cover_images(owner_type,owner_id,image_path)
  values(p_owner_type,v_id,p_image_path)
  on conflict(owner_type,owner_id) do update set image_path=excluded.image_path,updated_at=now();
 end if;
end;$$;
revoke all on function public.loyalty_set_cover(text,text) from public,anon;
grant execute on function public.loyalty_set_cover(text,text) to authenticated;

create or replace function public.loyalty_my_cover()
returns table(image_path text) language sql stable security definer set search_path='' as $$
 select c.image_path from public.loyalty_cover_images c
 where c.owner_type='customer' and c.owner_id=auth.uid() and auth.uid() is not null;
$$;
revoke all on function public.loyalty_my_cover() from public,anon;
grant execute on function public.loyalty_my_cover() to authenticated;

-- Business cover visible to its owner only via REST.
create policy loyalty_cover_business_read on public.loyalty_cover_images for select to authenticated
using(owner_type='business' and exists(
 select 1 from public.loyalty_businesses b
 where b.id=owner_id and b.owner_user_id=auth.uid()));

-- Storage policies: folder is customer/{user_id}/ or business/{business_id}/.
create policy loyalty_cover_upload on storage.objects for insert to authenticated
with check(bucket_id='loyalty-covers' and (
 ( (storage.foldername(name))[1]='customer' and (storage.foldername(name))[2]=auth.uid()::text )
 or
 ( (storage.foldername(name))[1]='business' and exists(
  select 1 from public.loyalty_businesses b where b.id::text=(storage.foldername(name))[2]
  and b.owner_user_id=auth.uid() and b.status='approved'))
));
create policy loyalty_cover_replace on storage.objects for update to authenticated
using(bucket_id='loyalty-covers' and (
 ((storage.foldername(name))[1]='customer' and (storage.foldername(name))[2]=auth.uid()::text)
 or ((storage.foldername(name))[1]='business' and exists(
 select 1 from public.loyalty_businesses b where b.id::text=(storage.foldername(name))[2]
 and b.owner_user_id=auth.uid() and b.status='approved'))
))
with check(bucket_id='loyalty-covers' and (
 ((storage.foldername(name))[1]='customer' and (storage.foldername(name))[2]=auth.uid()::text)
 or ((storage.foldername(name))[1]='business' and exists(
 select 1 from public.loyalty_businesses b where b.id::text=(storage.foldername(name))[2]
 and b.owner_user_id=auth.uid() and b.status='approved'))
));

-- Required for storage upsert (existing-object lookup); only own files are readable by API.
create policy loyalty_cover_owner_select on storage.objects for select to authenticated
using(bucket_id='loyalty-covers' and (
 ((storage.foldername(name))[1]='customer' and (storage.foldername(name))[2]=auth.uid()::text)
 or ((storage.foldername(name))[1]='business' and exists(
 select 1 from public.loyalty_businesses b
 where b.id::text=(storage.foldername(name))[2] and b.owner_user_id=auth.uid()))
));
