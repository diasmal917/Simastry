begin;

select plan(8);

select has_table(
  'public',
  'user_birth_charts',
  'private user birth chart table exists'
);

select col_is_pk(
  'public',
  'user_birth_charts',
  'user_id',
  'one source-of-truth chart row is keyed to its auth owner'
);

select ok(
  (select relrowsecurity
   from pg_class
   where oid = 'public.user_birth_charts'::regclass),
  'row level security is enabled'
);

select is(
  (select count(*)
   from information_schema.role_table_grants
   where table_schema = 'public'
     and table_name = 'user_birth_charts'
     and grantee in ('anon', 'PUBLIC')),
  0::bigint,
  'anonymous and PUBLIC roles have no table grants'
);

select ok(
  (select count(*) = 4
     and bool_and(privilege_type in ('DELETE', 'INSERT', 'SELECT', 'UPDATE'))
   from information_schema.role_table_grants
   where table_schema = 'public'
     and table_name = 'user_birth_charts'
     and grantee = 'authenticated'),
  'authenticated receives only CRUD table grants'
);

select is(
  (select count(*) from pg_policies
   where schemaname = 'public'
     and tablename = 'user_birth_charts'
     and roles = array['authenticated']::name[]),
  4::bigint,
  'four owner-only authenticated policies exist'
);

select is(
  (select array_agg(cmd order by cmd) from pg_policies
   where schemaname = 'public'
     and tablename = 'user_birth_charts'),
  array['DELETE', 'INSERT', 'SELECT', 'UPDATE']::text[],
  'policies cover every granted operation'
);

select ok(
  (select bool_and(
      coalesce(qual, with_check, '') like '%auth.uid()%'
      and coalesce(qual, with_check, '') like '%user_id%'
    )
   from pg_policies
   where schemaname = 'public'
     and tablename = 'user_birth_charts'),
  'every policy binds the authenticated uid to user_id'
);

select * from finish();
rollback;
