-- READ ONLY. Replace the email locally in the SQL Editor; do not share it in chat.
begin read only;
select id as account_user_id, email_confirmed_at is not null as email_verified,
  last_sign_in_at
from auth.users where lower(email) = lower('REPLACE_WITH_YOUR_SIGN_IN_EMAIL');

-- Exact listing IDs are needed; titles alone must not identify rows for repair.
select id, title, user_id, seller_id, status,
  cardinality(image_urls) as photo_count,
  image_url is not null as has_legacy_single_photo
from public.listings
where lower(trim(title)) in ('watch','hotel','smartphone','exercise books')
order by lower(trim(title)),id;
rollback;
