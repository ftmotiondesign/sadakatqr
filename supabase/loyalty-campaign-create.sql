-- SadakatQR ayrı Supabase projesinde çalıştırılacak.
-- Kampanyalar yalnızca kendi onaylı işletmesinin sahibi tarafından oluşturulabilir.
-- İstemciye UPDATE/DELETE yetkisi verilmez; kampanyalar başlangıçta pasiftir.
grant select, insert on table public.loyalty_campaigns to authenticated;
drop policy if exists loyalty_campaign_create_approved_owner on public.loyalty_campaigns;
create policy loyalty_campaign_create_approved_owner
on public.loyalty_campaigns for insert to authenticated
with check (
  active = false
  and exists (
    select 1 from public.loyalty_businesses b
    where b.id = business_id
      and b.owner_user_id = (select auth.uid())
      and b.status = 'approved'
  )
);
