-- Private source-of-truth for a user's natal chart. Existing sign columns on
-- `profiles` remain compatibility caches; this row carries the provenance and
-- uncertainty required to interpret those caches honestly.
create table if not exists public.user_birth_charts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  birth_date date not null,
  birth_time time without time zone,
  birth_time_precision text not null,
  birth_time_uncertainty_minutes integer,
  birth_place text not null,
  time_zone_identifier text not null,
  latitude double precision not null,
  longitude double precision not null,
  sun_estimate jsonb not null,
  moon_estimate jsonb not null,
  rising_estimate jsonb,
  house_cusps double precision[],
  calculation_version text not null,
  provenance text not null default 'calculated',
  confirmed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint user_birth_charts_birth_time_precision
    check (birth_time_precision in ('exact', 'approximate', 'unknown')),
  constraint user_birth_charts_birth_time_consistency
    check (
      (birth_time_precision = 'unknown'
        and birth_time is null
        and birth_time_uncertainty_minutes is null
        and rising_estimate is null
        and house_cusps is null)
      or
      (birth_time_precision = 'exact'
        and birth_time is not null
        and birth_time_uncertainty_minutes is null)
      or
      (birth_time_precision = 'approximate'
        and birth_time is not null
        and birth_time_uncertainty_minutes between 1 and 720
        and house_cusps is null)
    ),
  constraint user_birth_charts_birth_place_length
    check (length(trim(birth_place)) between 1 and 240),
  constraint user_birth_charts_time_zone_length
    check (length(trim(time_zone_identifier)) between 1 and 100),
  constraint user_birth_charts_latitude_range
    check (latitude between -90 and 90),
  constraint user_birth_charts_longitude_range
    check (longitude between -180 and 180),
  constraint user_birth_charts_sun_estimate_object
    check (jsonb_typeof(sun_estimate) = 'object'),
  constraint user_birth_charts_moon_estimate_object
    check (jsonb_typeof(moon_estimate) = 'object'),
  constraint user_birth_charts_rising_estimate_object
    check (rising_estimate is null or jsonb_typeof(rising_estimate) = 'object'),
  constraint user_birth_charts_house_count
    check (house_cusps is null or cardinality(house_cusps) = 12),
  constraint user_birth_charts_calculation_version_length
    check (length(trim(calculation_version)) between 1 and 120),
  constraint user_birth_charts_provenance
    check (provenance in ('calculated', 'user_confirmed', 'previously_saved', 'general_lens'))
);

comment on table public.user_birth_charts is
  'Private owner-scoped natal calculation provenance. Profile sign columns are compatibility caches only.';
comment on column public.user_birth_charts.birth_time is
  'Local wall-clock time at the birthplace; always NULL when precision is unknown.';
comment on column public.user_birth_charts.sun_estimate is
  'Calculated possible signs, sampled longitudes, and sampled UTC interval.';
comment on column public.user_birth_charts.moon_estimate is
  'Calculated possible signs, sampled longitudes, and sampled UTC interval.';
comment on column public.user_birth_charts.rising_estimate is
  'NULL for unknown time; can contain multiple possible signs for approximate time.';

create or replace function public.user_birth_charts_set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_user_birth_charts_updated_at
  on public.user_birth_charts;
create trigger set_user_birth_charts_updated_at
before update on public.user_birth_charts
for each row execute function public.user_birth_charts_set_updated_at();

-- Trigger functions do not need to be callable through the Data API.
revoke all on function public.user_birth_charts_set_updated_at()
  from public, anon, authenticated;

alter table public.user_birth_charts enable row level security;

-- Supabase projects created after April 2026 do not automatically expose new
-- public tables to the Data API. Grant only the signed-in role; anon receives
-- no table privilege and RLS still restricts every operation to its owner.
revoke all on table public.user_birth_charts from public, anon, authenticated;
grant select, insert, update, delete on table public.user_birth_charts to authenticated;

drop policy if exists "Users can view their own birth chart" on public.user_birth_charts;
create policy "Users can view their own birth chart"
on public.user_birth_charts
for select
to authenticated
using ((select auth.uid()) is not null and (select auth.uid()) = user_id);

drop policy if exists "Users can insert their own birth chart" on public.user_birth_charts;
create policy "Users can insert their own birth chart"
on public.user_birth_charts
for insert
to authenticated
with check ((select auth.uid()) is not null and (select auth.uid()) = user_id);

drop policy if exists "Users can update their own birth chart" on public.user_birth_charts;
create policy "Users can update their own birth chart"
on public.user_birth_charts
for update
to authenticated
using ((select auth.uid()) is not null and (select auth.uid()) = user_id)
with check ((select auth.uid()) is not null and (select auth.uid()) = user_id);

drop policy if exists "Users can delete their own birth chart" on public.user_birth_charts;
create policy "Users can delete their own birth chart"
on public.user_birth_charts
for delete
to authenticated
using ((select auth.uid()) is not null and (select auth.uid()) = user_id);
