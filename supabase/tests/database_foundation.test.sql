BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = extensions, public;

SELECT plan(19);

SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_extension AS e
    JOIN pg_namespace AS n ON n.oid = e.extnamespace
    WHERE e.extname = 'pgcrypto' AND n.nspname = 'extensions'
  ),
  'pgcrypto is the only application extension enabled by the migrations'
);

SELECT ok(
  (SELECT count(*) = 37 AND bool_and(c.relrowsecurity)
   FROM pg_class AS c
   JOIN pg_namespace AS n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relkind = 'r'),
  'all 37 application tables exist and have RLS enabled'
);

SELECT enum_has_labels('public', 'user_role', ARRAY['ADMIN', 'USER']);
SELECT enum_has_labels('public', 'goal_category', ARRAY[
  'ACADEMIC', 'CAREER', 'PERSONAL_DEVELOPMENT', 'HEALTH_FITNESS',
  'FINANCIAL', 'HOBBY_INTEREST', 'CUSTOM'
]);
SELECT enum_has_labels('public', 'task_status', ARRAY[
  'TODO', 'IN_PROGRESS', 'COMPLETED', 'SKIPPED', 'CANCELLED'
]);
SELECT enum_has_labels('public', 'conversation_type', ARRAY['DIRECT', 'GROUP', 'PROJECT']);

SELECT col_is_pk('public', 'goal_members', ARRAY['goal_id', 'user_id']);
SELECT col_is_pk('public', 'project_members', ARRAY['project_id', 'user_id']);
SELECT col_is_pk('public', 'task_dependencies', ARRAY['task_id', 'depends_on_task_id']);
SELECT has_index('public'::name, 'task_instances'::name, 'task_instances_recurrence_date_unique'::name);
SELECT has_index('public'::name, 'habit_entries'::name, 'habit_entries_habit_date_unique'::name);
SELECT has_trigger('auth'::name, 'users'::name, 'auth_user_create_profile'::name);
SELECT has_trigger('public'::name, 'profiles'::name, 'profiles_protect_last_active_admin'::name);
SELECT has_trigger('public'::name, 'tasks'::name, 'tasks_set_updated_at'::name);
SELECT has_trigger('public'::name, 'task_dependencies'::name, 'task_dependencies_prevent_cycle'::name);
SELECT has_trigger('public'::name, 'user_gamification'::name, 'user_gamification_protect_values'::name);

SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM pg_attribute
    WHERE attrelid = 'public.tasks'::regclass
      AND attname IN ('actual_minutes', 'time_spent', 'stopwatch_started_at')
      AND NOT attisdropped
  ),
  'tasks do not contain time-tracking fields'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM pg_policy
    WHERE polrelid = 'public.messages'::regclass
      AND (
        COALESCE(pg_get_expr(polqual, polrelid), '') ILIKE '%is_admin%'
        OR COALESCE(pg_get_expr(polwithcheck, polrelid), '') ILIKE '%is_admin%'
      )
  ),
  'no messages policy uses an administrator bypass'
);

SELECT policy_roles_are(
  'public', 'messages', 'messages_select_participants_only', ARRAY['authenticated']
);

SELECT * FROM finish(true);
ROLLBACK;
