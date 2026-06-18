alter function public.set_updated_at()
set search_path = public, pg_temp;

drop policy if exists "authenticated can read discoverable public profiles" on public.public_profiles;
drop policy if exists "owner can read own public profile" on public.public_profiles;
create policy "authenticated can read public profiles"
on public.public_profiles for select
to authenticated
using (
  (select auth.uid()) = id
  or (is_discoverable = true and username is not null)
);

drop policy if exists "owner can insert own public profile" on public.public_profiles;
create policy "owner can insert own public profile"
on public.public_profiles for insert
to authenticated
with check ((select auth.uid()) = id);

drop policy if exists "owner can update own public profile" on public.public_profiles;
create policy "owner can update own public profile"
on public.public_profiles for update
to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

drop policy if exists "owner can read own connections" on public.user_connections;
create policy "owner can read own connections"
on public.user_connections for select
to authenticated
using ((select auth.uid()) = owner_id);

drop policy if exists "owner can add discoverable connections" on public.user_connections;
create policy "owner can add discoverable connections"
on public.user_connections for insert
to authenticated
with check (
  (select auth.uid()) = owner_id
  and owner_id <> profile_id
  and exists (
    select 1
    from public.public_profiles profile
    where profile.id = profile_id
      and profile.is_discoverable = true
      and profile.username is not null
  )
);

drop policy if exists "owner can delete own connections" on public.user_connections;
create policy "owner can delete own connections"
on public.user_connections for delete
to authenticated
using ((select auth.uid()) = owner_id);

drop policy if exists "avatars are public read" on storage.objects;
drop policy if exists "users upload own avatars" on storage.objects;
drop policy if exists "users update own avatars" on storage.objects;
drop policy if exists "users delete own avatars" on storage.objects;

drop index if exists public.public_profiles_username_prefix_idx;
drop index if exists public.public_profiles_username_lower_idx;
