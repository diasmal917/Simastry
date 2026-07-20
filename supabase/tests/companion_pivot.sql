begin;

select plan(65);

select has_table('public', 'companion_personas', 'companion persona catalog exists');
select has_table('public', 'user_companion_relationships', 'companion relationships exist');
select has_table('public', 'companion_conversations', 'companion conversations exist');
select has_table('public', 'companion_messages', 'companion messages exist');
select has_table('public', 'companion_memories', 'companion memories exist');
select has_table('public', 'relationship_people', 'private People records exist');
select has_table('public', 'communication_outcomes', 'offline communication outcomes exist');

select is(
  (select count(*) from public.companion_personas),
  24::bigint,
  'all 24 stable Factory companion slugs are seeded'
);

select is(
  (select array_agg(id order by display_order)
   from public.companion_personas
   where status = 'pilot_ready'),
  array['aries-amara', 'taurus-theo', 'libra-isolde', 'pisces-zev']::text[],
  'only Amara, Theo, Isolde, and Zev are pilot-ready'
);

select is(
  (select count(*)
   from public.companion_personas
   where status = 'certification_pending'),
  20::bigint,
  'the remaining 20 companions stay certification-gated'
);

select ok(
  (select count(*) = 7 and bool_and(c.relrowsecurity)
   from pg_class c
   join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relname in (
       'companion_personas',
       'user_companion_relationships',
       'companion_conversations',
       'companion_messages',
       'companion_memories',
       'relationship_people',
       'communication_outcomes'
     )),
  'RLS is enabled on every companion-pivot table'
);

select is(
  (select count(*)
   from information_schema.role_table_grants
   where table_schema = 'public'
     and table_name = 'companion_personas'
     and grantee = 'anon'
     and privilege_type = 'SELECT'),
  1::bigint,
  'anonymous clients receive read-only access to released persona metadata'
);

select is(
  (select count(*)
   from information_schema.role_table_grants
   where table_schema = 'public'
     and table_name in (
       'user_companion_relationships',
       'companion_conversations',
       'companion_messages',
       'companion_memories',
       'relationship_people',
       'communication_outcomes'
     )
     and grantee in ('anon', 'PUBLIC')),
  0::bigint,
  'anonymous and PUBLIC roles have no private companion-data grants'
);

select ok(
  (select count(*) = 28
     and bool_and(privilege_type in ('DELETE', 'INSERT', 'SELECT', 'UPDATE'))
   from information_schema.role_table_grants
   where table_schema = 'public'
     and table_name in (
       'companion_personas',
       'user_companion_relationships',
       'companion_conversations',
       'companion_messages',
       'companion_memories',
       'relationship_people',
       'communication_outcomes'
     )
     and grantee = 'service_role'),
  'service-role runtime receives explicit CRUD grants on all seven tables'
);

select is(
  (select count(*)
   from pg_policies
   where schemaname = 'public'
     and tablename in (
       'companion_personas',
       'user_companion_relationships',
       'companion_conversations',
       'companion_messages',
       'companion_memories',
       'relationship_people',
       'communication_outcomes'
     )),
  22::bigint,
  'the release catalog and private tables have the expected policy surface'
);

select ok(
  (select count(*) = 5
     and bool_and(qual is not null and with_check is not null)
   from pg_policies
   where schemaname = 'public'
     and tablename in (
       'user_companion_relationships',
       'companion_conversations',
       'companion_memories',
       'relationship_people',
       'communication_outcomes'
     )
     and cmd = 'UPDATE'),
  'every authenticated UPDATE policy has USING and WITH CHECK clauses'
);

select ok(
  (select count(*) = 21
     and bool_and(
       (coalesce(qual, '') || coalesce(with_check, '')) like '%auth.uid()%'
       and (coalesce(qual, '') || coalesce(with_check, '')) like '%user_id%'
     )
   from pg_policies
   where schemaname = 'public'
     and tablename in (
       'user_companion_relationships',
       'companion_conversations',
       'companion_messages',
       'companion_memories',
       'relationship_people',
       'communication_outcomes'
     )),
  'every private-table policy binds auth.uid() to user_id'
);

select ok(
  exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and indexname = 'user_companion_relationships_one_primary_idx'
      and indexdef like 'CREATE UNIQUE INDEX%'
      and indexdef like '%WHERE is_primary%'
  ),
  'a partial unique index enforces at most one primary companion per user'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.companion_messages'::regclass
      and conname = 'companion_messages_client_role_unique'
      and pg_get_constraintdef(oid) like '%UNIQUE (user_id, client_message_id, role)%'
  ),
  'message idempotency keys are global per user and role'
);

select is(
  (select count(*)
   from information_schema.columns
   where table_schema = 'public'
     and table_name = 'companion_personas'
     and column_name like '%prompt%'),
  0::bigint,
  'the public persona catalog cannot store raw persona prompts'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.companion_messages'::regclass
      and conname = 'companion_messages_identity'
      and pg_get_constraintdef(oid) like '%legacy-unversioned%'
      and pg_get_constraintdef(oid) like '%is_legacy_import%'
  ),
  'canonical legacy messages require the reserved unversioned provenance marker'
);

select ok(
  exists (
    select 1
    from pg_proc procedure
    join pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname = 'delete_current_user_expert_archive'
      and procedure.pronargs = 0
  ),
  'expert archive deletion is an account-scoped no-argument RPC'
);

select ok(
  exists (
    select 1
    from pg_proc procedure
    join pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname = 'delete_current_user_expert_archive'
      and procedure.prosecdef = false
      and array_to_string(procedure.proconfig, ',') like '%search_path=""%'
  ),
  'expert archive deletion is SECURITY INVOKER with an empty search path'
);

select is(
  (select count(*)
   from information_schema.routine_privileges
   where routine_schema = 'public'
     and routine_name = 'delete_current_user_expert_archive'
     and grantee = 'authenticated'
     and privilege_type = 'EXECUTE'),
  1::bigint,
  'authenticated callers can execute expert archive deletion'
);

select is(
  (select count(*)
   from information_schema.routine_privileges
   where routine_schema = 'public'
     and routine_name = 'delete_current_user_expert_archive'
     and grantee in ('PUBLIC', 'anon', 'service_role')),
  0::bigint,
  'anonymous and privileged API roles are not granted the user deletion RPC'
);

select throws_ok(
  $$ select * from public.delete_current_user_expert_archive() $$,
  '42501',
  null,
  'the expert archive RPC refuses execution without an authenticated uid'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.companion_memories'::regclass
      and conname = 'companion_memories_source'
      and pg_get_constraintdef(oid) not like '%inferred%'
      and pg_get_constraintdef(oid) like '%conversation_confirmed%'
  ),
  'memory sources require explicit or confirmed provenance and exclude silent inference'
);

select is(
  (select count(*)
   from pg_constraint
   where conname in (
     'user_companion_relationships_migration_consent',
     'companion_conversations_migration_consent',
     'companion_memories_migration_consent',
     'relationship_people_migration_consent'
   )),
  4::bigint,
  'all local-import surfaces require a migration version and explicit sync consent'
);

select is(
  (select count(*)
   from information_schema.role_table_grants
   where table_schema = 'public'
     and table_name in ('companion_conversations', 'companion_messages')
     and grantee = 'authenticated'
     and privilege_type = 'INSERT'),
  0::bigint,
  'conversation and message creation are reserved for the server runtime'
);

insert into auth.users (id, email)
values
  ('10000000-0000-0000-0000-000000000001', 'companion-test-one@example.invalid'),
  ('20000000-0000-0000-0000-000000000002', 'companion-test-two@example.invalid')
on conflict (id) do nothing;

select lives_ok(
  $$
    insert into public.user_companion_relationships (
      id, user_id, companion_id, is_primary
    ) values (
      '11000000-0000-0000-0000-000000000001',
      '10000000-0000-0000-0000-000000000001',
      'aries-amara',
      true
    )
  $$,
  'the first primary relationship is accepted'
);

select lives_ok(
  $$
    insert into public.user_companion_relationships (
      id, user_id, companion_id, is_primary
    ) values (
      '22000000-0000-0000-0000-000000000002',
      '20000000-0000-0000-0000-000000000002',
      'taurus-theo',
      true
    )
  $$,
  'another user can independently choose a primary'
);

select throws_ok(
  $$
    insert into public.user_companion_relationships (
      id, user_id, companion_id, is_primary
    ) values (
      '12000000-0000-0000-0000-000000000002',
      '10000000-0000-0000-0000-000000000001',
      'taurus-theo',
      true
    )
  $$,
  '23505',
  null,
  'a user cannot have two primary companions'
);

select lives_ok(
  $$
    insert into public.user_companion_relationships (
      id,
      user_id,
      legacy_record_id,
      legacy_identity,
      status,
      migration_version,
      sync_consent_at
    ) values (
      '13000000-0000-0000-0000-000000000003',
      '10000000-0000-0000-0000-000000000001',
      'legacy-custom-one',
      '{"name":"Original custom companion"}'::jsonb,
      'legacy_read_only',
      1,
      now()
    )
  $$,
  'an unmatched custom companion can be preserved as a consented read-only legacy record'
);

select throws_ok(
  $$
    insert into public.companion_conversations (
      id,
      user_id,
      relationship_id,
      status,
      legacy_record_id,
      migration_version,
      sync_consent_at
    ) values (
      '33000000-0000-0000-0000-000000000003',
      '10000000-0000-0000-0000-000000000001',
      '22000000-0000-0000-0000-000000000002',
      'legacy_read_only',
      'legacy-cross-owner',
      1,
      now()
    )
  $$,
  '23503',
  null,
  'owner-pair foreign keys protect legacy rows even when companion_id is NULL'
);

select lives_ok(
  $$
    insert into public.companion_conversations (
      id, user_id, relationship_id, companion_id, persona_version
    ) values (
      '31000000-0000-0000-0000-000000000001',
      '10000000-0000-0000-0000-000000000001',
      '11000000-0000-0000-0000-000000000001',
      'aries-amara',
      'pilot-2026-07-19.1'
    )
  $$,
  'the server can create a canonical versioned conversation'
);

select lives_ok(
  $$
    insert into public.companion_messages (
      id,
      conversation_id,
      user_id,
      companion_id,
      client_message_id,
      role,
      content,
      persona_version
    ) values (
      '41000000-0000-0000-0000-000000000001',
      '31000000-0000-0000-0000-000000000001',
      '10000000-0000-0000-0000-000000000001',
      'aries-amara',
      '51000000-0000-0000-0000-000000000001',
      'user',
      'Help me prepare for a difficult conversation.',
      'pilot-2026-07-19.1'
    )
  $$,
  'the runtime can persist the user side of a turn'
);

select lives_ok(
  $$
    insert into public.companion_messages (
      id,
      conversation_id,
      user_id,
      companion_id,
      client_message_id,
      role,
      content,
      persona_version,
      model_provider,
      model_version
    ) values (
      '42000000-0000-0000-0000-000000000002',
      '31000000-0000-0000-0000-000000000001',
      '10000000-0000-0000-0000-000000000001',
      'aries-amara',
      '51000000-0000-0000-0000-000000000001',
      'companion',
      'Let us make the next step direct and safe.',
      'pilot-2026-07-19.1',
      'anthropic',
      'claude-sonnet-4-6'
    )
  $$,
  'one companion response may share the request idempotency key'
);

select throws_ok(
  $$
    insert into public.companion_messages (
      id,
      conversation_id,
      user_id,
      companion_id,
      client_message_id,
      role,
      content,
      persona_version
    ) values (
      '43000000-0000-0000-0000-000000000003',
      '31000000-0000-0000-0000-000000000001',
      '10000000-0000-0000-0000-000000000001',
      'aries-amara',
      '51000000-0000-0000-0000-000000000001',
      'user',
      'Duplicate retry.',
      'pilot-2026-07-19.1'
    )
  $$,
  '23505',
  null,
  'a retried user turn cannot create a duplicate message'
);

select lives_ok(
  $$
    insert into public.companion_conversations (
      id,
      user_id,
      relationship_id,
      companion_id,
      persona_version,
      legacy_record_id,
      migration_version,
      sync_consent_at
    ) values (
      '35000000-0000-0000-0000-000000000005',
      '10000000-0000-0000-0000-000000000001',
      '11000000-0000-0000-0000-000000000001',
      'aries-amara',
      'legacy-unversioned',
      'legacy-canonical-one',
      1,
      now()
    )
  $$,
  'a consented canonical legacy conversation retains its exact companion identity'
);

select lives_ok(
  $$
    insert into public.companion_messages (
      id,
      conversation_id,
      user_id,
      companion_id,
      client_message_id,
      role,
      content,
      persona_version,
      is_legacy_import
    ) values (
      '44000000-0000-0000-0000-000000000004',
      '35000000-0000-0000-0000-000000000005',
      '10000000-0000-0000-0000-000000000001',
      'aries-amara',
      '53000000-0000-0000-0000-000000000003',
      'user',
      'A consented device-local message.',
      'legacy-unversioned',
      true
    )
  $$,
  'a canonical imported message records both its companion and legacy provenance'
);

select throws_ok(
  $$
    insert into public.companion_messages (
      conversation_id,
      user_id,
      companion_id,
      client_message_id,
      role,
      content,
      persona_version,
      is_legacy_import
    ) values (
      '35000000-0000-0000-0000-000000000005',
      '10000000-0000-0000-0000-000000000001',
      'aries-amara',
      '54000000-0000-0000-0000-000000000004',
      'user',
      'A forged imported version.',
      'pilot-2026-07-19.1',
      true
    )
  $$,
  '23514',
  null,
  'legacy imports cannot claim a certified runtime persona version'
);

select throws_ok(
  $$
    insert into public.companion_messages (
      conversation_id,
      user_id,
      companion_id,
      client_message_id,
      role,
      content,
      persona_version,
      is_legacy_import
    ) values (
      '35000000-0000-0000-0000-000000000005',
      '10000000-0000-0000-0000-000000000001',
      'aries-amara',
      '55000000-0000-0000-0000-000000000005',
      'user',
      'A forged live legacy marker.',
      'legacy-unversioned',
      false
    )
  $$,
  '23514',
  null,
  'runtime messages cannot use the reserved legacy persona marker'
);

select lives_ok(
  $$
    insert into public.companion_conversations (
      id,
      user_id,
      relationship_id,
      companion_id,
      persona_version,
      legacy_record_id,
      migration_version,
      sync_consent_at
    ) values (
      '36000000-0000-0000-0000-000000000006',
      '20000000-0000-0000-0000-000000000002',
      '22000000-0000-0000-0000-000000000002',
      'taurus-theo',
      'legacy-unversioned',
      'legacy-canonical-one',
      1,
      now()
    )
  $$,
  'the same device-local conversation key is safely scoped to another owner'
);

select lives_ok(
  $$
    insert into public.companion_messages (
      id,
      conversation_id,
      user_id,
      companion_id,
      client_message_id,
      role,
      content,
      persona_version,
      is_legacy_import
    ) values (
      '45000000-0000-0000-0000-000000000005',
      '36000000-0000-0000-0000-000000000006',
      '20000000-0000-0000-0000-000000000002',
      'taurus-theo',
      '53000000-0000-0000-0000-000000000003',
      'user',
      'The same local key for a different owner.',
      'legacy-unversioned',
      true
    )
  $$,
  'message idempotency keys do not collide across users'
);

select throws_ok(
  $$
    insert into public.communication_outcomes (
      id,
      client_outcome_id,
      user_id,
      companion_id,
      relationship_id,
      action_text,
      result_summary,
      result_source,
      result_recorded_at
    ) values (
      '61000000-0000-0000-0000-000000000001',
      '62000000-0000-0000-0000-000000000001',
      '10000000-0000-0000-0000-000000000001',
      'aries-amara',
      '11000000-0000-0000-0000-000000000001',
      'Send the clear boundary.',
      'It probably went well.',
      'inferred',
      now()
    )
  $$,
  '23514',
  null,
  'the database rejects inferred offline results'
);

insert into public.relationship_people (id, user_id, display_name)
values
  (
    '71000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    'Person One'
  ),
  (
    '72000000-0000-0000-0000-000000000002',
    '20000000-0000-0000-0000-000000000002',
    'Person Two'
  );

select throws_ok(
  $$
    insert into public.communication_outcomes (
      id,
      client_outcome_id,
      user_id,
      companion_id,
      relationship_id,
      person_id,
      action_text
    ) values (
      '63000000-0000-0000-0000-000000000003',
      '64000000-0000-0000-0000-000000000003',
      '10000000-0000-0000-0000-000000000001',
      'aries-amara',
      '11000000-0000-0000-0000-000000000001',
      '72000000-0000-0000-0000-000000000002',
      'This must not bind another user''s person.'
    )
  $$,
  '23503',
  null,
  'owner-pair foreign keys reject another user''s People record'
);

insert into public.companion_memories (
  id, user_id, scope, memory_kind, content, source
) values
  (
    '81000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    'shared_user_fact',
    'communication_preference',
    'I prefer concise drafts.',
    'user_explicit'
  ),
  (
    '82000000-0000-0000-0000-000000000002',
    '20000000-0000-0000-0000-000000000002',
    'shared_user_fact',
    'communication_preference',
    'I prefer long drafts.',
    'user_explicit'
  );

insert into public.expert_astrology_intake (user_id)
values
  ('10000000-0000-0000-0000-000000000001'),
  ('20000000-0000-0000-0000-000000000002');

insert into public.expert_astrology_chart_imports (
  id, user_id, storage_path
)
values
  (
    '91000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001/archive/chart-one.png'
  ),
  (
    '92000000-0000-0000-0000-000000000002',
    '20000000-0000-0000-0000-000000000002',
    '20000000-0000-0000-0000-000000000002/archive/chart-two.png'
  );

insert into public.expert_person_astrology_intake (
  user_id, person_id, display_name, chart_import_id
)
values
  (
    '10000000-0000-0000-0000-000000000001',
    '93000000-0000-0000-0000-000000000003',
    'Archived Person One',
    '91000000-0000-0000-0000-000000000001'
  ),
  (
    '20000000-0000-0000-0000-000000000002',
    '94000000-0000-0000-0000-000000000004',
    'Archived Person Two',
    '92000000-0000-0000-0000-000000000002'
  );

insert into public.expert_astrologer_conversations (
  id, user_id, specialist_id
)
values
  (
    '95000000-0000-0000-0000-000000000005',
    '10000000-0000-0000-0000-000000000001',
    'archive-specialist-one'
  ),
  (
    '96000000-0000-0000-0000-000000000006',
    '20000000-0000-0000-0000-000000000002',
    'archive-specialist-two'
  );

insert into public.expert_astrologer_messages (
  id, conversation_id, user_id, specialist_id, role, content
)
values
  (
    '97000000-0000-0000-0000-000000000007',
    '95000000-0000-0000-0000-000000000005',
    '10000000-0000-0000-0000-000000000001',
    'archive-specialist-one',
    'user',
    'Archived question one.'
  ),
  (
    '98000000-0000-0000-0000-000000000008',
    '96000000-0000-0000-0000-000000000006',
    '20000000-0000-0000-0000-000000000002',
    'archive-specialist-two',
    'user',
    'Archived question two.'
  );

insert into public.expert_astrologer_consultations (
  id, user_id, user_question
)
values
  (
    '99000000-0000-0000-0000-000000000009',
    '10000000-0000-0000-0000-000000000001',
    'Archived council question one?'
  ),
  (
    'a1000000-0000-4000-8000-000000000010',
    '20000000-0000-0000-0000-000000000002',
    'Archived council question two?'
  );

insert into public.expert_astrologer_consultation_responses (
  id,
  multi_consultation_id,
  user_id,
  specialist_id,
  user_question,
  specialist_response
)
values
  (
    'a2000000-0000-4000-8000-000000000011',
    '99000000-0000-0000-0000-000000000009',
    '10000000-0000-0000-0000-000000000001',
    'archive-specialist-one',
    'Archived council question one?',
    'Archived response one.'
  ),
  (
    'a3000000-0000-4000-8000-000000000012',
    'a1000000-0000-4000-8000-000000000010',
    '20000000-0000-0000-0000-000000000002',
    'archive-specialist-two',
    'Archived council question two?',
    'Archived response two.'
  );

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);
select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001',
  true
);

select is(
  (select count(*) from public.user_companion_relationships),
  2::bigint,
  'RLS exposes only the current user''s canonical and legacy relationships'
);

select is(
  (select count(*) from public.companion_personas),
  4::bigint,
  'authenticated clients can read only the four released pilot personas'
);

select is(
  (select count(*)
   from public.companion_personas
   where status = 'certification_pending'),
  0::bigint,
  'certification-pending personas remain hidden from app clients'
);

select throws_ok(
  $$
    insert into public.user_companion_relationships (
      id, user_id, companion_id
    ) values (
      '23000000-0000-0000-0000-000000000003',
      '20000000-0000-0000-0000-000000000002',
      'pisces-zev'
    )
  $$,
  '42501',
  null,
  'RLS rejects creating a relationship for another user'
);

select throws_ok(
  $$
    insert into public.user_companion_relationships (
      id, user_id, companion_id
    ) values (
      '14000000-0000-0000-0000-000000000004',
      '10000000-0000-0000-0000-000000000001',
      'aries-cassian'
    )
  $$,
  '42501',
  null,
  'RLS rejects choosing a persona that is not released'
);

select throws_ok(
  $$
    insert into public.companion_conversations (
      id, user_id, relationship_id, companion_id, persona_version
    ) values (
      '34000000-0000-0000-0000-000000000004',
      '10000000-0000-0000-0000-000000000001',
      '11000000-0000-0000-0000-000000000001',
      'aries-amara',
      'forged-client-version'
    )
  $$,
  '42501',
  null,
  'clients cannot mint conversations or forged persona versions'
);

select throws_ok(
  $$
    insert into public.companion_messages (
      conversation_id,
      user_id,
      companion_id,
      client_message_id,
      role,
      content,
      persona_version
    ) values (
      '31000000-0000-0000-0000-000000000001',
      '10000000-0000-0000-0000-000000000001',
      'aries-amara',
      '52000000-0000-0000-0000-000000000002',
      'user',
      'Bypass the runtime.',
      'pilot-2026-07-19.1'
    )
  $$,
  '42501',
  null,
  'clients cannot bypass runtime safety and rate limiting by inserting messages directly'
);

select results_eq(
  $$
    update public.companion_memories
    set content = 'I prefer one concise draft.'
    where id = '81000000-0000-0000-0000-000000000001'
    returning content
  $$,
  $$ values ('I prefer one concise draft.'::text) $$,
  'a user can edit their own memory'
);

select is(
  (select edit_revision
   from public.companion_memories
   where id = '81000000-0000-0000-0000-000000000001'),
  1,
  'memory edits advance the server-tracked revision'
);

select results_eq(
  $$
    update public.companion_memories
    set content = 'Not allowed.'
    where id = '82000000-0000-0000-0000-000000000002'
    returning content
  $$,
  $$ select null::text where false $$,
  'RLS prevents editing another user''s memory'
);

select results_eq(
  $$
    delete from public.companion_memories
    where id = '81000000-0000-0000-0000-000000000001'
    returning id
  $$,
  $$ values ('81000000-0000-0000-0000-000000000001'::uuid) $$,
  'a user can permanently delete their own memory'
);

select is(
  (select count(*) from public.relationship_people),
  1::bigint,
  'RLS exposes only the current user''s People records'
);

select lives_ok(
  $$
    insert into public.communication_outcomes (
      id,
      client_outcome_id,
      user_id,
      companion_id,
      relationship_id,
      person_id,
      action_text,
      planned_for
    ) values (
      '65000000-0000-0000-0000-000000000005',
      '66000000-0000-0000-0000-000000000005',
      '10000000-0000-0000-0000-000000000001',
      'aries-amara',
      '11000000-0000-0000-0000-000000000001',
      '71000000-0000-0000-0000-000000000001',
      'Say the boundary clearly.',
      now()
    )
  $$,
  'a user can record an explicit offline action for their own person'
);

select throws_ok(
  $$
    insert into public.communication_outcomes (
      id,
      client_outcome_id,
      user_id,
      companion_id,
      relationship_id,
      action_text
    ) values (
      '67000000-0000-0000-0000-000000000006',
      '66000000-0000-0000-0000-000000000005',
      '10000000-0000-0000-0000-000000000001',
      'aries-amara',
      '11000000-0000-0000-0000-000000000001',
      'Duplicate offline action.'
    )
  $$,
  '23505',
  null,
  'offline action submissions are idempotent per user'
);

select results_eq(
  $$
    update public.communication_outcomes
    set
      action_state = 'completed',
      acted_at = now(),
      result_kind = 'better',
      result_summary = 'They listened and we agreed on a next step.',
      result_source = 'user_recorded',
      result_recorded_at = now()
    where id = '65000000-0000-0000-0000-000000000005'
    returning result_source
  $$,
  $$ values ('user_recorded'::text) $$,
  'a user can explicitly record what happened offline'
);

select throws_ok(
  $$
    update public.communication_outcomes
    set result_source = 'inferred'
    where id = '65000000-0000-0000-0000-000000000005'
  $$,
  '23514',
  null,
  'an existing outcome cannot be relabeled as inferred'
);

select results_eq(
  $$
    select * from public.delete_current_user_expert_archive()
  $$,
  $$
    values (
      1::bigint,
      1::bigint,
      1::bigint,
      1::bigint,
      1::bigint,
      1::bigint,
      1::bigint,
      array['10000000-0000-0000-0000-000000000001/archive/chart-one.png']::text[]
    )
  $$,
  'the RPC atomically reports every deleted current-user archive row and chart path'
);

select is(
  (
    (select count(*) from public.expert_astrologer_consultation_responses)
    + (select count(*) from public.expert_astrologer_consultations)
    + (select count(*) from public.expert_astrologer_messages)
    + (select count(*) from public.expert_astrologer_conversations)
    + (select count(*) from public.expert_person_astrology_intake)
    + (select count(*) from public.expert_astrology_chart_imports)
    + (select count(*) from public.expert_astrology_intake)
  ),
  0::bigint,
  'the current authenticated user has no expert archive rows after deletion'
);

reset role;

select ok(
  (select count(*) from public.expert_astrologer_consultation_responses
   where user_id = '20000000-0000-0000-0000-000000000002') = 1
  and (select count(*) from public.expert_astrologer_consultations
       where user_id = '20000000-0000-0000-0000-000000000002') = 1
  and (select count(*) from public.expert_astrologer_messages
       where user_id = '20000000-0000-0000-0000-000000000002') = 1
  and (select count(*) from public.expert_astrologer_conversations
       where user_id = '20000000-0000-0000-0000-000000000002') = 1
  and (select count(*) from public.expert_person_astrology_intake
       where user_id = '20000000-0000-0000-0000-000000000002') = 1
  and (select count(*) from public.expert_astrology_chart_imports
       where user_id = '20000000-0000-0000-0000-000000000002') = 1
  and (select count(*) from public.expert_astrology_intake
       where user_id = '20000000-0000-0000-0000-000000000002') = 1,
  'deleting one account expert archive leaves every other owner row unchanged'
);

select * from finish();
rollback;
