-- Simastry primary-companion persistence.
--
-- Persona prompts intentionally do not live in this schema. The public catalog
-- stores only stable identity and asset metadata; the companion runtime resolves
-- the approved, versioned persona program on the server.

create table public.companion_personas (
  id text primary key,
  display_name text not null,
  zodiac_sign text not null,
  element text not null,
  pronouns text not null,
  support_summary text not null,
  status text not null default 'certification_pending',
  asset_version text not null,
  asset_key_prefix text not null,
  post_count smallint not null default 10,
  active_persona_version text,
  display_order smallint not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint companion_personas_id_format
    check (id ~ '^[a-z]+-[a-z0-9-]+$'),
  constraint companion_personas_display_name_length
    check (length(trim(display_name)) between 1 and 80),
  constraint companion_personas_zodiac_sign
    check (zodiac_sign in (
      'aries', 'taurus', 'gemini', 'cancer', 'leo', 'virgo',
      'libra', 'scorpio', 'sagittarius', 'capricorn', 'aquarius', 'pisces'
    )),
  constraint companion_personas_element
    check (element in ('fire', 'earth', 'air', 'water')),
  constraint companion_personas_status
    check (status in (
      'certification_pending', 'certified_hidden', 'pilot_ready',
      'active', 'suspended', 'retired'
    )),
  constraint companion_personas_asset_version_length
    check (length(trim(asset_version)) between 1 and 120),
  constraint companion_personas_asset_key_prefix_length
    check (length(trim(asset_key_prefix)) between 1 and 160),
  constraint companion_personas_post_count
    check (post_count between 0 and 24),
  constraint companion_personas_active_version_consistency
    check (
      status not in ('certified_hidden', 'pilot_ready', 'active')
      or (
        active_persona_version is not null
        and length(trim(active_persona_version)) between 1 and 120
      )
    )
);

comment on table public.companion_personas is
  'Stable public companion identity and release metadata. Approved persona programs remain server-owned.';
comment on column public.companion_personas.id is
  'Canonical Factory slug. Display names may change without changing this identity.';
comment on column public.companion_personas.status is
  'Only pilot_ready and active rows are readable by app clients.';

insert into public.companion_personas (
  id,
  display_name,
  zodiac_sign,
  element,
  pronouns,
  support_summary,
  status,
  asset_version,
  asset_key_prefix,
  post_count,
  active_persona_version,
  display_order
) values
  ('aries-amara', 'Amara', 'aries', 'fire', 'she/her', 'Fast, direct courage without recklessness.', 'pilot_ready', 'factory-498b244e-20260719', 'Factory_aries-amara', 10, 'pilot-2026-07-19.1', 1),
  ('aries-cassian', 'Soren', 'aries', 'fire', 'he/him', 'Clean nerve and a bright spark.', 'certification_pending', 'factory-498b244e-20260719', 'Factory_aries-cassian', 10, null, 2),
  ('taurus-ada', 'Ada', 'taurus', 'earth', 'she/her', 'Soft voice and steel standards.', 'certification_pending', 'factory-498b244e-20260719', 'Factory_taurus-ada', 10, null, 3),
  ('taurus-theo', 'Theo', 'taurus', 'earth', 'he/him', 'Calm, grounded clarity without passivity.', 'pilot_ready', 'factory-498b244e-20260719', 'Factory_taurus-theo', 10, 'pilot-2026-07-19.1', 4),
  ('gemini-rina', 'Maria', 'gemini', 'air', 'she/her', 'Sharp mind with softer timing.', 'certification_pending', 'factory-498b244e-20260719', 'Factory_gemini-rina', 10, null, 5),
  ('gemini-arden', 'Arden', 'gemini', 'air', 'he/him', 'A quick wit with useful questions.', 'certification_pending', 'factory-498b244e-20260719', 'Factory_gemini-arden', 10, null, 6),
  ('cancer-mila', 'Mila', 'cancer', 'water', 'she/her', 'Tenderness with emotional precision.', 'certification_pending', 'factory-498b244e-20260719', 'Factory_cancer-mila', 10, null, 7),
  ('cancer-noel', 'Noel', 'cancer', 'water', 'he/him', 'Quiet loyalty and careful repair.', 'certification_pending', 'factory-498b244e-20260719', 'Factory_cancer-noel', 10, null, 8),
  ('leo-leona', 'Leona', 'leo', 'fire', 'she/her', 'High presence and higher standards.', 'certification_pending', 'factory-498b244e-20260719', 'Factory_leo-leona', 10, null, 9),
  ('leo-dante', 'Dante', 'leo', 'fire', 'he/him', 'Warm confidence that helps a message land.', 'certification_pending', 'factory-498b244e-20260719', 'Factory_leo-dante', 10, null, 10),
  ('virgo-mara', 'Leyla', 'virgo', 'earth', 'she/her', 'Precision with a soft landing.', 'certification_pending', 'factory-498b244e-20260719', 'Factory_virgo-mara', 10, null, 11),
  ('virgo-jonah', 'Jonah', 'virgo', 'earth', 'he/him', 'Specific, kind pattern recognition.', 'certification_pending', 'factory-498b244e-20260719', 'Factory_virgo-jonah', 10, null, 12),
  ('libra-isolde', 'Isolde', 'libra', 'air', 'she/her', 'Tactful fairness and firm boundaries.', 'pilot_ready', 'factory-498b244e-20260719', 'Factory_libra-isolde', 10, 'pilot-2026-07-19.1', 13),
  ('libra-mateo', 'Mateo', 'libra', 'air', 'he/him', 'Tact that keeps peace without self-erasure.', 'certification_pending', 'factory-498b244e-20260719', 'Factory_libra-mateo', 10, null, 14),
  ('scorpio-vera', 'Vera', 'scorpio', 'water', 'she/her', 'Controlled truth with emotional bravery.', 'certification_pending', 'factory-498b244e-20260719', 'Factory_scorpio-vera', 10, null, 15),
  ('scorpio-elias', 'Elias', 'scorpio', 'water', 'he/him', 'Depth without melodrama.', 'certification_pending', 'factory-498b244e-20260719', 'Factory_scorpio-elias', 10, null, 16),
  ('sagittarius-nadia', 'Nadia', 'sagittarius', 'fire', 'she/her', 'Truth, timing, humor, and enough air.', 'certification_pending', 'factory-498b244e-20260719', 'Factory_sagittarius-nadia', 10, null, 17),
  ('sagittarius-rafi', 'Rafi', 'sagittarius', 'fire', 'he/him', 'Candor that feels like fresh air.', 'certification_pending', 'factory-498b244e-20260719', 'Factory_sagittarius-rafi', 10, null, 18),
  ('capricorn-naomi', 'Naomi', 'capricorn', 'earth', 'she/her', 'Composed standards and consistent action.', 'certification_pending', 'factory-498b244e-20260719', 'Factory_capricorn-naomi', 10, null, 19),
  ('capricorn-silas', 'Silas', 'capricorn', 'earth', 'he/him', 'Dry humor and a patient long game.', 'certification_pending', 'factory-498b244e-20260719', 'Factory_capricorn-silas', 10, null, 20),
  ('aquarius-imani', 'Imani', 'aquarius', 'air', 'she/her', 'Original perspective without emotional pressure.', 'certification_pending', 'factory-498b244e-20260719', 'Factory_aquarius-imani', 10, null, 21),
  ('aquarius-yarrow', 'Yarrow', 'aquarius', 'air', 'he/him', 'Freedom with a clear connective thread.', 'certification_pending', 'factory-498b244e-20260719', 'Factory_aquarius-yarrow', 10, null, 22),
  ('pisces-liora', 'Liora', 'pisces', 'water', 'she/her', 'Compassion that keeps its boundary.', 'certification_pending', 'factory-498b244e-20260719', 'Factory_pisces-liora', 10, null, 23),
  ('pisces-zev', 'Zev', 'pisces', 'water', 'he/him', 'Emotionally perceptive translation without mind-reading or rescuing.', 'pilot_ready', 'factory-498b244e-20260719', 'Factory_pisces-zev', 10, 'pilot-2026-07-19.1', 24);

create table public.user_companion_relationships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  companion_id text references public.companion_personas(id) on delete restrict,
  legacy_record_id text,
  legacy_identity jsonb,
  status text not null default 'active',
  is_primary boolean not null default false,
  support_preferences jsonb not null default '{}'::jsonb,
  migration_version integer,
  sync_consent_at timestamptz,
  last_interaction_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint user_companion_relationships_status
    check (status in ('active', 'archived', 'legacy_read_only')),
  constraint user_companion_relationships_identity
    check (
      (
        status = 'legacy_read_only'
        and companion_id is null
        and legacy_record_id is not null
        and legacy_identity is not null
        and jsonb_typeof(legacy_identity) = 'object'
        and is_primary = false
      )
      or
      (
        status in ('active', 'archived')
        and companion_id is not null
        and legacy_identity is null
      )
    ),
  constraint user_companion_relationships_primary_is_active
    check (not is_primary or status = 'active'),
  constraint user_companion_relationships_support_preferences
    check (
      jsonb_typeof(support_preferences) = 'object'
      and (support_preferences - array['tone', 'directness', 'length', 'topics']) = '{}'::jsonb
      and (
        not (support_preferences ? 'tone')
        or jsonb_typeof(support_preferences -> 'tone') = 'string'
      )
      and (
        not (support_preferences ? 'directness')
        or jsonb_typeof(support_preferences -> 'directness') = 'string'
      )
      and (
        not (support_preferences ? 'length')
        or jsonb_typeof(support_preferences -> 'length') = 'string'
      )
      and (
        not (support_preferences ? 'topics')
        or jsonb_typeof(support_preferences -> 'topics') = 'array'
      )
    ),
  constraint user_companion_relationships_migration_consent
    check (
      (
        legacy_record_id is null
        and migration_version is null
        and sync_consent_at is null
      )
      or
      (
        legacy_record_id is not null
        and migration_version >= 1
        and sync_consent_at is not null
      )
    ),
  constraint user_companion_relationships_owner_unique
    unique (id, user_id),
  constraint user_companion_relationships_owner_identity_unique
    unique (id, user_id, companion_id)
);

comment on table public.user_companion_relationships is
  'Owner-scoped companion relationships. Canonical and unmatched legacy identities are never inferred from sign or display name.';
comment on column public.user_companion_relationships.support_preferences is
  'User calibration is deliberately limited to tone, directness, length, and topic preferences.';

create unique index user_companion_relationships_one_primary_idx
  on public.user_companion_relationships (user_id)
  where is_primary;
create unique index user_companion_relationships_companion_idx
  on public.user_companion_relationships (user_id, companion_id)
  where companion_id is not null;
create unique index user_companion_relationships_legacy_idx
  on public.user_companion_relationships (user_id, legacy_record_id)
  where legacy_record_id is not null;
create index user_companion_relationships_user_status_idx
  on public.user_companion_relationships (user_id, status, updated_at desc);

create table public.companion_conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  relationship_id uuid not null references public.user_companion_relationships(id) on delete cascade,
  companion_id text references public.companion_personas(id) on delete restrict,
  status text not null default 'active',
  title text,
  persona_version text,
  legacy_record_id text,
  migration_version integer,
  sync_consent_at timestamptz,
  last_message_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint companion_conversations_status
    check (status in ('active', 'archived', 'legacy_read_only')),
  constraint companion_conversations_title_length
    check (title is null or length(trim(title)) between 1 and 160),
  constraint companion_conversations_identity
    check (
      (
        status = 'legacy_read_only'
        and companion_id is null
        and persona_version is null
        and legacy_record_id is not null
      )
      or
      (
        status in ('active', 'archived')
        and companion_id is not null
        and persona_version is not null
        and length(trim(persona_version)) between 1 and 120
      )
    ),
  constraint companion_conversations_migration_consent
    check (
      (
        legacy_record_id is null
        and migration_version is null
        and sync_consent_at is null
      )
      or
      (
        legacy_record_id is not null
        and migration_version >= 1
        and sync_consent_at is not null
      )
    ),
  constraint companion_conversations_relationship_owner_fk
    foreign key (relationship_id, user_id, companion_id)
    references public.user_companion_relationships(id, user_id, companion_id)
    on delete cascade,
  constraint companion_conversations_relationship_user_fk
    foreign key (relationship_id, user_id)
    references public.user_companion_relationships(id, user_id)
    on delete cascade,
  constraint companion_conversations_owner_unique
    unique (id, user_id),
  constraint companion_conversations_owner_identity_unique
    unique (id, user_id, companion_id)
);

comment on table public.companion_conversations is
  'Conversation threads remain isolated by canonical companion relationship. Legacy imports are explicitly read-only.';

create unique index companion_conversations_legacy_idx
  on public.companion_conversations (user_id, legacy_record_id)
  where legacy_record_id is not null;
create index companion_conversations_user_companion_idx
  on public.companion_conversations (user_id, companion_id, last_message_at desc nulls last);
create index companion_conversations_relationship_idx
  on public.companion_conversations (relationship_id, updated_at desc);

create table public.companion_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.companion_conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  companion_id text references public.companion_personas(id) on delete restrict,
  client_message_id uuid not null,
  role text not null,
  content text not null,
  persona_version text,
  model_provider text,
  model_version text,
  delivery_state text not null default 'complete',
  safety_metadata jsonb not null default '{}'::jsonb,
  is_legacy_import boolean not null default false,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint companion_messages_role
    check (role in ('user', 'companion')),
  constraint companion_messages_content_length
    check (length(trim(content)) between 1 and 50000),
  constraint companion_messages_delivery_state
    check (delivery_state in ('pending', 'streaming', 'complete', 'failed')),
  constraint companion_messages_safety_metadata
    check (jsonb_typeof(safety_metadata) = 'object'),
  constraint companion_messages_identity
    check (
      (
        is_legacy_import
        and (
          (
            companion_id is null
            and persona_version is null
          )
          or
          (
            companion_id is not null
            and persona_version = 'legacy-unversioned'
          )
        )
      )
      or
      (
        not is_legacy_import
        and companion_id is not null
        and persona_version is not null
        and length(trim(persona_version)) between 1 and 120
        and persona_version <> 'legacy-unversioned'
      )
    ),
  constraint companion_messages_model_provenance
    check (
      (
        role = 'user'
        and model_provider is null
        and model_version is null
      )
      or
      (
        role = 'companion'
        and (
          is_legacy_import
          or (
            model_provider is not null
            and length(trim(model_provider)) between 1 and 80
            and model_version is not null
            and length(trim(model_version)) between 1 and 160
          )
        )
      )
    ),
  constraint companion_messages_conversation_owner_fk
    foreign key (conversation_id, user_id, companion_id)
    references public.companion_conversations(id, user_id, companion_id)
    on delete cascade,
  constraint companion_messages_conversation_user_fk
    foreign key (conversation_id, user_id)
    references public.companion_conversations(id, user_id)
    on delete cascade,
  constraint companion_messages_client_role_unique
    unique (user_id, client_message_id, role),
  constraint companion_messages_owner_unique
    unique (id, user_id),
  constraint companion_messages_owner_identity_unique
    unique (id, user_id, companion_id)
);

comment on column public.companion_messages.client_message_id is
  'Globally user-scoped idempotency key for one turn. The role permits one request and one response per key.';
comment on column public.companion_messages.persona_version is
  'Approved server persona version resolved for this turn, or the reserved legacy-unversioned marker for a consented canonical import; never a raw client prompt.';
comment on column public.companion_messages.is_legacy_import is
  'True only for consented device imports. Canonical imports retain companion_id and use persona_version legacy-unversioned; unmatched custom records retain neither identity field.';

create index companion_messages_conversation_created_idx
  on public.companion_messages (conversation_id, created_at, id);
create index companion_messages_user_created_idx
  on public.companion_messages (user_id, created_at desc);

create table public.companion_memories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  scope text not null,
  companion_id text references public.companion_personas(id) on delete restrict,
  relationship_id uuid references public.user_companion_relationships(id) on delete cascade,
  memory_kind text not null,
  content text not null,
  source text not null,
  source_id uuid,
  is_sensitive boolean not null default false,
  consent_confirmed_at timestamptz,
  edit_revision integer not null default 0,
  edited_at timestamptz,
  deleted_at timestamptz,
  legacy_record_id text,
  migration_version integer,
  sync_consent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint companion_memories_scope
    check (scope in ('shared_user_fact', 'persona_relationship')),
  constraint companion_memories_scope_identity
    check (
      (
        scope = 'shared_user_fact'
        and companion_id is null
        and relationship_id is null
      )
      or
      (
        scope = 'persona_relationship'
        and companion_id is not null
        and relationship_id is not null
      )
    ),
  constraint companion_memories_kind_length
    check (length(trim(memory_kind)) between 1 and 80),
  constraint companion_memories_content_length
    check (length(trim(content)) between 1 and 2000),
  constraint companion_memories_source
    check (source in (
      'user_explicit', 'user_correction', 'conversation_confirmed',
      'outcome_recorded', 'legacy_import'
    )),
  constraint companion_memories_sensitive_consent
    check (not is_sensitive or consent_confirmed_at is not null),
  constraint companion_memories_edit_revision
    check (edit_revision >= 0),
  constraint companion_memories_migration_consent
    check (
      (
        legacy_record_id is null
        and migration_version is null
        and sync_consent_at is null
      )
      or
      (
        legacy_record_id is not null
        and migration_version >= 1
        and sync_consent_at is not null
        and source = 'legacy_import'
      )
    ),
  constraint companion_memories_relationship_owner_fk
    foreign key (relationship_id, user_id, companion_id)
    references public.user_companion_relationships(id, user_id, companion_id)
    on delete cascade,
  constraint companion_memories_relationship_user_fk
    foreign key (relationship_id, user_id)
    references public.user_companion_relationships(id, user_id)
    on delete cascade
);

comment on table public.companion_memories is
  'Editable, deletable memories separated into shared user facts and persona-specific relationship context.';
comment on column public.companion_memories.source is
  'Inference-only sources are deliberately unsupported; conversation memories require confirmation.';

create unique index companion_memories_legacy_idx
  on public.companion_memories (user_id, legacy_record_id)
  where legacy_record_id is not null;
create index companion_memories_user_active_idx
  on public.companion_memories (user_id, scope, updated_at desc)
  where deleted_at is null;
create index companion_memories_relationship_idx
  on public.companion_memories (relationship_id, updated_at desc)
  where relationship_id is not null and deleted_at is null;

create table public.relationship_people (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  display_name text not null,
  relationship_kind text,
  pronouns text,
  birth_date date,
  birth_time time without time zone,
  birth_time_precision text,
  birth_place text,
  time_zone_identifier text,
  latitude double precision,
  longitude double precision,
  birth_chart jsonb,
  notes text,
  communication_guide jsonb,
  ai_context_enabled boolean not null default true,
  record_source text not null default 'app_entry',
  legacy_record_id text,
  migration_version integer,
  sync_consent_at timestamptz,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint relationship_people_display_name_length
    check (length(trim(display_name)) between 1 and 120),
  constraint relationship_people_relationship_kind_length
    check (relationship_kind is null or length(trim(relationship_kind)) between 1 and 80),
  constraint relationship_people_birth_time_precision
    check (birth_time_precision is null or birth_time_precision in ('exact', 'approximate', 'unknown')),
  constraint relationship_people_birth_time_consistency
    check (
      (birth_time_precision is null and birth_time is null)
      or (birth_time_precision = 'unknown' and birth_time is null)
      or (birth_time_precision in ('exact', 'approximate') and birth_time is not null)
    ),
  constraint relationship_people_birth_place_length
    check (birth_place is null or length(trim(birth_place)) between 1 and 240),
  constraint relationship_people_time_zone_length
    check (time_zone_identifier is null or length(trim(time_zone_identifier)) between 1 and 100),
  constraint relationship_people_coordinates
    check (
      (latitude is null and longitude is null)
      or (latitude between -90 and 90 and longitude between -180 and 180)
    ),
  constraint relationship_people_birth_chart_object
    check (birth_chart is null or jsonb_typeof(birth_chart) = 'object'),
  constraint relationship_people_communication_guide_object
    check (communication_guide is null or jsonb_typeof(communication_guide) = 'object'),
  constraint relationship_people_notes_length
    check (notes is null or length(notes) <= 10000),
  constraint relationship_people_record_source
    check (record_source in ('app_entry', 'local_migration')),
  constraint relationship_people_migration_consent
    check (
      (
        record_source = 'app_entry'
        and legacy_record_id is null
        and migration_version is null
        and sync_consent_at is null
      )
      or
      (
        record_source = 'local_migration'
        and legacy_record_id is not null
        and migration_version >= 1
        and sync_consent_at is not null
      )
    ),
  constraint relationship_people_owner_identity_unique
    unique (id, user_id)
);

comment on table public.relationship_people is
  'Private structured People records. Raw third-party message text has no persistence column by design.';

create unique index relationship_people_legacy_idx
  on public.relationship_people (user_id, legacy_record_id)
  where legacy_record_id is not null;
create index relationship_people_user_active_idx
  on public.relationship_people (user_id, display_name)
  where archived_at is null;

create table public.communication_outcomes (
  id uuid primary key default gen_random_uuid(),
  client_outcome_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  companion_id text not null references public.companion_personas(id) on delete restrict,
  relationship_id uuid not null references public.user_companion_relationships(id) on delete cascade,
  person_id uuid references public.relationship_people(id) on delete set null,
  conversation_id uuid references public.companion_conversations(id) on delete set null,
  follow_up_message_id uuid references public.companion_messages(id) on delete set null,
  action_text text not null,
  action_state text not null default 'planned',
  planned_for timestamptz,
  acted_at timestamptz,
  result_kind text,
  result_summary text,
  result_source text,
  result_recorded_at timestamptz,
  follow_up_state text not null default 'not_scheduled',
  follow_up_due_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint communication_outcomes_action_length
    check (length(trim(action_text)) between 1 and 4000),
  constraint communication_outcomes_action_state
    check (action_state in ('planned', 'completed', 'cancelled')),
  constraint communication_outcomes_acted_at_consistency
    check (action_state <> 'completed' or acted_at is not null),
  constraint communication_outcomes_result_kind
    check (result_kind is null or result_kind in (
      'better', 'mixed', 'worse', 'no_response', 'other'
    )),
  constraint communication_outcomes_result_summary_length
    check (result_summary is null or length(trim(result_summary)) between 1 and 4000),
  constraint communication_outcomes_result_is_user_recorded
    check (
      (
        result_recorded_at is null
        and result_kind is null
        and result_summary is null
        and result_source is null
      )
      or
      (
        result_recorded_at is not null
        and result_source = 'user_recorded'
        and (result_kind is not null or result_summary is not null)
      )
    ),
  constraint communication_outcomes_follow_up_state
    check (follow_up_state in (
      'not_scheduled', 'scheduled', 'due', 'delivered', 'dismissed'
    )),
  constraint communication_outcomes_follow_up_due
    check (
      follow_up_state not in ('scheduled', 'due')
      or follow_up_due_at is not null
    ),
  constraint communication_outcomes_follow_up_delivery
    check (
      follow_up_state <> 'delivered'
      or follow_up_message_id is not null
    ),
  constraint communication_outcomes_relationship_owner_fk
    foreign key (relationship_id, user_id, companion_id)
    references public.user_companion_relationships(id, user_id, companion_id)
    on delete cascade,
  constraint communication_outcomes_relationship_user_fk
    foreign key (relationship_id, user_id)
    references public.user_companion_relationships(id, user_id)
    on delete cascade,
  constraint communication_outcomes_person_owner_fk
    foreign key (person_id, user_id)
    references public.relationship_people(id, user_id),
  constraint communication_outcomes_conversation_owner_fk
    foreign key (conversation_id, user_id, companion_id)
    references public.companion_conversations(id, user_id, companion_id),
  constraint communication_outcomes_conversation_user_fk
    foreign key (conversation_id, user_id)
    references public.companion_conversations(id, user_id),
  constraint communication_outcomes_follow_up_message_owner_fk
    foreign key (follow_up_message_id, user_id, companion_id)
    references public.companion_messages(id, user_id, companion_id),
  constraint communication_outcomes_follow_up_message_user_fk
    foreign key (follow_up_message_id, user_id)
    references public.companion_messages(id, user_id),
  constraint communication_outcomes_client_unique
    unique (user_id, client_outcome_id)
);

comment on table public.communication_outcomes is
  'Explicit offline communication actions, user-recorded results, and transparent follow-up state.';
comment on column public.communication_outcomes.result_source is
  'Must be user_recorded whenever a result exists; companions cannot silently infer an outcome.';

create index communication_outcomes_user_follow_up_idx
  on public.communication_outcomes (user_id, follow_up_state, follow_up_due_at);
create index communication_outcomes_person_idx
  on public.communication_outcomes (person_id, created_at desc)
  where person_id is not null;
create index communication_outcomes_relationship_idx
  on public.communication_outcomes (relationship_id, created_at desc);

create or replace function public.companion_set_updated_at()
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

create or replace function public.companion_memory_track_edit()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.content is distinct from old.content then
    new.edit_revision = old.edit_revision + 1;
    new.edited_at = now();
  else
    new.edit_revision = old.edit_revision;
    new.edited_at = old.edited_at;
  end if;
  return new;
end;
$$;

create trigger set_companion_personas_updated_at
before update on public.companion_personas
for each row execute function public.companion_set_updated_at();

create trigger set_user_companion_relationships_updated_at
before update on public.user_companion_relationships
for each row execute function public.companion_set_updated_at();

create trigger set_companion_conversations_updated_at
before update on public.companion_conversations
for each row execute function public.companion_set_updated_at();

create trigger set_companion_messages_updated_at
before update on public.companion_messages
for each row execute function public.companion_set_updated_at();

create trigger set_companion_memories_updated_at
before update on public.companion_memories
for each row execute function public.companion_set_updated_at();

create trigger track_companion_memory_edit
before update on public.companion_memories
for each row execute function public.companion_memory_track_edit();

create trigger set_relationship_people_updated_at
before update on public.relationship_people
for each row execute function public.companion_set_updated_at();

create trigger set_communication_outcomes_updated_at
before update on public.communication_outcomes
for each row execute function public.companion_set_updated_at();

-- Trigger helpers are not callable Data API endpoints.
revoke all on function public.companion_set_updated_at()
  from public, anon, authenticated, service_role;
revoke all on function public.companion_memory_track_edit()
  from public, anon, authenticated, service_role;

alter table public.companion_personas enable row level security;
alter table public.user_companion_relationships enable row level security;
alter table public.companion_conversations enable row level security;
alter table public.companion_messages enable row level security;
alter table public.companion_memories enable row level security;
alter table public.relationship_people enable row level security;
alter table public.communication_outcomes enable row level security;

-- New public tables are no longer automatically exposed in current Supabase
-- projects. Revoke any legacy defaults first, then opt each role into the
-- minimum Data API surface it needs. RLS remains the row-level boundary.
revoke all on table public.companion_personas
  from public, anon, authenticated, service_role;
revoke all on table public.user_companion_relationships
  from public, anon, authenticated, service_role;
revoke all on table public.companion_conversations
  from public, anon, authenticated, service_role;
revoke all on table public.companion_messages
  from public, anon, authenticated, service_role;
revoke all on table public.companion_memories
  from public, anon, authenticated, service_role;
revoke all on table public.relationship_people
  from public, anon, authenticated, service_role;
revoke all on table public.communication_outcomes
  from public, anon, authenticated, service_role;

grant select on table public.companion_personas to anon, authenticated;

grant select, insert, delete on table public.user_companion_relationships to authenticated;
grant update (status, is_primary, support_preferences, last_interaction_at)
  on table public.user_companion_relationships to authenticated;

grant select, delete on table public.companion_conversations to authenticated;
grant update (status, title, last_message_at)
  on table public.companion_conversations to authenticated;

grant select, delete on table public.companion_messages to authenticated;

grant select, insert, delete on table public.companion_memories to authenticated;
grant update (content, is_sensitive, consent_confirmed_at, deleted_at)
  on table public.companion_memories to authenticated;

grant select, insert, delete on table public.relationship_people to authenticated;
grant update (
  display_name,
  relationship_kind,
  pronouns,
  birth_date,
  birth_time,
  birth_time_precision,
  birth_place,
  time_zone_identifier,
  latitude,
  longitude,
  birth_chart,
  notes,
  communication_guide,
  ai_context_enabled,
  archived_at
) on table public.relationship_people to authenticated;

grant select, insert, delete on table public.communication_outcomes to authenticated;
grant update (
  action_text,
  action_state,
  planned_for,
  acted_at,
  result_kind,
  result_summary,
  result_source,
  result_recorded_at,
  follow_up_state,
  follow_up_due_at
) on table public.communication_outcomes to authenticated;

grant select, insert, update, delete on table public.companion_personas to service_role;
grant select, insert, update, delete on table public.user_companion_relationships to service_role;
grant select, insert, update, delete on table public.companion_conversations to service_role;
grant select, insert, update, delete on table public.companion_messages to service_role;
grant select, insert, update, delete on table public.companion_memories to service_role;
grant select, insert, update, delete on table public.relationship_people to service_role;
grant select, insert, update, delete on table public.communication_outcomes to service_role;

create policy "Released companion personas are publicly readable"
on public.companion_personas
for select
to anon, authenticated
using (status in ('pilot_ready', 'active'));

create policy "Users can view their companion relationships"
on public.user_companion_relationships
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can create their companion relationships"
on public.user_companion_relationships
for insert
to authenticated
with check (
  (select auth.uid()) = user_id
  and (
    (
      status in ('active', 'archived')
      and exists (
        select 1
        from public.companion_personas persona
        where persona.id = user_companion_relationships.companion_id
          and persona.status in ('pilot_ready', 'active')
      )
    )
    or status = 'legacy_read_only'
  )
);

create policy "Users can update their companion relationships"
on public.user_companion_relationships
for update
to authenticated
using ((select auth.uid()) = user_id)
with check (
  (select auth.uid()) = user_id
  and (
    (
      status in ('active', 'archived')
      and exists (
        select 1
        from public.companion_personas persona
        where persona.id = user_companion_relationships.companion_id
          and persona.status in ('pilot_ready', 'active')
      )
    )
    or status = 'legacy_read_only'
  )
);

create policy "Users can delete their companion relationships"
on public.user_companion_relationships
for delete
to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can view their companion conversations"
on public.companion_conversations
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can update their companion conversations"
on public.companion_conversations
for update
to authenticated
using ((select auth.uid()) = user_id)
with check (
  (select auth.uid()) = user_id
  and exists (
    select 1
    from public.user_companion_relationships relationship
    where relationship.id = companion_conversations.relationship_id
      and relationship.user_id = (select auth.uid())
      and relationship.companion_id is not distinct from companion_conversations.companion_id
      and (
        (relationship.status in ('active', 'archived') and companion_conversations.status in ('active', 'archived'))
        or (relationship.status = 'legacy_read_only' and companion_conversations.status = 'legacy_read_only')
      )
  )
);

create policy "Users can delete their companion conversations"
on public.companion_conversations
for delete
to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can view their companion messages"
on public.companion_messages
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can delete their companion messages"
on public.companion_messages
for delete
to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can view their companion memories"
on public.companion_memories
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can create their companion memories"
on public.companion_memories
for insert
to authenticated
with check (
  (select auth.uid()) = user_id
  and (
    scope = 'shared_user_fact'
    or exists (
      select 1
      from public.user_companion_relationships relationship
      where relationship.id = companion_memories.relationship_id
        and relationship.user_id = (select auth.uid())
        and relationship.companion_id = companion_memories.companion_id
        and relationship.status in ('active', 'archived')
    )
  )
);

create policy "Users can update their companion memories"
on public.companion_memories
for update
to authenticated
using ((select auth.uid()) = user_id)
with check (
  (select auth.uid()) = user_id
  and (
    scope = 'shared_user_fact'
    or exists (
      select 1
      from public.user_companion_relationships relationship
      where relationship.id = companion_memories.relationship_id
        and relationship.user_id = (select auth.uid())
        and relationship.companion_id = companion_memories.companion_id
        and relationship.status in ('active', 'archived')
    )
  )
);

create policy "Users can delete their companion memories"
on public.companion_memories
for delete
to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can view their relationship people"
on public.relationship_people
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can create their relationship people"
on public.relationship_people
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "Users can update their relationship people"
on public.relationship_people
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "Users can delete their relationship people"
on public.relationship_people
for delete
to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can view their communication outcomes"
on public.communication_outcomes
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can create their communication outcomes"
on public.communication_outcomes
for insert
to authenticated
with check (
  (select auth.uid()) = user_id
  and exists (
    select 1
    from public.user_companion_relationships relationship
    where relationship.id = communication_outcomes.relationship_id
      and relationship.user_id = (select auth.uid())
      and relationship.companion_id = communication_outcomes.companion_id
      and relationship.status in ('active', 'archived')
  )
  and (
    person_id is null
    or exists (
      select 1
      from public.relationship_people person
      where person.id = communication_outcomes.person_id
        and person.user_id = (select auth.uid())
    )
  )
  and (
    conversation_id is null
    or exists (
      select 1
      from public.companion_conversations conversation
      where conversation.id = communication_outcomes.conversation_id
        and conversation.user_id = (select auth.uid())
        and conversation.companion_id = communication_outcomes.companion_id
    )
  )
);

create policy "Users can update their communication outcomes"
on public.communication_outcomes
for update
to authenticated
using ((select auth.uid()) = user_id)
with check (
  (select auth.uid()) = user_id
  and exists (
    select 1
    from public.user_companion_relationships relationship
    where relationship.id = communication_outcomes.relationship_id
      and relationship.user_id = (select auth.uid())
      and relationship.companion_id = communication_outcomes.companion_id
      and relationship.status in ('active', 'archived')
  )
  and (
    person_id is null
    or exists (
      select 1
      from public.relationship_people person
      where person.id = communication_outcomes.person_id
        and person.user_id = (select auth.uid())
    )
  )
  and (
    conversation_id is null
    or exists (
      select 1
      from public.companion_conversations conversation
      where conversation.id = communication_outcomes.conversation_id
        and conversation.user_id = (select auth.uid())
        and conversation.companion_id = communication_outcomes.companion_id
    )
  )
);

create policy "Users can delete their communication outcomes"
on public.communication_outcomes
for delete
to authenticated
using ((select auth.uid()) = user_id);

-- Account-scoped expert archive deletion. The function has no user-id input,
-- runs with the caller's privileges, and therefore keeps every existing table
-- RLS policy in force. All row deletes happen in the RPC transaction. Storage
-- object paths are returned for deletion through the Storage API; deleting
-- storage.objects directly in SQL could orphan the underlying files.
create or replace function public.delete_current_user_expert_archive()
returns table (
  consultation_responses_deleted bigint,
  consultations_deleted bigint,
  messages_deleted bigint,
  conversations_deleted bigint,
  person_intakes_deleted bigint,
  chart_imports_deleted bigint,
  self_intakes_deleted bigint,
  chart_storage_paths text[]
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  archive_owner_id uuid := (select auth.uid());
begin
  if archive_owner_id is null then
    raise exception 'Authentication is required to delete an expert archive.'
      using errcode = '42501';
  end if;

  select coalesce(array_agg(chart_import.storage_path order by chart_import.storage_path), '{}'::text[])
  into chart_storage_paths
  from public.expert_astrology_chart_imports chart_import
  where chart_import.user_id = archive_owner_id;

  delete from public.expert_astrologer_consultation_responses response
  where response.user_id = archive_owner_id;
  get diagnostics consultation_responses_deleted = row_count;

  delete from public.expert_astrologer_messages message
  where message.user_id = archive_owner_id;
  get diagnostics messages_deleted = row_count;

  -- Delete this referencing table before its optional chart import parent.
  delete from public.expert_person_astrology_intake person_intake
  where person_intake.user_id = archive_owner_id;
  get diagnostics person_intakes_deleted = row_count;

  delete from public.expert_astrologer_consultations consultation
  where consultation.user_id = archive_owner_id;
  get diagnostics consultations_deleted = row_count;

  delete from public.expert_astrologer_conversations conversation
  where conversation.user_id = archive_owner_id;
  get diagnostics conversations_deleted = row_count;

  delete from public.expert_astrology_chart_imports chart_import
  where chart_import.user_id = archive_owner_id;
  get diagnostics chart_imports_deleted = row_count;

  delete from public.expert_astrology_intake self_intake
  where self_intake.user_id = archive_owner_id;
  get diagnostics self_intakes_deleted = row_count;

  return next;
end;
$$;

comment on function public.delete_current_user_expert_archive() is
  'Atomically deletes only auth.uid-owned expert archive rows and returns deletion counts plus user-owned chart storage paths for Storage API cleanup.';

revoke all on function public.delete_current_user_expert_archive()
  from public, anon, authenticated, service_role;
grant execute on function public.delete_current_user_expert_archive()
  to authenticated;
