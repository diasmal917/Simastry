create table if not exists public.ai_usage_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  feature text not null,
  model text not null default 'unknown',
  status text not null default 'reserved',
  request_max_tokens integer not null default 0 check (request_max_tokens >= 0),
  input_tokens integer not null default 0 check (input_tokens >= 0),
  output_tokens integer not null default 0 check (output_tokens >= 0),
  total_tokens integer not null default 0 check (total_tokens >= 0),
  estimated_micro_usd bigint not null default 0 check (estimated_micro_usd >= 0),
  error_type text,
  reserved_at timestamptz not null default now(),
  finalized_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.ai_usage_events
  add column if not exists device_id text,
  add column if not exists kind text,
  add column if not exists specialist_id text,
  add column if not exists mode text,
  add column if not exists request_characters integer not null default 0 check (request_characters >= 0),
  add column if not exists response_characters integer not null default 0 check (response_characters >= 0),
  add column if not exists error_code text,
  add column if not exists metadata jsonb not null default '{}'::jsonb,
  add column if not exists updated_at timestamptz not null default now();

alter table public.ai_usage_events
  alter column model set default 'unknown',
  alter column status set default 'reserved',
  alter column request_max_tokens set default 0,
  alter column input_tokens set default 0,
  alter column output_tokens set default 0,
  alter column total_tokens set default 0,
  alter column estimated_micro_usd set default 0,
  alter column request_characters set default 0,
  alter column response_characters set default 0,
  alter column metadata set default '{}'::jsonb,
  alter column updated_at set default now();

alter table public.ai_usage_events
  drop constraint if exists ai_usage_events_feature_check,
  drop constraint if exists ai_usage_events_status_check;

alter table public.ai_usage_events
  add constraint ai_usage_events_feature_check
  check (
    feature = any (
      array[
        'panel_chat',
        'companion_chat',
        'prediction',
        'practice',
        'playbook',
        'moment_comment',
        'daily_decision',
        'expert_astrologer',
        'unknown'
      ]::text[]
    )
  ),
  add constraint ai_usage_events_status_check
  check (
    status = any (
      array[
        'reserved',
        'success',
        'failed',
        'rate_limited'
      ]::text[]
    )
  );

create table if not exists public.wallet_lookup_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id text,
  public_address text,
  public_address_hash text,
  chain text,
  status text not null check (status in ('started', 'completed', 'failed', 'limited')),
  total_zodiacs integer not null default 0 check (total_zodiacs >= 0),
  error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.wallet_lookup_events
  add column if not exists public_address_hash text,
  alter column public_address drop not null;

create index if not exists ai_usage_events_user_created_idx
  on public.ai_usage_events(user_id, created_at desc);

create index if not exists ai_usage_events_device_created_idx
  on public.ai_usage_events(device_id, created_at desc)
  where device_id is not null;

create index if not exists wallet_lookup_events_user_created_idx
  on public.wallet_lookup_events(user_id, created_at desc);

create index if not exists wallet_lookup_events_device_created_idx
  on public.wallet_lookup_events(device_id, created_at desc)
  where device_id is not null;

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

drop trigger if exists set_ai_usage_events_updated_at on public.ai_usage_events;
create trigger set_ai_usage_events_updated_at
before update on public.ai_usage_events
for each row execute function public.expert_astrologers_set_updated_at();

drop trigger if exists set_wallet_lookup_events_updated_at on public.wallet_lookup_events;
create trigger set_wallet_lookup_events_updated_at
before update on public.wallet_lookup_events
for each row execute function public.expert_astrologers_set_updated_at();

alter table public.ai_usage_events enable row level security;
alter table public.wallet_lookup_events enable row level security;

grant select on public.ai_usage_events to authenticated;
grant select on public.wallet_lookup_events to authenticated;

drop policy if exists "Users can view their AI usage events" on public.ai_usage_events;
create policy "Users can view their AI usage events"
on public.ai_usage_events
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users can view their wallet lookup events" on public.wallet_lookup_events;
create policy "Users can view their wallet lookup events"
on public.wallet_lookup_events
for select
to authenticated
using ((select auth.uid()) = user_id);
