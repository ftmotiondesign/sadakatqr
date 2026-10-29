-- SadakatQR ONLY: run in project mplmmoehzsmohjikpqvj.
-- Read-only business owner/status diagnosis.
select b.id as business_id,b.name,b.status,b.owner_user_id,u.email as owner_email
from public.loyalty_businesses b
left join auth.users u on u.id=b.owner_user_id
order by b.created_at desc nulls last;
select policyname,cmd,roles,qual,with_check from pg_policies
where schemaname='storage' and tablename='objects' and policyname like 'loyalty_cover_%'
order by policyname;
select id,name,public from storage.buckets where id='loyalty-covers';
