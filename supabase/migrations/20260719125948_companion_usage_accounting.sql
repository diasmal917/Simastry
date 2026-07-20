-- Durable, privacy-minimized accounting for the server-owned companion
-- runtimes. The RPC signatures deliberately accept provenance and numeric
-- counts only; there is no parameter through which Decode text or prompts can
-- be persisted.

alter table public.ai_usage_events
  add column if not exists persona_id text,
  add column if not exists persona_version text,
  add column if not exists model_provider text,
  add column if not exists token_source text not null default 'unavailable',
  add column if not exists request_key uuid,
  add column if not exists attempt_number integer not null default 1
    check (attempt_number > 0);

alter table public.companion_messages
  add column if not exists usage_event_id uuid,
  add column if not exists request_fingerprint text,
  add column if not exists request_fingerprint_key_id text;

alter table public.companion_messages
  drop constraint if exists companion_messages_request_fingerprint_check;
alter table public.companion_messages
  add constraint companion_messages_request_fingerprint_check
  check (
    (
      request_fingerprint is null
      and request_fingerprint_key_id is null
    )
    or (
      role = 'user'
      and request_fingerprint ~ '^[0-9a-f]{64}$'
      and request_fingerprint_key_id ~ '^[a-z0-9][a-z0-9._-]{0,31}$'
    )
  );

alter table public.companion_messages
  drop constraint if exists companion_messages_usage_event_role_check;
alter table public.companion_messages
  add constraint companion_messages_usage_event_role_check
  check (
    usage_event_id is null
    or (role = 'companion' and delivery_state = 'complete')
  );

create unique index if not exists ai_usage_events_owner_identity_idx
  on public.ai_usage_events(id, user_id);

alter table public.companion_messages
  drop constraint if exists companion_messages_usage_event_owner_fk;
alter table public.companion_messages
  add constraint companion_messages_usage_event_owner_fk
  foreign key (usage_event_id, user_id)
  references public.ai_usage_events(id, user_id)
  on delete set null (usage_event_id);

create index if not exists companion_messages_usage_event_idx
  on public.companion_messages(usage_event_id)
  where usage_event_id is not null;

comment on column public.companion_messages.usage_event_id is
  'Durable owner-matched AI usage provenance for a generated companion response; NULL for user and legacy messages.';
comment on column public.companion_messages.request_fingerprint is
  'Server-keyed HMAC of the original logical Chat request for privacy-safe idempotency conflict detection; never raw content.';
comment on column public.companion_messages.request_fingerprint_key_id is
  'Non-secret identifier for the server HMAC key version used by request_fingerprint.';

create or replace function public.finalize_companion_message_usage()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_accounting jsonb;
  v_provider_usage jsonb;
  v_token_source text;
  v_input_tokens integer := 0;
  v_output_tokens integer := 0;
  v_response_characters integer;
  v_updated_id uuid;
begin
  if new.usage_event_id is null then
    return new;
  end if;

  v_accounting := new.safety_metadata -> 'usage_accounting';
  if jsonb_typeof(v_accounting) <> 'object'
     or coalesce(v_accounting ->> 'response_characters', '')
       !~ '^[0-9]{1,7}$' then
    raise exception using
      errcode = '23514',
      message = 'companion response usage accounting is required';
  end if;
  v_response_characters := (v_accounting ->> 'response_characters')::integer;
  if v_response_characters > 1000000 then
    raise exception using
      errcode = '23514',
      message = 'invalid companion response character count';
  end if;

  v_token_source := v_accounting ->> 'token_source';
  if v_token_source = 'provider' then
    v_provider_usage := new.safety_metadata -> 'provider_usage';
    if jsonb_typeof(v_provider_usage) <> 'object'
       or coalesce(v_provider_usage ->> 'input_tokens', '')
         !~ '^[0-9]{1,7}$'
       or coalesce(v_provider_usage ->> 'output_tokens', '')
         !~ '^[0-9]{1,7}$' then
      raise exception using
        errcode = '23514',
        message = 'provider token accounting is required';
    end if;
    v_input_tokens := (v_provider_usage ->> 'input_tokens')::integer;
    v_output_tokens := (v_provider_usage ->> 'output_tokens')::integer;
    if v_input_tokens > 1000000 or v_output_tokens > 1000000 then
      raise exception using
        errcode = '23514',
        message = 'invalid provider token accounting';
    end if;
  elsif v_token_source is null
     or v_token_source not in ('deterministic', 'unavailable') then
    raise exception using
      errcode = '23514',
      message = 'invalid companion token source';
  end if;

  update public.ai_usage_events as event
     set status = 'success',
         model_provider = new.model_provider,
         model = new.model_version,
         input_tokens = v_input_tokens,
         output_tokens = v_output_tokens,
         total_tokens = v_input_tokens + v_output_tokens,
         response_characters = v_response_characters,
         token_source = v_token_source,
         error_code = null,
         error_type = null,
         finalized_at = clock_timestamp(),
         updated_at = clock_timestamp()
   where event.id = new.usage_event_id
     and event.user_id = new.user_id
     and event.feature = 'companion_chat'
     and event.request_key = new.client_message_id
     and event.persona_id = new.companion_id
     and event.persona_version = new.persona_version
     and event.status = 'reserved'
  returning event.id into v_updated_id;

  if v_updated_id is null then
    raise exception using
      errcode = '23514',
      message = 'companion response usage reservation mismatch';
  end if;
  return new;
end;
$$;

drop trigger if exists finalize_companion_message_usage
  on public.companion_messages;
create trigger finalize_companion_message_usage
after insert on public.companion_messages
for each row execute function public.finalize_companion_message_usage();

comment on function public.finalize_companion_message_usage() is
  'Atomically finalizes an owner-, persona-, and request-matched Chat usage reservation when its durable companion response is inserted.';

revoke all on function public.finalize_companion_message_usage()
  from public, anon, authenticated, service_role;

alter table public.ai_usage_events
  drop constraint if exists ai_usage_events_feature_check;

alter table public.ai_usage_events
  add constraint ai_usage_events_feature_check
  check (
    feature = any (
      array[
        'panel_chat',
        'companion_chat',
        'companion_decode',
        'prediction',
        'practice',
        'playbook',
        'moment_comment',
        'daily_decision',
        'expert_astrologer',
        'conversation_rehearsal',
        'unknown'
      ]::text[]
    )
  );

alter table public.ai_usage_events
  drop constraint if exists ai_usage_events_token_source_check;

alter table public.ai_usage_events
  add constraint ai_usage_events_token_source_check
  check (
    token_source = any (
      array[
        'pending',
        'provider',
        'deterministic',
        'unavailable',
        'not_applicable'
      ]::text[]
    )
  );

create unique index if not exists ai_usage_events_companion_request_key_idx
  on public.ai_usage_events(user_id, feature, request_key, attempt_number)
  where request_key is not null;

create index if not exists ai_usage_events_companion_window_idx
  on public.ai_usage_events(user_id, feature, reserved_at desc)
  where status in ('reserved', 'success', 'failed');

create or replace function public.reserve_companion_ai_usage(
  p_user_id uuid,
  p_feature text,
  p_persona_id text,
  p_persona_version text,
  p_model_provider text,
  p_model text,
  p_request_max_tokens integer,
  p_request_characters integer,
  p_request_key uuid,
  p_per_minute_limit integer,
  p_per_day_limit integer
)
returns table (
  usage_event_id uuid,
  allowed boolean,
  limit_label text
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_now timestamptz;
  v_existing public.ai_usage_events%rowtype;
  v_event_id uuid;
  v_limit_label text;
  v_status text;
  v_attempt_number integer := 1;
begin
  if p_user_id is null then
    raise exception using errcode = '22023', message = 'user_id is required';
  end if;
  if p_feature is null
     or p_feature not in ('companion_chat', 'companion_decode') then
    raise exception using errcode = '22023', message = 'unsupported companion feature';
  end if;
  if p_feature = 'companion_chat' and p_request_key is null then
    raise exception using errcode = '22023', message = 'chat request_key is required';
  end if;
  if p_feature = 'companion_decode' and p_request_key is not null then
    raise exception using errcode = '22023', message = 'Decode request_key must be null';
  end if;
  if p_persona_id is null
     or length(p_persona_id) not between 3 and 80
     or p_persona_id !~ '^[a-z][a-z0-9]*(-[a-z0-9]+)+$' then
    raise exception using errcode = '22023', message = 'invalid persona_id';
  end if;
  if p_persona_version is null
     or length(p_persona_version) not between 1 and 120 then
    raise exception using errcode = '22023', message = 'invalid persona_version';
  end if;
  if p_model_provider is null
     or length(p_model_provider) not between 1 and 80
     or p_model_provider !~ '^[a-z0-9_-]+$' then
    raise exception using errcode = '22023', message = 'invalid model_provider';
  end if;
  if p_model is null or length(p_model) not between 1 and 160 then
    raise exception using errcode = '22023', message = 'invalid model';
  end if;
  if p_request_max_tokens is null
     or p_request_max_tokens not between 0 and 1200 then
    raise exception using errcode = '22023', message = 'invalid request_max_tokens';
  end if;
  if p_request_characters is null
     or p_request_characters not between 1 and 12000 then
    raise exception using errcode = '22023', message = 'invalid request_characters';
  end if;
  if p_per_minute_limit is null
     or p_per_minute_limit not between 1 and 100000
     or p_per_day_limit is null
     or p_per_day_limit not between 1 and 100000 then
    raise exception using errcode = '22023', message = 'invalid usage limit';
  end if;

  -- Every reservation for a user is serialized in Postgres, including calls
  -- arriving concurrently at different Edge Function isolates. Hash
  -- collisions only serialize unrelated users; they cannot weaken a limit.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_user_id::text, 774979825)
  );
  -- Lock wait time must not age a new reservation out of its own window.
  v_now := clock_timestamp();

  if p_request_key is not null then
    select event.*
      into v_existing
      from public.ai_usage_events as event
     where event.user_id = p_user_id
       and event.feature = p_feature
       and event.request_key = p_request_key
     order by event.attempt_number desc
     limit 1
     for update;

    v_attempt_number := coalesce(v_existing.attempt_number, 0) + 1;

    -- A reserved or completed chat turn is the same logical billable request,
    -- not a new event. Message-level claiming prevents concurrent generation;
    -- this branch makes the accounting layer independently idempotent.
    if v_existing.id is not null
       and v_existing.status in ('reserved', 'success') then
      return query
      select v_existing.id, true, null::text;
      return;
    end if;
  end if;

  if (
    select count(*)
      from public.ai_usage_events as event
     where event.user_id = p_user_id
       and event.feature = p_feature
       and event.status in ('reserved', 'success', 'failed')
       and event.reserved_at >= v_now - interval '1 minute'
  ) >= p_per_minute_limit then
    v_limit_label := 'per_minute';
  elsif (
    select count(*)
      from public.ai_usage_events as event
     where event.user_id = p_user_id
       and event.feature = p_feature
       and event.status in ('reserved', 'success', 'failed')
       and event.reserved_at >= v_now - interval '24 hours'
  ) >= p_per_day_limit then
    v_limit_label := 'per_day';
  end if;

  v_status := case when v_limit_label is null then 'reserved'
                   else 'rate_limited' end;

  -- A denied attempt has not invoked the provider, so it is safe to reuse its
  -- row once the window opens. A failed provider attempt is never overwritten:
  -- the next retry receives a new attempt_number and preserves prior tokens.
  if v_existing.id is not null and v_existing.status = 'rate_limited' then
    update public.ai_usage_events as event
       set persona_id = p_persona_id,
           persona_version = p_persona_version,
           model_provider = p_model_provider,
           model = p_model,
           status = v_status,
           request_max_tokens = p_request_max_tokens,
           request_characters = p_request_characters,
           response_characters = 0,
           input_tokens = 0,
           output_tokens = 0,
           total_tokens = 0,
           token_source = case when v_limit_label is null then 'pending'
                               else 'not_applicable' end,
           error_code = v_limit_label,
           error_type = case when v_limit_label is null then null
                             else 'ai_usage_limit' end,
           reserved_at = v_now,
           finalized_at = case when v_limit_label is null then null
                               else v_now end,
           metadata = jsonb_build_object(
             'accounting_version',
             'companion-usage-2026-07-19.1'
           ),
           updated_at = v_now
     where event.id = v_existing.id
     returning event.id into v_event_id;
  else
    insert into public.ai_usage_events (
      user_id,
      feature,
      kind,
      mode,
      persona_id,
      persona_version,
      model_provider,
      model,
      status,
      request_max_tokens,
      request_characters,
      token_source,
      request_key,
      attempt_number,
      error_code,
      error_type,
      reserved_at,
      finalized_at,
      metadata
    ) values (
      p_user_id,
      p_feature,
      case when p_feature = 'companion_chat' then 'message' else 'decode' end,
      case when p_feature = 'companion_chat' then 'primary_companion'
           else 'decode' end,
      p_persona_id,
      p_persona_version,
      p_model_provider,
      p_model,
      v_status,
      p_request_max_tokens,
      p_request_characters,
      case when v_limit_label is null then 'pending'
           else 'not_applicable' end,
      p_request_key,
      v_attempt_number,
      v_limit_label,
      case when v_limit_label is null then null else 'ai_usage_limit' end,
      v_now,
      case when v_limit_label is null then null else v_now end,
      jsonb_build_object(
        'accounting_version',
        'companion-usage-2026-07-19.1'
      )
    )
    returning id into v_event_id;
  end if;

  return query
  select v_event_id, v_limit_label is null, v_limit_label;
end;
$$;

create or replace function public.finalize_companion_ai_usage(
  p_user_id uuid,
  p_usage_event_id uuid,
  p_status text,
  p_model_provider text,
  p_model text,
  p_input_tokens integer,
  p_output_tokens integer,
  p_response_characters integer,
  p_token_source text,
  p_error_code text
)
returns boolean
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_updated_id uuid;
begin
  if p_user_id is null or p_usage_event_id is null then
    raise exception using errcode = '22023', message = 'usage owner and event are required';
  end if;
  if p_status is null or p_status not in ('success', 'failed') then
    raise exception using errcode = '22023', message = 'invalid final status';
  end if;
  if p_model_provider is null
     or length(p_model_provider) not between 1 and 80
     or p_model_provider !~ '^[a-z0-9_-]+$' then
    raise exception using errcode = '22023', message = 'invalid model_provider';
  end if;
  if p_model is null or length(p_model) not between 1 and 160 then
    raise exception using errcode = '22023', message = 'invalid model';
  end if;
  if p_input_tokens is null
     or p_input_tokens not between 0 and 1000000
     or p_output_tokens is null
     or p_output_tokens not between 0 and 1000000
     or p_response_characters is null
     or p_response_characters not between 0 and 1000000 then
    raise exception using errcode = '22023', message = 'invalid usage counts';
  end if;
  if p_token_source is null
     or p_token_source not in ('provider', 'deterministic', 'unavailable') then
    raise exception using errcode = '22023', message = 'invalid token_source';
  end if;
  if p_error_code is not null and length(p_error_code) > 80 then
    raise exception using errcode = '22023', message = 'invalid error_code';
  end if;

  update public.ai_usage_events as event
     set status = p_status,
         model_provider = p_model_provider,
         model = p_model,
         input_tokens = p_input_tokens,
         output_tokens = p_output_tokens,
         total_tokens = p_input_tokens + p_output_tokens,
         response_characters = p_response_characters,
         token_source = p_token_source,
         error_code = p_error_code,
         error_type = p_error_code,
         finalized_at = clock_timestamp(),
         updated_at = clock_timestamp()
   where event.id = p_usage_event_id
     and event.user_id = p_user_id
     and event.feature in ('companion_chat', 'companion_decode')
     and event.status = 'reserved'
  returning event.id into v_updated_id;

  if v_updated_id is not null then
    return true;
  end if;

  -- A repeated delivery after a lost HTTP response is harmless when the first
  -- finalization already committed with the same terminal status.
  return exists (
    select 1
      from public.ai_usage_events as event
     where event.id = p_usage_event_id
       and event.user_id = p_user_id
       and event.feature in ('companion_chat', 'companion_decode')
       and event.status = p_status
       and event.model_provider = p_model_provider
       and event.model = p_model
       and event.input_tokens = p_input_tokens
       and event.output_tokens = p_output_tokens
       and event.total_tokens = p_input_tokens + p_output_tokens
       and event.response_characters = p_response_characters
       and event.token_source = p_token_source
       and event.error_code is not distinct from p_error_code
  );
end;
$$;

comment on function public.reserve_companion_ai_usage(
  uuid, text, text, text, text, text, integer, integer, uuid, integer, integer
) is
  'Atomically enforces per-user companion limits and records PII-minimized provenance. It cannot accept raw message or prompt text.';

comment on function public.finalize_companion_ai_usage(
  uuid, uuid, text, text, text, integer, integer, integer, text, text
) is
  'Finalizes one owner-scoped companion usage reservation with model and token provenance; accepts no raw content.';

revoke all on function public.reserve_companion_ai_usage(
  uuid, text, text, text, text, text, integer, integer, uuid, integer, integer
) from public, anon, authenticated;
revoke all on function public.finalize_companion_ai_usage(
  uuid, uuid, text, text, text, integer, integer, integer, text, text
) from public, anon, authenticated;

grant execute on function public.reserve_companion_ai_usage(
  uuid, text, text, text, text, text, integer, integer, uuid, integer, integer
) to service_role;
grant execute on function public.finalize_companion_ai_usage(
  uuid, uuid, text, text, text, integer, integer, integer, text, text
) to service_role;

-- Keep elevated deletion out of the exposed API schema. The public wrapper
-- remains SECURITY INVOKER, while this narrowly scoped helper can remove rows
-- that authenticated clients must never be able to delete directly (doing so
-- would let them reset live rate windows).
create schema if not exists companion_private;
revoke all on schema companion_private
  from public, anon, authenticated, service_role;
grant usage on schema companion_private to authenticated;

create or replace function companion_private.delete_current_user_companion_usage()
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_deleted bigint;
begin
  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'authenticated user required';
  end if;

  delete from public.ai_usage_events
   where user_id = v_user_id
     and feature in ('companion_chat', 'companion_decode');
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;

comment on function companion_private.delete_current_user_companion_usage() is
  'Deletes only auth.uid()-owned Chat and Decode usage during explicit companion-data erasure. It is outside the exposed API schema.';

revoke all on function companion_private.delete_current_user_companion_usage()
  from public, anon, authenticated, service_role;
grant execute on function companion_private.delete_current_user_companion_usage()
  to authenticated;

create or replace function public.delete_current_user_companion_data()
returns table (
  companion_messages_deleted bigint,
  companion_conversations_deleted bigint,
  companion_memories_deleted bigint,
  communication_outcomes_deleted bigint,
  relationship_people_deleted bigint,
  user_companion_relationships_deleted bigint
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_messages bigint;
  v_conversations bigint;
  v_memories bigint;
  v_outcomes bigint;
  v_people bigint;
  v_relationships bigint;
begin
  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'authenticated user required';
  end if;

  -- The order is explicit even where a foreign key also cascades, so the
  -- returned counts describe exactly what this account-scoped operation did.
  delete from public.companion_messages
   where user_id = v_user_id;
  get diagnostics v_messages = row_count;

  delete from public.companion_conversations
   where user_id = v_user_id;
  get diagnostics v_conversations = row_count;

  delete from public.companion_memories
   where user_id = v_user_id;
  get diagnostics v_memories = row_count;

  delete from public.communication_outcomes
   where user_id = v_user_id;
  get diagnostics v_outcomes = row_count;

  delete from public.relationship_people
   where user_id = v_user_id;
  get diagnostics v_people = row_count;

  delete from public.user_companion_relationships
   where user_id = v_user_id;
  get diagnostics v_relationships = row_count;

  -- Usage events are intentionally omitted from the six-field API response,
  -- but are part of the same transaction and account-scoped privacy erasure.
  perform companion_private.delete_current_user_companion_usage();

  return query select
    v_messages,
    v_conversations,
    v_memories,
    v_outcomes,
    v_people,
    v_relationships;
end;
$$;

comment on function public.delete_current_user_companion_data() is
  'Atomically deletes only auth.uid()-owned companion data and Chat/Decode usage in foreign-key-safe order, returning the stable six-table count contract. The persona catalog and unrelated usage are never modified.';

revoke all on function public.delete_current_user_companion_data()
  from public, anon, service_role;
grant execute on function public.delete_current_user_companion_data()
  to authenticated;
