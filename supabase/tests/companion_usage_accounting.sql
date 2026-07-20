begin;

select plan(49);

select has_column('public', 'ai_usage_events', 'persona_id',
  'usage events record the public companion slug');
select has_column('public', 'ai_usage_events', 'persona_version',
  'usage events record the server persona version');
select has_column('public', 'ai_usage_events', 'model_provider',
  'usage events record the model provider');
select has_column('public', 'ai_usage_events', 'token_source',
  'usage events distinguish provider, deterministic, and unavailable tokens');
select has_column('public', 'ai_usage_events', 'request_key',
  'usage events support opaque chat idempotency keys');
select has_column('public', 'ai_usage_events', 'attempt_number',
  'usage events preserve each failed provider attempt');
select has_column('public', 'companion_messages', 'usage_event_id',
  'persisted companion responses link to their durable usage event');
select has_column('public', 'companion_messages', 'request_fingerprint',
  'Chat user rows can retain a non-reversible idempotency fingerprint');
select has_column('public', 'companion_messages', 'request_fingerprint_key_id',
  'Chat fingerprints identify their non-secret server key version');

select ok(
  exists (
    select 1
      from pg_constraint
     where conrelid = 'public.companion_messages'::regclass
       and conname = 'companion_messages_request_fingerprint_check'
       and pg_get_constraintdef(oid) like '%[0-9a-f]{64}%'
       and pg_get_constraintdef(oid) like '%role =%user%'
  ),
  'the database accepts only versioned lowercase HMACs on user messages'
);

select ok(
  exists (
    select 1
      from pg_constraint
     where conrelid = 'public.companion_messages'::regclass
       and conname = 'companion_messages_usage_event_role_check'
       and pg_get_constraintdef(oid) like '%role =%companion%'
       and pg_get_constraintdef(oid) like '%delivery_state =%complete%'
  ),
  'only complete companion responses may link a durable usage event'
);

select ok(
  exists (
    select 1
      from pg_constraint
     where conrelid = 'public.companion_messages'::regclass
       and conname = 'companion_messages_usage_event_owner_fk'
       and pg_get_constraintdef(oid)
         like '%FOREIGN KEY (usage_event_id, user_id) REFERENCES ai_usage_events(id, user_id)%'
  ),
  'the response-to-usage link enforces the same owner at the database boundary'
);

select ok(
  exists (
    select 1
      from pg_constraint
     where conrelid = 'public.ai_usage_events'::regclass
       and conname = 'ai_usage_events_feature_check'
       and pg_get_constraintdef(oid) like '%companion_decode%'
       and pg_get_constraintdef(oid) like '%conversation_rehearsal%'
  ),
  'the feature contract includes Decode and conversation rehearsal'
);

select ok(
  exists (
    select 1
      from pg_indexes
     where schemaname = 'public'
       and indexname = 'ai_usage_events_companion_request_key_idx'
       and indexdef like '%user_id, feature, request_key, attempt_number%'
       and indexdef like '%WHERE (request_key IS NOT NULL)%'
  ),
  'chat idempotency is unique per user, feature, key, and attempt'
);

select ok(
  exists (
    select 1
      from pg_indexes
     where schemaname = 'public'
       and indexname = 'ai_usage_events_companion_window_idx'
       and indexdef like '%failed%'
  ),
  'the durable rate window counts failed provider attempts'
);

select ok(
  exists (
    select 1
      from pg_proc procedure
      join pg_namespace namespace on namespace.oid = procedure.pronamespace
     where namespace.nspname = 'public'
       and procedure.proname = 'reserve_companion_ai_usage'
       and procedure.prosecdef = false
       and array_to_string(procedure.proconfig, ',') like '%search_path=""%'
  ),
  'the reservation RPC is SECURITY INVOKER with an empty search path'
);

select ok(
  exists (
    select 1
      from pg_proc procedure
      join pg_namespace namespace on namespace.oid = procedure.pronamespace
     where namespace.nspname = 'public'
       and procedure.proname = 'reserve_companion_ai_usage'
       and pg_get_functiondef(procedure.oid) like '%pg_advisory_xact_lock%'
  ),
  'usage reservations serialize each user across concurrent server isolates'
);

select ok(
  exists (
    select 1
      from pg_proc procedure
      join pg_namespace namespace on namespace.oid = procedure.pronamespace
     where namespace.nspname = 'public'
       and procedure.proname = 'reserve_companion_ai_usage'
       and strpos(pg_get_functiondef(procedure.oid), 'v_now := clock_timestamp()')
         > strpos(pg_get_functiondef(procedure.oid), 'pg_advisory_xact_lock')
  ),
  'rate windows capture their timestamp only after any advisory-lock wait'
);

select ok(
  exists (
    select 1
      from pg_proc procedure
      join pg_namespace namespace on namespace.oid = procedure.pronamespace
     where namespace.nspname = 'public'
       and procedure.proname = 'finalize_companion_ai_usage'
       and procedure.prosecdef = false
       and array_to_string(procedure.proconfig, ',') like '%search_path=""%'
  ),
  'the finalization RPC is SECURITY INVOKER with an empty search path'
);

select is(
  (
    select count(*)
      from information_schema.routine_privileges
     where routine_schema = 'public'
       and routine_name in (
         'reserve_companion_ai_usage',
         'finalize_companion_ai_usage'
       )
       and grantee = 'service_role'
       and privilege_type = 'EXECUTE'
  ),
  2::bigint,
  'only the server runtime receives explicit usage RPC execution grants'
);

select is(
  (
    select count(*)
      from information_schema.routine_privileges
     where routine_schema = 'public'
       and routine_name in (
         'reserve_companion_ai_usage',
         'finalize_companion_ai_usage'
       )
       and grantee in ('PUBLIC', 'anon', 'authenticated')
  ),
  0::bigint,
  'clients cannot reserve or finalize their own usage events'
);

select ok(
  not exists (
    select 1
      from information_schema.parameters
     where specific_schema = 'public'
       and specific_name like 'reserve_companion_ai_usage_%'
       and parameter_name ~ '(message|prompt|content|person_id)'
  ),
  'the reservation RPC has no raw content or People-record parameter'
);

select ok(
  exists (
    select 1
      from pg_proc procedure
      join pg_namespace namespace on namespace.oid = procedure.pronamespace
     where namespace.nspname = 'public'
       and procedure.proname = 'finalize_companion_message_usage'
       and procedure.prosecdef = false
       and array_to_string(procedure.proconfig, ',') like '%search_path=""%'
  )
  and exists (
    select 1
      from pg_trigger trigger
     where trigger.tgrelid = 'public.companion_messages'::regclass
       and trigger.tgname = 'finalize_companion_message_usage'
       and trigger.tgenabled = 'O'
       and not trigger.tgisinternal
  )
  and not exists (
    select 1
      from information_schema.routine_privileges
     where routine_schema = 'public'
       and routine_name = 'finalize_companion_message_usage'
       and grantee in ('PUBLIC', 'anon', 'authenticated', 'service_role')
  ),
  'response insertion invokes a private SECURITY INVOKER accounting trigger'
);

insert into auth.users (id, email)
values
  ('a1000000-0000-4000-8000-000000000001', 'usage-owner-one@example.invalid'),
  ('a2000000-0000-4000-8000-000000000002', 'usage-owner-two@example.invalid')
on conflict (id) do nothing;

-- Exercise the usage path under the exact production database role. Because
-- both RPCs are SECURITY INVOKER, this also verifies the underlying table
-- privileges granted by the companion runtime migration chain.
set local role service_role;

select is(
  (
    select allowed
      from public.reserve_companion_ai_usage(
        'a1000000-0000-4000-8000-000000000001',
        'companion_chat',
        'aries-amara',
        'pilot-2026-07-19.1',
        'anthropic',
        'claude-test',
        640,
        27,
        'aa100000-0000-4000-8000-000000000001',
        1,
        10
      )
  ),
  true,
  'the first owner-scoped chat request reserves durably'
);

select ok(
  (
    select persona_id = 'aries-amara'
       and persona_version = 'pilot-2026-07-19.1'
       and model_provider = 'anthropic'
       and model = 'claude-test'
       and request_max_tokens = 640
       and request_characters = 27
       and token_source = 'pending'
       and attempt_number = 1
       and metadata = jsonb_build_object(
         'accounting_version',
         'companion-usage-2026-07-19.1'
       )
      from public.ai_usage_events
     where user_id = 'a1000000-0000-4000-8000-000000000001'
       and feature = 'companion_chat'
       and request_key = 'aa100000-0000-4000-8000-000000000001'
  ),
  'a reservation stores only bounded provenance and numeric request size'
);

insert into public.user_companion_relationships (
  id, user_id, companion_id, is_primary
) values (
  'ab100000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'aries-amara',
  true
);

insert into public.companion_conversations (
  id, user_id, relationship_id, companion_id, persona_version
) values (
  'ac100000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'ab100000-0000-4000-8000-000000000001',
  'aries-amara',
  'pilot-2026-07-19.1'
);

insert into public.companion_messages (
  id, conversation_id, user_id, companion_id, client_message_id,
  role, content, persona_version, delivery_state,
  request_fingerprint, request_fingerprint_key_id
) values (
  'a3100000-0000-4000-8000-000000000001',
  'ac100000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'aries-amara',
  'aa100000-0000-4000-8000-000000000001',
  'user',
  'Privacy-redacted user message.',
  'pilot-2026-07-19.1',
  'streaming',
  repeat('a', 64),
  'v1'
);

select lives_ok(
  $$
    insert into public.companion_messages (
      id, conversation_id, user_id, companion_id, client_message_id,
      role, content, persona_version, model_provider, model_version,
      delivery_state, usage_event_id, safety_metadata, completed_at
    ) values (
      'a3200000-0000-4000-8000-000000000001',
      'ac100000-0000-4000-8000-000000000001',
      'a1000000-0000-4000-8000-000000000001',
      'aries-amara',
      'aa100000-0000-4000-8000-000000000001',
      'companion',
      'A durably linked companion response.',
      'pilot-2026-07-19.1',
      'anthropic',
      'claude-test',
      'complete',
      (
        select id
          from public.ai_usage_events
         where user_id = 'a1000000-0000-4000-8000-000000000001'
           and feature = 'companion_chat'
           and request_key = 'aa100000-0000-4000-8000-000000000001'
      ),
      jsonb_build_object(
        'provider_usage', jsonb_build_object(
          'input_tokens', 19,
          'output_tokens', 11
        ),
        'usage_accounting', jsonb_build_object(
          'response_characters', 84,
          'token_source', 'provider'
        )
      ),
      clock_timestamp()
    )
  $$,
  'response persistence atomically finalizes its matched usage reservation'
);

select is(
  public.finalize_companion_ai_usage(
    'a1000000-0000-4000-8000-000000000001',
    (
      select id
        from public.ai_usage_events
       where user_id = 'a1000000-0000-4000-8000-000000000001'
         and feature = 'companion_chat'
         and request_key = 'aa100000-0000-4000-8000-000000000001'
    ),
    'success',
    'anthropic',
    'claude-test',
    19,
    11,
    84,
    'provider',
    null
  ),
  true,
  'the owner-scoped finalizer idempotently confirms trigger-committed usage'
);

select ok(
  (
    select status = 'success'
       and input_tokens = 19
       and output_tokens = 11
       and total_tokens = 30
       and response_characters = 84
       and token_source = 'provider'
       and finalized_at is not null
      from public.ai_usage_events
     where user_id = 'a1000000-0000-4000-8000-000000000001'
       and feature = 'companion_chat'
       and request_key = 'aa100000-0000-4000-8000-000000000001'
  ),
  'successful accounting preserves actual token provenance'
);

select is(
  public.finalize_companion_ai_usage(
    'a2000000-0000-4000-8000-000000000002',
    (
      select id
        from public.ai_usage_events
       where user_id = 'a1000000-0000-4000-8000-000000000001'
         and feature = 'companion_chat'
         and request_key = 'aa100000-0000-4000-8000-000000000001'
    ),
    'success',
    'anthropic',
    'claude-test',
    19,
    11,
    84,
    'provider',
    null
  ),
  false,
  'finalization cannot cross the durable event owner boundary'
);

select is(
  (
    select usage_event_id
      from public.reserve_companion_ai_usage(
        'a1000000-0000-4000-8000-000000000001',
        'companion_chat',
        'aries-amara',
        'pilot-2026-07-19.1',
        'anthropic',
        'claude-test',
        640,
        27,
        'aa100000-0000-4000-8000-000000000001',
        1,
        10
      )
  ),
  (
    select id
      from public.ai_usage_events
     where user_id = 'a1000000-0000-4000-8000-000000000001'
       and feature = 'companion_chat'
       and request_key = 'aa100000-0000-4000-8000-000000000001'
  ),
  'an idempotent completed chat request resolves to the same usage event'
);

select is(
  (
    select count(*)
      from public.ai_usage_events
     where user_id = 'a1000000-0000-4000-8000-000000000001'
       and feature = 'companion_chat'
       and request_key = 'aa100000-0000-4000-8000-000000000001'
  ),
  1::bigint,
  'idempotent replay does not mint another accounting attempt'
);

select is(
  (
    select allowed
      from public.reserve_companion_ai_usage(
        'a1000000-0000-4000-8000-000000000001',
        'companion_chat',
        'aries-amara',
        'pilot-2026-07-19.1',
        'anthropic',
        'claude-test',
        640,
        18,
        'aa100000-0000-4000-8000-000000000002',
        1,
        10
      )
  ),
  false,
  'a second concurrent-window chat key is rejected at the durable limit'
);

select is(
  (
    select status
      from public.ai_usage_events
     where user_id = 'a1000000-0000-4000-8000-000000000001'
       and request_key = 'aa100000-0000-4000-8000-000000000002'
  ),
  'rate_limited',
  'a denied attempt is recorded without counting as provider usage'
);

select is(
  (
    select allowed
      from public.reserve_companion_ai_usage(
        'a2000000-0000-4000-8000-000000000002',
        'companion_chat',
        'taurus-theo',
        'pilot-2026-07-19.1',
        'anthropic',
        'claude-test',
        640,
        20,
        'aa200000-0000-4000-8000-000000000001',
        1,
        10
      )
  ),
  true,
  'one user cannot consume another user''s rate window'
);

select is(
  (
    select allowed
      from public.reserve_companion_ai_usage(
        'a1000000-0000-4000-8000-000000000001',
        'companion_decode',
        'pisces-zev',
        'pilot-2026-07-19.1',
        'anthropic',
        'claude-test',
        900,
        41,
        null,
        1,
        10
      )
  ),
  true,
  'an authorized Decode call receives its own durable reservation'
);

select is(
  public.finalize_companion_ai_usage(
    'a1000000-0000-4000-8000-000000000001',
    (
      select id
        from public.ai_usage_events
       where user_id = 'a1000000-0000-4000-8000-000000000001'
         and feature = 'companion_decode'
         and status = 'reserved'
       order by created_at desc
       limit 1
    ),
    'failed',
    'anthropic',
    'claude-test',
    23,
    0,
    0,
    'provider',
    'provider_format'
  ),
  true,
  'a failed provider attempt retains any known provider token count'
);

select is(
  (
    select allowed
      from public.reserve_companion_ai_usage(
        'a1000000-0000-4000-8000-000000000001',
        'companion_decode',
        'pisces-zev',
        'pilot-2026-07-19.1',
        'anthropic',
        'claude-test',
        900,
        12,
        null,
        1,
        10
      )
  ),
  false,
  'failed provider attempts remain in the durable rate window'
);

reset role;

select ok(
  exists (
    select 1
      from pg_proc procedure
      join pg_namespace namespace on namespace.oid = procedure.pronamespace
     where namespace.nspname = 'companion_private'
       and procedure.proname = 'delete_current_user_companion_usage'
       and procedure.prosecdef = true
       and array_to_string(procedure.proconfig, ',') like '%search_path=""%'
  )
  and exists (
    select 1
      from information_schema.routine_privileges
     where routine_schema = 'companion_private'
       and routine_name = 'delete_current_user_companion_usage'
       and grantee = 'authenticated'
       and privilege_type = 'EXECUTE'
  )
  and not exists (
    select 1
      from information_schema.routine_privileges
     where routine_schema = 'companion_private'
       and routine_name = 'delete_current_user_companion_usage'
       and grantee in ('PUBLIC', 'anon', 'service_role')
  ),
  'a private owner-derived helper erases usage without granting table deletion'
);

insert into public.ai_usage_events (
  user_id, feature, status, finalized_at
) values (
  'a1000000-0000-4000-8000-000000000001',
  'prediction',
  'success',
  clock_timestamp()
);

select ok(
  exists (
    select 1
      from pg_proc procedure
      join pg_namespace namespace on namespace.oid = procedure.pronamespace
     where namespace.nspname = 'public'
       and procedure.proname = 'delete_current_user_companion_data'
       and procedure.pronargs = 0
       and procedure.prosecdef = false
       and array_to_string(procedure.proconfig, ',') like '%search_path=""%'
  ),
  'companion deletion is a no-argument SECURITY INVOKER RPC'
);

select is(
  (
    select count(*)
      from information_schema.routine_privileges
     where routine_schema = 'public'
       and routine_name = 'delete_current_user_companion_data'
       and grantee = 'authenticated'
       and privilege_type = 'EXECUTE'
  ),
  1::bigint,
  'authenticated users can execute their account-scoped companion deletion'
);

select is(
  (
    select count(*)
      from information_schema.routine_privileges
     where routine_schema = 'public'
       and routine_name = 'delete_current_user_companion_data'
       and grantee in ('PUBLIC', 'anon', 'service_role')
  ),
  0::bigint,
  'anonymous and privileged API roles are not granted the user deletion RPC'
);

select throws_ok(
  $$ select * from public.delete_current_user_companion_data() $$,
  '42501',
  null,
  'companion deletion refuses execution without an authenticated uid'
);

insert into public.user_companion_relationships (
  id, user_id, companion_id, is_primary
) values
  (
    'ab200000-0000-4000-8000-000000000002',
    'a2000000-0000-4000-8000-000000000002',
    'taurus-theo',
    true
  );

insert into public.companion_messages (
  id, conversation_id, user_id, companion_id, client_message_id,
  role, content, persona_version
) values (
  'ad100000-0000-4000-8000-000000000001',
  'ac100000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'aries-amara',
  'ae100000-0000-4000-8000-000000000001',
  'user',
  'Account-owned test message.',
  'pilot-2026-07-19.1'
);

insert into public.companion_memories (
  id, user_id, scope, memory_kind, content, source
) values (
  'af100000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'shared_user_fact',
  'preference',
  'Account-owned test memory.',
  'user_explicit'
);

insert into public.relationship_people (
  id, user_id, display_name
) values (
  'b0100000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'Test Person'
);

insert into public.communication_outcomes (
  id, client_outcome_id, user_id, companion_id, relationship_id,
  person_id, conversation_id, action_text
) values (
  'b1100000-0000-4000-8000-000000000001',
  'b2100000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'aries-amara',
  'ab100000-0000-4000-8000-000000000001',
  'b0100000-0000-4000-8000-000000000001',
  'ac100000-0000-4000-8000-000000000001',
  'Account-owned test action.'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"a1000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);
select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000001',
  true
);

select results_eq(
  $$ select * from public.delete_current_user_companion_data() $$,
  $$ values (3::bigint, 1::bigint, 1::bigint, 1::bigint, 1::bigint, 1::bigint) $$,
  'companion deletion returns exact per-table counts in FK-safe order'
);

select is(
  (
    select count(*)
      from (
        select user_id from public.companion_messages
        union all select user_id from public.companion_conversations
        union all select user_id from public.companion_memories
        union all select user_id from public.communication_outcomes
        union all select user_id from public.relationship_people
        union all select user_id from public.user_companion_relationships
      ) owned
     where user_id = 'a1000000-0000-4000-8000-000000000001'
  ),
  0::bigint,
  'all six companion data surfaces are empty for the current user'
);

reset role;

select is(
  (
    select count(*)
      from public.ai_usage_events
     where user_id = 'a1000000-0000-4000-8000-000000000001'
       and feature in ('companion_chat', 'companion_decode')
  ),
  0::bigint,
  'companion deletion erases all current-user Chat and Decode usage rows'
);

select is(
  (
    select count(*)
      from public.ai_usage_events
     where user_id = 'a1000000-0000-4000-8000-000000000001'
       and feature = 'prediction'
  ),
  1::bigint,
  'companion deletion preserves the current user''s unrelated feature usage'
);

select is(
  (
    select count(*)
      from public.ai_usage_events
     where user_id = 'a2000000-0000-4000-8000-000000000002'
       and feature = 'companion_chat'
  ),
  1::bigint,
  'companion deletion preserves every other user''s companion usage'
);

select is(
  (
    select count(*)
      from public.user_companion_relationships
     where user_id = 'a2000000-0000-4000-8000-000000000002'
  ),
  1::bigint,
  'account deletion leaves another user''s companion relationship intact'
);

select is(
  (select count(*) from public.companion_personas),
  24::bigint,
  'account deletion never deletes the shared persona catalog'
);

select * from finish();
rollback;
