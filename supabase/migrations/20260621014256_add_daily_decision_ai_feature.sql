alter table public.ai_usage_events
  drop constraint if exists ai_usage_events_feature_check;

alter table public.ai_usage_events
  add constraint ai_usage_events_feature_check check (
    feature in (
      'panel_chat',
      'companion_chat',
      'prediction',
      'practice',
      'playbook',
      'moment_comment',
      'daily_decision'
    )
  );

create or replace function private.reserve_ai_usage(
  p_user_id uuid,
  p_feature text,
  p_model text,
  p_request_max_tokens integer
)
returns table (
  allowed boolean,
  event_id uuid,
  reason text,
  tier text,
  minute_used integer,
  hour_used integer,
  daily_used integer,
  daily_limit integer
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_tier text;
  v_minute_used integer;
  v_hour_used integer;
  v_daily_used integer;
  v_daily_limit integer;
  v_reason text;
  v_event_id uuid;
begin
  if p_user_id is null then
    raise exception 'user_id is required';
  end if;

  if p_feature not in (
    'panel_chat',
    'companion_chat',
    'prediction',
    'practice',
    'playbook',
    'moment_comment',
    'daily_decision'
  ) then
    raise exception 'invalid ai usage feature: %', p_feature;
  end if;

  perform pg_advisory_xact_lock(hashtext(p_user_id::text));

  select lower(coalesce(profiles.tier, 'free'))
    into v_tier
  from public.profiles
  where profiles.id = p_user_id;

  v_tier := coalesce(v_tier, 'free');
  v_daily_limit := case v_tier
    when 'pro' then 100
    when 'plus' then 40
    else 5
  end;

  select count(*)::integer
    into v_minute_used
  from public.ai_usage_events
  where user_id = p_user_id
    and status in ('reserved', 'success', 'failed')
    and created_at >= now() - interval '1 minute';

  select count(*)::integer
    into v_hour_used
  from public.ai_usage_events
  where user_id = p_user_id
    and status in ('reserved', 'success', 'failed')
    and created_at >= now() - interval '1 hour';

  select count(*)::integer
    into v_daily_used
  from public.ai_usage_events
  where user_id = p_user_id
    and status in ('reserved', 'success', 'failed')
    and created_at >= date_trunc('day', now());

  if v_minute_used >= 3 then
    v_reason := 'minute_limit';
  elsif v_hour_used >= 30 then
    v_reason := 'hour_limit';
  elsif v_daily_used >= v_daily_limit then
    v_reason := 'daily_limit';
  end if;

  if v_reason is not null then
    return query select
      false as allowed,
      null::uuid as event_id,
      v_reason as reason,
      v_tier as tier,
      v_minute_used as minute_used,
      v_hour_used as hour_used,
      v_daily_used as daily_used,
      v_daily_limit as daily_limit;
    return;
  end if;

  insert into public.ai_usage_events (
    user_id,
    feature,
    model,
    status,
    request_max_tokens,
    error_type
  )
  values (
    p_user_id,
    p_feature,
    coalesce(nullif(trim(p_model), ''), 'unknown'),
    'reserved',
    greatest(coalesce(p_request_max_tokens, 0), 0),
    null
  )
  returning id into v_event_id;

  return query select
    true as allowed,
    v_event_id as event_id,
    v_reason as reason,
    v_tier as tier,
    v_minute_used as minute_used,
    v_hour_used as hour_used,
    v_daily_used as daily_used,
    v_daily_limit as daily_limit;
end;
$$;

grant execute on function private.reserve_ai_usage(uuid, text, text, integer) to service_role;

revoke execute on function private.reserve_ai_usage(uuid, text, text, integer) from public;
revoke execute on function private.reserve_ai_usage(uuid, text, text, integer) from anon;
revoke execute on function private.reserve_ai_usage(uuid, text, text, integer) from authenticated;
