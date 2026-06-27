revoke all on table public.public_profiles from anon;
revoke all on table public.user_connections from anon;

grant select, insert, update on table public.public_profiles to authenticated;
grant select, insert, delete on table public.user_connections to authenticated;

drop policy if exists "avatars are public read" on storage.objects;
drop policy if exists "users upload own avatars" on storage.objects;
drop policy if exists "users update own avatars" on storage.objects;
drop policy if exists "users delete own avatars" on storage.objects;

drop policy if exists "Avatar owners can select own files" on storage.objects;
create policy "Avatar owners can select own files"
on storage.objects for select
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Avatar owners can upload own files" on storage.objects;
create policy "Avatar owners can upload own files"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Avatar owners can update own files" on storage.objects;
create policy "Avatar owners can update own files"
on storage.objects for update
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Avatar owners can delete own files" on storage.objects;
create policy "Avatar owners can delete own files"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);
