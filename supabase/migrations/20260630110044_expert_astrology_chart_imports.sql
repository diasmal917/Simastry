insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'expert-astrology-charts',
  'expert-astrology-charts',
  false,
  10485760,
  array[
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/heic',
    'image/heif'
  ]
)
on conflict (id) do update
set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create table if not exists public.expert_astrology_chart_imports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  subject_type text not null default 'self'
    check (subject_type in ('self', 'person')),
  person_id uuid,
  storage_bucket text not null default 'expert-astrology-charts',
  storage_path text not null,
  status text not null default 'uploaded'
    check (status in ('uploaded', 'extracted', 'needs_review', 'confirmed', 'failed')),
  extracted_data jsonb not null default '{}'::jsonb,
  confirmed_data jsonb not null default '{}'::jsonb,
  extraction_warnings jsonb not null default '[]'::jsonb,
  source_label text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, id),
  unique (storage_bucket, storage_path),
  constraint expert_astrology_chart_imports_subject_consistency
    check (
      (subject_type = 'self' and person_id is null)
      or (subject_type = 'person' and person_id is not null)
    ),
  constraint expert_astrology_chart_imports_storage_bucket
    check (storage_bucket = 'expert-astrology-charts'),
  constraint expert_astrology_chart_imports_storage_path_length
    check (length(trim(storage_path)) between 1 and 512),
  constraint expert_astrology_chart_imports_storage_path_owner
    check (split_part(storage_path, '/', 1) = user_id::text),
  constraint expert_astrology_chart_imports_extracted_object
    check (jsonb_typeof(extracted_data) = 'object'),
  constraint expert_astrology_chart_imports_confirmed_object
    check (jsonb_typeof(confirmed_data) = 'object'),
  constraint expert_astrology_chart_imports_warnings_array
    check (jsonb_typeof(extraction_warnings) = 'array'),
  constraint expert_astrology_chart_imports_source_label_length
    check (source_label is null or length(trim(source_label)) <= 160)
);

create index if not exists expert_astrology_chart_imports_user_updated_idx
  on public.expert_astrology_chart_imports(user_id, updated_at desc);

create index if not exists expert_astrology_chart_imports_person_updated_idx
  on public.expert_astrology_chart_imports(user_id, person_id, updated_at desc)
  where subject_type = 'person';

create table if not exists public.expert_person_astrology_intake (
  user_id uuid not null references auth.users(id) on delete cascade,
  person_id uuid not null,
  display_name text,
  birth_date date,
  birth_time time,
  birth_time_unknown boolean not null default false,
  birth_place text,
  user_supplied_tradition_data jsonb not null default '{}'::jsonb,
  chart_import_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, person_id),
  constraint expert_person_astrology_intake_chart_import_fk
    foreign key (chart_import_id, user_id)
    references public.expert_astrology_chart_imports(id, user_id),
  constraint expert_person_astrology_intake_birth_time_consistency
    check (not birth_time_unknown or birth_time is null),
  constraint expert_person_astrology_intake_display_name_length
    check (display_name is null or length(trim(display_name)) <= 120),
  constraint expert_person_astrology_intake_birth_place_length
    check (birth_place is null or length(trim(birth_place)) <= 240),
  constraint expert_person_astrology_intake_user_supplied_object
    check (jsonb_typeof(user_supplied_tradition_data) = 'object')
);

create index if not exists expert_person_astrology_intake_user_updated_idx
  on public.expert_person_astrology_intake(user_id, updated_at desc);

drop trigger if exists set_expert_astrology_chart_imports_updated_at
  on public.expert_astrology_chart_imports;
create trigger set_expert_astrology_chart_imports_updated_at
before update on public.expert_astrology_chart_imports
for each row execute function public.expert_astrologers_set_updated_at();

drop trigger if exists set_expert_person_astrology_intake_updated_at
  on public.expert_person_astrology_intake;
create trigger set_expert_person_astrology_intake_updated_at
before update on public.expert_person_astrology_intake
for each row execute function public.expert_astrologers_set_updated_at();

alter table public.expert_astrology_chart_imports enable row level security;
alter table public.expert_person_astrology_intake enable row level security;

grant select, insert, update, delete on public.expert_astrology_chart_imports to authenticated;
grant select, insert, update, delete on public.expert_person_astrology_intake to authenticated;
grant select, insert, update, delete on public.expert_astrology_chart_imports to service_role;
grant select on public.expert_person_astrology_intake to service_role;

drop policy if exists "Users can view their chart imports" on public.expert_astrology_chart_imports;
create policy "Users can view their chart imports"
on public.expert_astrology_chart_imports
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert their chart imports" on public.expert_astrology_chart_imports;
create policy "Users can insert their chart imports"
on public.expert_astrology_chart_imports
for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their chart imports" on public.expert_astrology_chart_imports;
create policy "Users can update their chart imports"
on public.expert_astrology_chart_imports
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their chart imports" on public.expert_astrology_chart_imports;
create policy "Users can delete their chart imports"
on public.expert_astrology_chart_imports
for delete
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users can view their person astrology intake" on public.expert_person_astrology_intake;
create policy "Users can view their person astrology intake"
on public.expert_person_astrology_intake
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert their person astrology intake" on public.expert_person_astrology_intake;
create policy "Users can insert their person astrology intake"
on public.expert_person_astrology_intake
for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their person astrology intake" on public.expert_person_astrology_intake;
create policy "Users can update their person astrology intake"
on public.expert_person_astrology_intake
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their person astrology intake" on public.expert_person_astrology_intake;
create policy "Users can delete their person astrology intake"
on public.expert_person_astrology_intake
for delete
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users can view their astrology chart screenshots" on storage.objects;
create policy "Users can view their astrology chart screenshots"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'expert-astrology-charts'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Users can upload their astrology chart screenshots" on storage.objects;
create policy "Users can upload their astrology chart screenshots"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'expert-astrology-charts'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Users can update their astrology chart screenshots" on storage.objects;
create policy "Users can update their astrology chart screenshots"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'expert-astrology-charts'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'expert-astrology-charts'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Users can delete their astrology chart screenshots" on storage.objects;
create policy "Users can delete their astrology chart screenshots"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'expert-astrology-charts'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
