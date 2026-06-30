create table if not exists public.expert_astrology_intake (
  user_id uuid primary key references auth.users(id) on delete cascade,
  birth_date date,
  birth_time time,
  birth_time_unknown boolean not null default false,
  birth_place text,
  partner_birth_date date,
  partner_birth_time time,
  partner_birth_time_unknown boolean not null default false,
  partner_birth_place text,
  user_supplied_tradition_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint expert_astrology_intake_birth_time_consistency
    check (not birth_time_unknown or birth_time is null),
  constraint expert_astrology_intake_partner_birth_time_consistency
    check (not partner_birth_time_unknown or partner_birth_time is null),
  constraint expert_astrology_intake_birth_place_length
    check (birth_place is null or length(trim(birth_place)) <= 240),
  constraint expert_astrology_intake_partner_birth_place_length
    check (partner_birth_place is null or length(trim(partner_birth_place)) <= 240),
  constraint expert_astrology_intake_user_supplied_object
    check (jsonb_typeof(user_supplied_tradition_data) = 'object')
);

create index if not exists expert_astrology_intake_updated_idx
  on public.expert_astrology_intake(updated_at desc);

create or replace function public.expert_astrologers_set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_expert_astrology_intake_updated_at
  on public.expert_astrology_intake;
create trigger set_expert_astrology_intake_updated_at
before update on public.expert_astrology_intake
for each row execute function public.expert_astrologers_set_updated_at();

alter table public.expert_astrology_intake enable row level security;

grant select, insert, update, delete on public.expert_astrology_intake to authenticated;

drop policy if exists "Users can view their expert astrology intake" on public.expert_astrology_intake;
create policy "Users can view their expert astrology intake"
on public.expert_astrology_intake
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert their expert astrology intake" on public.expert_astrology_intake;
create policy "Users can insert their expert astrology intake"
on public.expert_astrology_intake
for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their expert astrology intake" on public.expert_astrology_intake;
create policy "Users can update their expert astrology intake"
on public.expert_astrology_intake
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their expert astrology intake" on public.expert_astrology_intake;
create policy "Users can delete their expert astrology intake"
on public.expert_astrology_intake
for delete
to authenticated
using ((select auth.uid()) = user_id);
