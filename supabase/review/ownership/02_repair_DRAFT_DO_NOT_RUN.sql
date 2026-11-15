-- PROPOSAL ONLY. Requires separate approval after account and listing verification.
-- Replace every placeholder. Never use a blanket UPDATE WHERE user_id IS NULL.
-- This script changes only user_id and seller_id on four explicitly selected rows.
begin;
do $$
declare
  account_id uuid := 'REPLACE_WITH_VERIFIED_ACCOUNT_UUID'::uuid;
  account_email text := 'REPLACE_WITH_YOUR_SIGN_IN_EMAIL';
  targets jsonb := '[
    {"id":"REPLACE_WITH_WATCH_UUID","title":"watch"},
    {"id":"REPLACE_WITH_HOTEL_UUID","title":"hotel"},
    {"id":"REPLACE_WITH_SMARTPHONE_UUID","title":"smartphone"},
    {"id":"REPLACE_WITH_EXERCISE_BOOKS_UUID","title":"exercise books"}
  ]';
  target_ids uuid[];
  before_rows jsonb;
  changed integer;
begin
  if not exists(select 1 from auth.users where id=account_id
    and lower(email)=lower(account_email) and email_confirmed_at is not null) then
    raise exception 'Account UUID, email, and verified sign-in must match';
  end if;
  select array_agg((t->>'id')::uuid) into target_ids from jsonb_array_elements(targets) t;
  if cardinality(target_ids)<>4 or (select count(distinct id) from unnest(target_ids) id)<>4 then
    raise exception 'Exactly four distinct listing IDs are required';
  end if;
  perform 1 from public.listings where id=any(target_ids) order by id for update;
  if (select count(*) from public.listings where id=any(target_ids))<>4
    or exists(select 1 from jsonb_array_elements(targets) t join public.listings l
      on l.id=(t->>'id')::uuid where lower(trim(l.title))<>t->>'title'
      or l.user_id is not null or l.seller_id is not null) then
    raise exception 'Listings missing, titles changed, or ownership already assigned. Stop and review.';
  end if;
  select jsonb_agg(to_jsonb(l) order by l.id) into before_rows
    from public.listings l where id=any(target_ids);
  update public.listings set user_id=account_id,seller_id=account_id
    where id=any(target_ids) and user_id is null and seller_id is null;
  get diagnostics changed = row_count;
  if changed<>4 then raise exception 'Expected exactly four updated listings'; end if;
  if exists(select 1 from jsonb_array_elements(before_rows) b join public.listings l
    on l.id=(b->>'id')::uuid where
      (to_jsonb(l)-'user_id'-'seller_id') is distinct from (b-'user_id'-'seller_id')
      or l.user_id is distinct from account_id or l.seller_id is distinct from account_id) then
    raise exception 'Unexpected changes detected; entire transaction aborted';
  end if;
  raise notice 'Verified: only ownership changed on exactly four listings. Photos and all other fields preserved.';
end $$;
commit;
