-- REVIEW ONLY. Protects new user/folder uploads; preserves legacy public reads.
-- Existing bucket configuration and legacy paths are NOT rewritten.
begin;
create function public.zammarket_photo_unreferenced(p_path text) returns boolean
language sql stable security definer set search_path = '' as $$
  select not exists(select 1 from public.listings where p_path = any(image_paths));
$$;
revoke all on function public.zammarket_photo_unreferenced(text) from public,anon;
grant execute on function public.zammarket_photo_unreferenced(text) to authenticated;

create policy zammarket_image_owner_read on storage.objects
  for select to authenticated using(bucket_id='listing-images'
    and (storage.foldername(name))[1]=(select auth.uid())::text);

create policy zammarket_image_upload_guard on storage.objects as restrictive
  for insert to authenticated with check (bucket_id <> 'listing-images' or
    ((storage.foldername(name))[1]=(select auth.uid())::text and name not like '%..%'));
create policy zammarket_image_upload on storage.objects
  for insert to authenticated with check (bucket_id='listing-images'
    and (storage.foldername(name))[1]=(select auth.uid())::text and name not like '%..%');
-- Disallow overwriting listing files, including files pending cleanup.
create policy zammarket_image_update_guard on storage.objects as restrictive
  for update to authenticated using(bucket_id <> 'listing-images')
  with check(bucket_id <> 'listing-images');
create policy zammarket_image_delete_guard on storage.objects as restrictive
  for delete to authenticated using(bucket_id <> 'listing-images' or
    ((storage.foldername(name))[1]=(select auth.uid())::text
      and public.zammarket_photo_unreferenced(name)));
create policy zammarket_image_delete_unused on storage.objects
  for delete to authenticated using(bucket_id='listing-images'
    and (storage.foldername(name))[1]=(select auth.uid())::text
    and public.zammarket_photo_unreferenced(name));

alter table public.likes enable row level security;
revoke all on public.likes from public,anon,authenticated;
grant select on public.likes to anon,authenticated;
grant insert(listing_id,user_id),delete on public.likes to authenticated;
create policy zammarket_likes_read on public.likes for select to anon,authenticated using(true);
create policy zammarket_likes_insert_guard on public.likes as restrictive for insert to authenticated
  with check(user_id=(select auth.uid()));
create policy zammarket_likes_insert on public.likes for insert to authenticated
  with check(user_id=(select auth.uid()));
create policy zammarket_likes_delete_guard on public.likes as restrictive for delete to authenticated
  using(user_id=(select auth.uid()));
create policy zammarket_likes_delete on public.likes for delete to authenticated
  using(user_id=(select auth.uid()));
commit;
