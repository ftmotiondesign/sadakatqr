-- Run ONLY in the separate SadakatQR Supabase project.
-- Allow approved business owners to change status of their own campaigns.
grant update (active) on public.loyalty_campaigns to authenticated;
drop policy if exists loyalty_campaign_toggle_approved_owner on public.loyalty_campaigns;
create policy loyalty_campaign_toggle_approved_owner
on public.loyalty_campaigns for update to authenticated
using (exists(select 1 from public.loyalty_businesses b
 where b.id=business_id and b.owner_user_id=(select auth.uid()) and b.status='approved'))
with check (exists(select 1 from public.loyalty_businesses b
 where b.id=business_id and b.owner_user_id=(select auth.uid()) and b.status='approved'));
