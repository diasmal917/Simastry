create extension if not exists pg_trgm with schema extensions;

create table if not exists public.public_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique,
  display_name text,
  avatar_url text,
  avatar_path text,
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
    username is null or (username = lower(username) and username ~ '^[a-z0-9._]{3,24}$')
  ),
  constraint public_profiles_ice_breakers_count check (cardinality(ice_breakers) <= 8),
  constraint public_profiles_sun_sign_valid check (
    sun_sign is null or sun_sign = any (array[
      'aries','taurus','gemini','cancer','leo','virgo',
      'libra','scorpio','sagittarius','capricorn','aquarius','pisces'
    ])
  ),
  constraint public_profiles_moon_sign_valid check (
    moon_sign is null or moon_sign = any (array[
      'aries','taurus','gemini','cancer','leo','virgo',
      'libra','scorpio','sagittarius','capricorn','aquarius','pisces'
    ])
  ),
  constraint public_profiles_rising_sign_valid check (
    rising_sign is null or rising_sign = any (array[
      'aries','taurus','gemini','cancer','leo','virgo',
      'libra','scorpio','sagittarius','capricorn','aquarius','pisces'
    ])
  )
);

create table if not exists public.user_connections (
  owner_id uuid not null references auth.users(id) on delete cascade,
  profile_id uuid not null references public.public_profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (owner_id, profile_id),
  constraint user_connections_no_self check (owner_id <> profile_id)
);

create unique index if not exists public_profiles_username_lower_unique_idx
  on public.public_profiles (lower(username))
  where username is not null;

create index if not exists public_profiles_discoverable_username_prefix_idx
  on public.public_profiles (username text_pattern_ops)
  where is_discoverable = true and username is not null;

create index if not exists public_profiles_display_name_trgm_idx
  on public.public_profiles using gin (display_name gin_trgm_ops)
  where is_discoverable = true and display_name is not null;

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

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update set public = true;
