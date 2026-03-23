create extension if not exists pgcrypto;

create or replace function public.set_current_timestamp_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.social_profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null check (char_length(trim(display_name)) between 1 and 32),
  sun_sign text not null,
  moon_sign text,
  rising_sign text,
  bio text check (bio is null or char_length(trim(bio)) <= 150),
  social_links jsonb,
  is_visible boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.discovery_messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users (id) on delete cascade,
  recipient_id uuid not null references auth.users (id) on delete cascade,
  sender_display_name text not null check (char_length(trim(sender_display_name)) between 1 and 32),
  sender_sun_sign text not null,
  sender_moon_sign text,
  sender_rising_sign text,
  recipient_display_name text not null check (char_length(trim(recipient_display_name)) between 1 and 32),
  recipient_sun_sign text not null,
  recipient_moon_sign text,
  recipient_rising_sign text,
  content text not null check (char_length(trim(content)) between 1 and 280),
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  constraint discovery_messages_no_self_send check (sender_id <> recipient_id)
);

alter table public.discovery_messages
  add column if not exists recipient_display_name text;

alter table public.discovery_messages
  add column if not exists recipient_sun_sign text;

alter table public.discovery_messages
  add column if not exists recipient_moon_sign text;

alter table public.discovery_messages
  add column if not exists recipient_rising_sign text;

create table if not exists public.discovery_blocks (
  blocker_id uuid not null references auth.users (id) on delete cascade,
  blocked_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint discovery_blocks_no_self_block check (blocker_id <> blocked_id)
);

create table if not exists public.discovery_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users (id) on delete cascade,
  reported_id uuid not null references auth.users (id) on delete cascade,
  reason text not null,
  details text,
  created_at timestamptz not null default now(),
  constraint discovery_reports_no_self_report check (reporter_id <> reported_id)
);

create index if not exists social_profiles_visible_idx
  on public.social_profiles (is_visible, created_at desc);

create index if not exists discovery_messages_recipient_idx
  on public.discovery_messages (recipient_id, created_at desc);

create index if not exists discovery_messages_sender_idx
  on public.discovery_messages (sender_id, created_at desc);

create index if not exists discovery_reports_reported_idx
  on public.discovery_reports (reported_id, created_at desc);

drop trigger if exists set_social_profiles_updated_at on public.social_profiles;
create trigger set_social_profiles_updated_at
before update on public.social_profiles
for each row
execute function public.set_current_timestamp_updated_at();

alter table public.social_profiles enable row level security;
alter table public.discovery_messages enable row level security;
alter table public.discovery_blocks enable row level security;
alter table public.discovery_reports enable row level security;

drop policy if exists "social_profiles_select_visible_or_own" on public.social_profiles;
create policy "social_profiles_select_visible_or_own"
on public.social_profiles
for select
using (auth.uid() = id or is_visible = true);

drop policy if exists "social_profiles_insert_own" on public.social_profiles;
create policy "social_profiles_insert_own"
on public.social_profiles
for insert
with check (auth.uid() = id);

drop policy if exists "social_profiles_update_own" on public.social_profiles;
create policy "social_profiles_update_own"
on public.social_profiles
for update
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists "social_profiles_delete_own" on public.social_profiles;
create policy "social_profiles_delete_own"
on public.social_profiles
for delete
using (auth.uid() = id);

drop policy if exists "discovery_messages_select_participant" on public.discovery_messages;
create policy "discovery_messages_select_participant"
on public.discovery_messages
for select
using (auth.uid() = sender_id or auth.uid() = recipient_id);

drop policy if exists "discovery_messages_insert_sender" on public.discovery_messages;
create policy "discovery_messages_insert_sender"
on public.discovery_messages
for insert
with check (auth.uid() = sender_id);

drop policy if exists "discovery_messages_update_recipient" on public.discovery_messages;
create policy "discovery_messages_update_recipient"
on public.discovery_messages
for update
using (auth.uid() = recipient_id)
with check (auth.uid() = recipient_id);

drop policy if exists "discovery_messages_delete_participant" on public.discovery_messages;
create policy "discovery_messages_delete_participant"
on public.discovery_messages
for delete
using (auth.uid() = sender_id or auth.uid() = recipient_id);

drop policy if exists "discovery_blocks_select_participant" on public.discovery_blocks;
create policy "discovery_blocks_select_participant"
on public.discovery_blocks
for select
using (auth.uid() = blocker_id or auth.uid() = blocked_id);

drop policy if exists "discovery_blocks_insert_blocker" on public.discovery_blocks;
create policy "discovery_blocks_insert_blocker"
on public.discovery_blocks
for insert
with check (auth.uid() = blocker_id);

drop policy if exists "discovery_blocks_delete_blocker" on public.discovery_blocks;
create policy "discovery_blocks_delete_blocker"
on public.discovery_blocks
for delete
using (auth.uid() = blocker_id);

drop policy if exists "discovery_reports_insert_reporter" on public.discovery_reports;
create policy "discovery_reports_insert_reporter"
on public.discovery_reports
for insert
with check (auth.uid() = reporter_id);

comment on table public.social_profiles is 'Public discovery profiles that users opt into.';
comment on table public.discovery_messages is 'Intro messages exchanged between discoverable users.';
comment on table public.discovery_blocks is 'Discovery safety blocks between users.';
comment on table public.discovery_reports is 'Safety reports submitted from discovery.';
