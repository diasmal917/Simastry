create table if not exists public.guide_feedback_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  ai_usage_event_id uuid references public.ai_usage_events(id) on delete set null,
  read_id uuid not null,
  guide_id text,
  surface text not null,
  helpfulness text not null,
  reasons text[] not null default '{}',
  freeform_note text,
  created_at timestamptz not null default now(),
  synced_at timestamptz not null default now(),
  constraint guide_feedback_surface_check check (
    surface in ('firstRead', 'panelChat', 'guideCard', 'replyOption')
  ),
  constraint guide_feedback_helpfulness_check check (
    helpfulness in ('helpful', 'partlyHelpful', 'notHelpful')
  ),
  constraint guide_feedback_reasons_check check (
    reasons <@ array[
      'tooVague',
      'tooIntense',
      'tooMystical',
      'notPractical',
      'wrongTone',
      'missedContext',
      'replyDidntSoundLikeMe',
      'tooLong',
      'tooSoft',
      'tooHarsh'
    ]::text[]
  ),
  constraint guide_feedback_note_length_check check (
    freeform_note is null or char_length(freeform_note) <= 500
  )
);

create index if not exists guide_feedback_events_user_created_idx
  on public.guide_feedback_events (user_id, created_at desc);

create index if not exists guide_feedback_events_user_guide_created_idx
  on public.guide_feedback_events (user_id, guide_id, created_at desc);

create index if not exists guide_feedback_events_ai_usage_idx
  on public.guide_feedback_events (ai_usage_event_id)
  where ai_usage_event_id is not null;

alter table public.guide_feedback_events enable row level security;

drop policy if exists "Users can read own AI usage events" on public.ai_usage_events;
create policy "Users can read own AI usage events"
  on public.ai_usage_events
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

grant select on table public.ai_usage_events to authenticated;

drop policy if exists "Users can read own guide feedback" on public.guide_feedback_events;
create policy "Users can read own guide feedback"
  on public.guide_feedback_events
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert own guide feedback" on public.guide_feedback_events;
create policy "Users can insert own guide feedback"
  on public.guide_feedback_events
  for insert
  to authenticated
  with check (
    (select auth.uid()) = user_id
    and (
      ai_usage_event_id is null
      or exists (
        select 1
        from public.ai_usage_events
        where ai_usage_events.id = guide_feedback_events.ai_usage_event_id
          and ai_usage_events.user_id = (select auth.uid())
      )
    )
  );

drop policy if exists "Users can update own guide feedback" on public.guide_feedback_events;
create policy "Users can update own guide feedback"
  on public.guide_feedback_events
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and (
      ai_usage_event_id is null
      or exists (
        select 1
        from public.ai_usage_events
        where ai_usage_events.id = guide_feedback_events.ai_usage_event_id
          and ai_usage_events.user_id = (select auth.uid())
      )
    )
  );

drop policy if exists "Users can delete own guide feedback" on public.guide_feedback_events;
create policy "Users can delete own guide feedback"
  on public.guide_feedback_events
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

revoke all on table public.guide_feedback_events from anon;
revoke all on table public.guide_feedback_events from authenticated;
revoke all on table public.guide_feedback_events from service_role;

grant select, insert, update, delete on table public.guide_feedback_events to authenticated;
grant select, insert, update, delete on table public.guide_feedback_events to service_role;

create or replace function public.sync_guide_feedback_event(
  p_id uuid,
  p_ai_usage_event_id uuid,
  p_read_id uuid,
  p_guide_id text,
  p_surface text,
  p_helpfulness text,
  p_reasons text[],
  p_freeform_note text,
  p_created_at timestamptz
)
returns public.guide_feedback_events
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_row public.guide_feedback_events;
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  if p_id is null or p_read_id is null then
    raise exception 'feedback id and read id are required';
  end if;

  if p_ai_usage_event_id is not null and not exists (
    select 1
    from public.ai_usage_events
    where ai_usage_events.id = p_ai_usage_event_id
      and ai_usage_events.user_id = v_user_id
  ) then
    raise exception 'ai_usage_event_not_owned';
  end if;

  delete from public.guide_feedback_events
  where user_id = v_user_id
    and read_id = p_read_id
    and coalesce(guide_id, '') = coalesce(p_guide_id, '')
    and surface = p_surface
    and id <> p_id;

  insert into public.guide_feedback_events (
    id,
    user_id,
    ai_usage_event_id,
    read_id,
    guide_id,
    surface,
    helpfulness,
    reasons,
    freeform_note,
    created_at,
    synced_at
  )
  values (
    p_id,
    v_user_id,
    p_ai_usage_event_id,
    p_read_id,
    nullif(trim(coalesce(p_guide_id, '')), ''),
    p_surface,
    p_helpfulness,
    coalesce(p_reasons, '{}'::text[]),
    nullif(left(coalesce(p_freeform_note, ''), 500), ''),
    coalesce(p_created_at, now()),
    now()
  )
  on conflict (id) do update
  set ai_usage_event_id = excluded.ai_usage_event_id,
      guide_id = excluded.guide_id,
      surface = excluded.surface,
      helpfulness = excluded.helpfulness,
      reasons = excluded.reasons,
      freeform_note = excluded.freeform_note,
      synced_at = now()
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.sync_guide_feedback_event(
  uuid,
  uuid,
  uuid,
  text,
  text,
  text,
  text[],
  text,
  timestamptz
) to authenticated;
