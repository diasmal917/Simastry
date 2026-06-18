create extension if not exists pg_trgm with schema extensions;

create table if not exists public.public_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique,
  display_name text,
  avatar_url text,
  bio text,
  sun_sign text,
  moon_sign text,
  rising_sign text,
  communication_hint text,
  ice_breakers text[] not null default '{}',
  is_discoverable boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint public_profiles_username_format check (
    username is null or username ~ '^[a-z0-9._]{3,24}$'
  )
);

create table if not exists public.user_connections (
  owner_id uuid not null references auth.users(id) on delete cascade,
  profile_id uuid not null references public.public_profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (owner_id, profile_id),
  constraint user_connections_no_self check (owner_id <> profile_id)
);

create unique index if not exists public_profiles_username_lower_idx
  on public.public_profiles (lower(username))
  where username is not null;

create index if not exists public_profiles_username_prefix_idx
  on public.public_profiles (username text_pattern_ops)
  where is_discoverable = true and username is not null;

create index if not exists public_profiles_username_trgm_idx
  on public.public_profiles using gin (username gin_trgm_ops)
  where is_discoverable = true and username is not null;

create index if not exists user_connections_owner_id_idx
  on public.user_connections (owner_id);

create index if not exists user_connections_profile_id_idx
  on public.user_connections (profile_id);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists public_profiles_set_updated_at on public.public_profiles;
create trigger public_profiles_set_updated_at
before update on public.public_profiles
for each row execute function public.set_updated_at();

alter table public.public_profiles enable row level security;
alter table public.user_connections enable row level security;

drop policy if exists "owner can read own public profile" on public.public_profiles;
create policy "owner can read own public profile"
on public.public_profiles for select
to authenticated
using (auth.uid() = id);

drop policy if exists "authenticated can read discoverable public profiles" on public.public_profiles;
create policy "authenticated can read discoverable public profiles"
on public.public_profiles for select
to authenticated
using (is_discoverable = true and username is not null);

drop policy if exists "owner can insert own public profile" on public.public_profiles;
create policy "owner can insert own public profile"
on public.public_profiles for insert
to authenticated
with check (auth.uid() = id);

drop policy if exists "owner can update own public profile" on public.public_profiles;
create policy "owner can update own public profile"
on public.public_profiles for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists "owner can read own connections" on public.user_connections;
create policy "owner can read own connections"
on public.user_connections for select
to authenticated
using (auth.uid() = owner_id);

drop policy if exists "owner can add discoverable connections" on public.user_connections;
create policy "owner can add discoverable connections"
on public.user_connections for insert
to authenticated
with check (
  auth.uid() = owner_id
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
using (auth.uid() = owner_id);

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update set public = true;

drop policy if exists "avatars are public read" on storage.objects;
create policy "avatars are public read"
on storage.objects for select
using (bucket_id = 'avatars');

drop policy if exists "users upload own avatars" on storage.objects;
create policy "users upload own avatars"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "users update own avatars" on storage.objects;
create policy "users update own avatars"
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

drop policy if exists "users delete own avatars" on storage.objects;
create policy "users delete own avatars"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);
