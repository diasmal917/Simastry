alter table public.profiles
  add column if not exists daily_messages_used integer default 0,
  add column if not exists daily_messages_reset_date timestamp with time zone,
  add column if not exists weekly_predictions_used integer default 0,
  add column if not exists weekly_predictions_reset_date timestamp with time zone;

update public.profiles
set daily_messages_used = coalesce(daily_messages_used, 0),
    weekly_predictions_used = coalesce(weekly_predictions_used, 0)
where daily_messages_used is null
   or weekly_predictions_used is null;
