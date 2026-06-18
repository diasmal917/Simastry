alter table public.public_profiles
  add column if not exists social_links jsonb;

alter table public.public_profiles
  drop constraint if exists public_profiles_social_links_object;

alter table public.public_profiles
  add constraint public_profiles_social_links_object
  check (social_links is null or jsonb_typeof(social_links) = 'object');
