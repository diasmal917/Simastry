drop policy if exists "Authenticated users can view public profiles" on public.public_profiles;
drop policy if exists "Owners can insert own public profile" on public.public_profiles;
drop policy if exists "Owners can update own public profile" on public.public_profiles;

drop policy if exists "Owners can add discoverable connections" on public.user_connections;
drop policy if exists "Owners can remove own connections" on public.user_connections;
drop policy if exists "Owners can view own connections" on public.user_connections;
