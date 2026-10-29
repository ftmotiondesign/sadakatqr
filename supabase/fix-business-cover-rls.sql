-- SadakatQR ONLY: mplmmoehzsmohjikpqvj
-- Fix business-cover Storage RLS without opening access to other businesses.
-- Existing records and objects are untouched.
create or replace function public.loyalty_can_manage_cover_path(p_path text)
returns boolean
language plpgsql stable security definer set search_path=''
as $$
declare v_parts text[];v_owner uuid;
begin
 if auth.uid() is null or p_path is null then return false;end if;
 v_parts:=storage.foldername(p_path);
 if array_length(v_parts,1) <> 2
    or p_path !~ '^((customer)|(business))/[0-9a-f-]{36}/cover[.](jpg|png|webp)$'
 then return false;end if;
 begin v_owner:=v_parts[2]::uuid;exception when invalid_text_representation then return false;end;
 if v_parts[1]='customer' then return v_owner=auth.uid();end if;
 if v_parts[1]='business' then
   return exists(select 1 from public.loyalty_businesses b
     where b.id=v_owner and b.owner_user_id=auth.uid() and b.status='approved');
 end if;
 return false;
end $$;
revoke all on function public.loyalty_can_manage_cover_path(text) from public,anon;
grant execute on function public.loyalty_can_manage_cover_path(text) to authenticated;

drop policy if exists loyalty_cover_upload on storage.objects;
create policy loyalty_cover_upload on storage.objects
for insert to authenticated
with check(bucket_id='loyalty-covers' and public.loyalty_can_manage_cover_path(name));

drop policy if exists loyalty_cover_replace on storage.objects;
create policy loyalty_cover_replace on storage.objects
for update to authenticated
using(bucket_id='loyalty-covers' and public.loyalty_can_manage_cover_path(name))
with check(bucket_id='loyalty-covers' and public.loyalty_can_manage_cover_path(name));

drop policy if exists loyalty_cover_owner_select on storage.objects;
create policy loyalty_cover_owner_select on storage.objects
for select to authenticated
using(bucket_id='loyalty-covers' and public.loyalty_can_manage_cover_path(name));

-- Confirm policy installation
select policyname,cmd from pg_policies
where schemaname='storage' and tablename='objects'
and policyname in ('loyalty_cover_upload','loyalty_cover_replace','loyalty_cover_owner_select')
order by policyname;
