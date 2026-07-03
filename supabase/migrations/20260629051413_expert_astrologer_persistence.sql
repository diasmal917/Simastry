create table if not exists public.expert_astrologer_conversations (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  specialist_id text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_message_at timestamptz
);

create table if not exists public.expert_astrologer_messages (
  id uuid primary key,
  conversation_id uuid not null references public.expert_astrologer_conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  specialist_id text not null,
  role text not null check (role in ('user', 'specialist')),
  content text not null check (length(trim(content)) > 0),
  mode text not null default 'individual' check (mode in ('individual', 'everyone')),
  multi_consultation_id uuid,
  profile_context_summary text,
  created_at timestamptz not null default now()
);

create table if not exists public.expert_astrologer_consultations (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  mode text not null default 'everyone' check (mode = 'everyone'),
  user_question text not null check (length(trim(user_question)) > 0),
  profile_context_summary text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.expert_astrologer_consultation_responses (
  id uuid primary key,
  multi_consultation_id uuid not null references public.expert_astrologer_consultations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  specialist_id text not null,
  user_question text not null check (length(trim(user_question)) > 0),
  specialist_response text,
  error_message text,
  mode text not null default 'everyone' check (mode = 'everyone'),
  profile_context_summary text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (multi_consultation_id, specialist_id)
);

create index if not exists expert_astrologer_conversations_user_idx
  on public.expert_astrologer_conversations(user_id, updated_at desc);

create index if not exists expert_astrologer_messages_user_conversation_idx
  on public.expert_astrologer_messages(user_id, conversation_id, created_at asc);

create index if not exists expert_astrologer_consultations_user_idx
  on public.expert_astrologer_consultations(user_id, updated_at desc);

create index if not exists expert_astrologer_consultation_responses_user_idx
  on public.expert_astrologer_consultation_responses(user_id, multi_consultation_id, specialist_id);

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

drop trigger if exists set_expert_astrologer_conversations_updated_at
  on public.expert_astrologer_conversations;
create trigger set_expert_astrologer_conversations_updated_at
before update on public.expert_astrologer_conversations
for each row execute function public.expert_astrologers_set_updated_at();

drop trigger if exists set_expert_astrologer_consultations_updated_at
  on public.expert_astrologer_consultations;
create trigger set_expert_astrologer_consultations_updated_at
before update on public.expert_astrologer_consultations
for each row execute function public.expert_astrologers_set_updated_at();

drop trigger if exists set_expert_astrologer_consultation_responses_updated_at
  on public.expert_astrologer_consultation_responses;
create trigger set_expert_astrologer_consultation_responses_updated_at
before update on public.expert_astrologer_consultation_responses
for each row execute function public.expert_astrologers_set_updated_at();

alter table public.expert_astrologer_conversations enable row level security;
alter table public.expert_astrologer_messages enable row level security;
alter table public.expert_astrologer_consultations enable row level security;
alter table public.expert_astrologer_consultation_responses enable row level security;

grant select, insert, update, delete on public.expert_astrologer_conversations to authenticated;
grant select, insert, update, delete on public.expert_astrologer_messages to authenticated;
grant select, insert, update, delete on public.expert_astrologer_consultations to authenticated;
grant select, insert, update, delete on public.expert_astrologer_consultation_responses to authenticated;

drop policy if exists "Users can view their expert conversations" on public.expert_astrologer_conversations;
create policy "Users can view their expert conversations"
on public.expert_astrologer_conversations
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert their expert conversations" on public.expert_astrologer_conversations;
create policy "Users can insert their expert conversations"
on public.expert_astrologer_conversations
for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their expert conversations" on public.expert_astrologer_conversations;
create policy "Users can update their expert conversations"
on public.expert_astrologer_conversations
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their expert conversations" on public.expert_astrologer_conversations;
create policy "Users can delete their expert conversations"
on public.expert_astrologer_conversations
for delete
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users can view their expert messages" on public.expert_astrologer_messages;
create policy "Users can view their expert messages"
on public.expert_astrologer_messages
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert their expert messages" on public.expert_astrologer_messages;
create policy "Users can insert their expert messages"
on public.expert_astrologer_messages
for insert
to authenticated
with check (
  (select auth.uid()) = user_id
  and exists (
    select 1
    from public.expert_astrologer_conversations c
    where c.id = conversation_id
      and c.user_id = (select auth.uid())
      and c.specialist_id = specialist_id
  )
);

drop policy if exists "Users can update their expert messages" on public.expert_astrologer_messages;
create policy "Users can update their expert messages"
on public.expert_astrologer_messages
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their expert messages" on public.expert_astrologer_messages;
create policy "Users can delete their expert messages"
on public.expert_astrologer_messages
for delete
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users can view their expert consultations" on public.expert_astrologer_consultations;
create policy "Users can view their expert consultations"
on public.expert_astrologer_consultations
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert their expert consultations" on public.expert_astrologer_consultations;
create policy "Users can insert their expert consultations"
on public.expert_astrologer_consultations
for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their expert consultations" on public.expert_astrologer_consultations;
create policy "Users can update their expert consultations"
on public.expert_astrologer_consultations
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their expert consultations" on public.expert_astrologer_consultations;
create policy "Users can delete their expert consultations"
on public.expert_astrologer_consultations
for delete
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users can view their expert consultation responses" on public.expert_astrologer_consultation_responses;
create policy "Users can view their expert consultation responses"
on public.expert_astrologer_consultation_responses
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert their expert consultation responses" on public.expert_astrologer_consultation_responses;
create policy "Users can insert their expert consultation responses"
on public.expert_astrologer_consultation_responses
for insert
to authenticated
with check (
  (select auth.uid()) = user_id
  and exists (
    select 1
    from public.expert_astrologer_consultations c
    where c.id = multi_consultation_id
      and c.user_id = (select auth.uid())
  )
);

drop policy if exists "Users can update their expert consultation responses" on public.expert_astrologer_consultation_responses;
create policy "Users can update their expert consultation responses"
on public.expert_astrologer_consultation_responses
for update
to authenticated
using ((select auth.uid()) = user_id)
with check (
  (select auth.uid()) = user_id
  and exists (
    select 1
    from public.expert_astrologer_consultations c
    where c.id = multi_consultation_id
      and c.user_id = (select auth.uid())
  )
);

drop policy if exists "Users can delete their expert consultation responses" on public.expert_astrologer_consultation_responses;
create policy "Users can delete their expert consultation responses"
on public.expert_astrologer_consultation_responses
for delete
to authenticated
using ((select auth.uid()) = user_id);
