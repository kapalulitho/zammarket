-- ZAMMARKET: SOLD LISTINGS AND PUBLIC SALES HISTORY
-- REVIEW ONLY. DO NOT RUN IN PRODUCTION.
--
-- Purpose:
-- 1. Keep sold listings in the database.
-- 2. Provide a separate public view of sold listings.
-- 3. Calculate the seven-day archive milestone.
-- 4. Never delete listing records or photos.
--
-- The seller's existing My Listings page remains the private management area.
-- Buyer identities, conversations and payment records are not exposed here.

begin;

-- Efficiently retrieve a seller's public sold history.
create index if not exists
  zammarket_sold_history_owner_date
on public.listings (user_id, sold_at desc)
where status = 'sold'
  and deleted_at is null
  and sold_at is not null;

-- Public sold history contains only listing information.
-- Storage paths and private transaction information are deliberately excluded.
create or replace view public.marketplace_sold_history
with (security_invoker = true)
as
select
  l.id,
  l.user_id,
  l.title,
  l.description,
  l.price,
  l.category,
  l.location,
  l.image_url,
  l.image_urls,
  l.created_at,
  l.sold_at,

  -- The listing reaches its archive milestone seven days after sale.
  l.sold_at + interval '7 days' as archived_at,

  -- This is calculated dynamically; no deletion or scheduled job is needed.
  (now() >= l.sold_at + interval '7 days') as is_archived

from public.listings l
where
  l.status = 'sold'
  and l.sold_at is not null
  and l.deleted_at is null;

-- Apply explicit view permissions.
revoke all on public.marketplace_sold_history
from public, anon, authenticated;

grant select on public.marketplace_sold_history
to anon, authenticated;

comment on view public.marketplace_sold_history is
  'Public sold listing history. Seven-day archive milestone is calculated dynamically. Listing records and photos are not deleted.';

commit;