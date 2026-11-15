-- HOLD 033. Requires 020. Private digital delivery authorisation, not purchase issuance.
begin;
create table public.digital_delivery_audit(id uuid primary key default gen_random_uuid(),buyer_id uuid not null references auth.users(id),asset_id uuid not null references public.digital_private_assets(id),created_at timestamptz not null default now());
create index digital_delivery_buyer_time on public.digital_delivery_audit(buyer_id,created_at desc);
alter table public.digital_delivery_audit enable row level security;
revoke all on public.digital_delivery_audit from public,anon,authenticated,service_role;
grant select on public.digital_delivery_audit to authenticated;
create policy delivery_audit_owner on public.digital_delivery_audit for select to authenticated using(buyer_id=(select auth.uid()));
create function public.digital_delivery_catalogue() returns table(asset_id uuid,title text,version_label text) language sql stable security definer set search_path='' as $$select a.id,l.title,a.version_label from public.digital_private_assets a join public.digital_entitlements e on e.asset_id=a.id join public.specialist_listings l on l.id=a.listing_id where e.buyer_id=auth.uid() and e.revoked_at is null and a.scan_status='approved' and public.marketplace_verified_user() order by a.created_at desc limit 100;$$;
create function public.digital_authorize_delivery(p_asset uuid) returns text language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();asset public.digital_private_assets;
begin
 if caller is null or not public.digital_download_eligible(p_asset) then raise exception 'Digital access denied';end if;
 perform pg_advisory_xact_lock(hashtextextended('digital-delivery:'||caller::text,0));
 if (select count(*) from public.digital_delivery_audit where buyer_id=caller and created_at>now()-interval '1 hour')>=30 then raise exception 'Download limit reached';end if;
 select * into asset from public.digital_private_assets where id=p_asset and scan_status='approved' for share;
 perform id from public.digital_entitlements where asset_id=p_asset and buyer_id=caller and revoked_at is null for share;
 if asset.id is null or not found or not public.digital_download_eligible(p_asset) then raise exception 'Digital access denied';end if;
 insert into public.digital_delivery_audit(buyer_id,asset_id) values(caller,p_asset);return asset.path;
end $$;
revoke all on function public.digital_delivery_catalogue(),public.digital_authorize_delivery(uuid) from public,anon,authenticated,service_role;
grant execute on function public.digital_delivery_catalogue(),public.digital_authorize_delivery(uuid) to authenticated;
commit;
