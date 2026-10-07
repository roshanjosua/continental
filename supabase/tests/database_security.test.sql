BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = extensions, public;

INSERT INTO auth.users (id, email, raw_user_meta_data)
VALUES
  ('a1000000-0000-4000-8000-000000000001', 'admin@test.invalid', '{"username":"Admin.One","display_name":"Admin One"}'),
  ('a2000000-0000-4000-8000-000000000002', 'member@test.invalid', '{"username":"Team.Member","display_name":"Team Member"}'),
  ('a3000000-0000-4000-8000-000000000003', 'other@test.invalid', '{"username":"Other.User","display_name":"Other User"}');

SET LOCAL ROLE service_role;
SET LOCAL request.jwt.claims = '{"role":"service_role"}';
SELECT private.bootstrap_first_admin('a1000000-0000-4000-8000-000000000001');
RESET ROLE;

INSERT INTO public.conversations (id, type, created_by)
VALUES (
  'c1000000-0000-4000-8000-000000000001',
  'DIRECT',
  (SELECT id FROM public.profiles WHERE auth_user_id = 'a2000000-0000-4000-8000-000000000002')
);
INSERT INTO public.conversation_members (conversation_id, user_id)
VALUES (
  'c1000000-0000-4000-8000-000000000001',
  (SELECT id FROM public.profiles WHERE auth_user_id = 'a2000000-0000-4000-8000-000000000002')
);
INSERT INTO public.messages (id, conversation_id, sender_id, content)
VALUES (
  'd1000000-0000-4000-8000-000000000001',
  'c1000000-0000-4000-8000-000000000001',
  (SELECT id FROM public.profiles WHERE auth_user_id = 'a2000000-0000-4000-8000-000000000002'),
  'participant-only test message'
);

INSERT INTO public.projects (id, owner_id, name)
VALUES (
  'e1000000-0000-4000-8000-000000000001',
  (SELECT id FROM public.profiles WHERE auth_user_id = 'a2000000-0000-4000-8000-000000000002'),
  'Shared test project'
);
INSERT INTO public.project_members (project_id, user_id)
VALUES (
  'e1000000-0000-4000-8000-000000000001',
  (SELECT id FROM public.profiles WHERE auth_user_id = 'a3000000-0000-4000-8000-000000000003')
);
INSERT INTO public.tasks (id, creator_id, project_id, title)
VALUES (
  'f1000000-0000-4000-8000-000000000001',
  (SELECT id FROM public.profiles WHERE auth_user_id = 'a2000000-0000-4000-8000-000000000002'),
  'e1000000-0000-4000-8000-000000000001',
  'Shared project task'
);
INSERT INTO public.goals (id, owner_id, title, category, duration_type, start_date)
VALUES (
  'e2000000-0000-4000-8000-000000000002',
  (SELECT id FROM public.profiles WHERE auth_user_id = 'a3000000-0000-4000-8000-000000000003'),
  'Owner protected goal',
  'PERSONAL_DEVELOPMENT',
  'WEEKLY',
  current_date
);
INSERT INTO public.projects (id, owner_id, name)
VALUES (
  'e3000000-0000-4000-8000-000000000003',
  (SELECT id FROM public.profiles WHERE auth_user_id = 'a3000000-0000-4000-8000-000000000003'),
  'Owner protected project'
);
CREATE TEMP TABLE test_profile_refs AS
SELECT id AS other_profile_id
FROM public.profiles
WHERE auth_user_id = 'a2000000-0000-4000-8000-000000000002';
GRANT SELECT ON test_profile_refs TO authenticated;

INSERT INTO public.tasks (id, creator_id, title)
VALUES
  ('f2000000-0000-4000-8000-000000000002', (SELECT id FROM public.profiles WHERE auth_user_id = 'a2000000-0000-4000-8000-000000000002'), 'Recurring task'),
  ('f3000000-0000-4000-8000-000000000003', (SELECT id FROM public.profiles WHERE auth_user_id = 'a2000000-0000-4000-8000-000000000002'), 'Dependency task one'),
  ('f4000000-0000-4000-8000-000000000004', (SELECT id FROM public.profiles WHERE auth_user_id = 'a2000000-0000-4000-8000-000000000002'), 'Dependency task two');
INSERT INTO public.task_recurrences (id, task_id, frequency, start_date)
VALUES (
  'b1000000-0000-4000-8000-000000000001',
  'f2000000-0000-4000-8000-000000000002',
  'WEEKLY',
  current_date
);
INSERT INTO public.task_instances (recurrence_id, task_id, scheduled_date)
VALUES ('b1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000002', current_date);
INSERT INTO public.task_dependencies (task_id, depends_on_task_id)
VALUES ('f3000000-0000-4000-8000-000000000003', 'f4000000-0000-4000-8000-000000000004');

CREATE TEMP TABLE profile_timestamp_before AS
SELECT id, updated_at
FROM public.profiles
WHERE auth_user_id = 'a2000000-0000-4000-8000-000000000002';
SELECT pg_sleep(0.01);
UPDATE public.profiles
SET display_name = 'Team Member Updated'
WHERE auth_user_id = 'a2000000-0000-4000-8000-000000000002';

SELECT plan(32);

SELECT is(
  (SELECT username FROM public.profiles WHERE auth_user_id = 'a2000000-0000-4000-8000-000000000002'),
  'team.member_a2000000',
  'Auth user creation creates a lowercase normalized profile username'
);
SELECT is(
  (SELECT role::text FROM public.profiles WHERE auth_user_id = 'a2000000-0000-4000-8000-000000000002'),
  'USER',
  'New profiles default to the USER role'
);
SELECT is(
  (SELECT display_name FROM public.profiles WHERE auth_user_id = 'a2000000-0000-4000-8000-000000000002'),
  'Team Member Updated',
  'Profile fields can be updated through database triggers and constraints'
);
SELECT is(
  (SELECT role::text FROM public.profiles WHERE auth_user_id = 'a1000000-0000-4000-8000-000000000001'),
  'ADMIN',
  'Service-role bootstrap promotes the first active administrator'
);
SELECT is(
  (SELECT xp FROM public.user_gamification WHERE user_id = (
    SELECT id FROM public.profiles WHERE auth_user_id = 'a2000000-0000-4000-8000-000000000002'
  )),
  0::bigint,
  'Profile creation provisions zero XP'
);
SELECT is(
  (SELECT level FROM public.user_gamification WHERE user_id = (
    SELECT id FROM public.profiles WHERE auth_user_id = 'a2000000-0000-4000-8000-000000000002'
  )),
  1,
  'Profile creation provisions level one'
);
SELECT is(
  (SELECT achievement_currency FROM public.user_gamification WHERE user_id = (
    SELECT id FROM public.profiles WHERE auth_user_id = 'a2000000-0000-4000-8000-000000000002'
  )),
  0::bigint,
  'Profile creation provisions zero achievement currency'
);
SELECT ok(
  (SELECT p.updated_at > before.updated_at
   FROM public.profiles AS p
   JOIN profile_timestamp_before AS before ON before.id = p.id),
  'updated_at is set by the database trigger'
);

SELECT throws_ok(
  $$INSERT INTO public.goals (owner_id, title, category, duration_type, start_date, manual_progress)
    VALUES ((SELECT id FROM public.profiles WHERE auth_user_id = 'a2000000-0000-4000-8000-000000000002'), 'Invalid progress', 'ACADEMIC', 'WEEKLY', current_date, 101)$$,
  '23514', NULL, 'Goal manual progress is constrained to 0 through 100'
);
SELECT throws_ok(
  $$INSERT INTO public.task_instances (recurrence_id, task_id, scheduled_date)
    VALUES ('b1000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000002', current_date)$$,
  '23505', NULL, 'A recurrence cannot create duplicate instances for one date'
);
SELECT throws_ok(
  $$INSERT INTO public.task_dependencies (task_id, depends_on_task_id)
    VALUES ('f4000000-0000-4000-8000-000000000004', 'f3000000-0000-4000-8000-000000000003')$$,
  '23514', NULL, 'Task dependency cycles are rejected by the controlled trigger'
);
SELECT throws_ok(
  $$DELETE FROM public.profiles WHERE auth_user_id = 'a1000000-0000-4000-8000-000000000001'$$,
  '23514', 'at least one active administrator must remain',
  'The only active administrator cannot be deleted'
);
SET LOCAL request.jwt.claims = '{"role":"authenticated"}';
SELECT throws_ok(
  $$SELECT private.bootstrap_first_admin('a3000000-0000-4000-8000-000000000003')$$,
  '42501', 'first administrator bootstrap requires a service-role request',
  'First-admin bootstrap rejects non-service-role requests'
);

SET LOCAL ROLE service_role;
SET LOCAL request.jwt.claims = '{"role":"service_role"}';
UPDATE public.profiles
SET role = 'ADMIN'
WHERE auth_user_id = 'a2000000-0000-4000-8000-000000000002';
RESET ROLE;
SELECT is(
  (SELECT count(*)::integer FROM public.profiles WHERE role = 'ADMIN' AND is_active),
  2,
  'Trusted server operations can support multiple active administrators'
);

SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub = 'a1000000-0000-4000-8000-000000000001';
SET LOCAL request.jwt.claims = '{"role":"authenticated","sub":"a1000000-0000-4000-8000-000000000001"}';
SELECT is(
  (SELECT count(*)::integer FROM public.messages),
  0,
  'Administrator who is not a conversation participant cannot read messages'
);
SELECT throws_ok(
  $$INSERT INTO public.messages (conversation_id, sender_id, content)
    VALUES ('c1000000-0000-4000-8000-000000000001',
      (SELECT id FROM public.profiles WHERE auth_user_id = 'a1000000-0000-4000-8000-000000000001'),
      'unauthorized message')$$,
  '42501', NULL,
  'Nonparticipant administrator cannot send a message'
);
SELECT throws_ok(
  $$INSERT INTO public.conversation_members (conversation_id, user_id)
    VALUES ('c1000000-0000-4000-8000-000000000001',
      (SELECT id FROM public.profiles WHERE auth_user_id = 'a1000000-0000-4000-8000-000000000001'))$$,
  '42501', NULL,
  'Administrator cannot add themselves to a conversation they do not participate in'
);
UPDATE public.messages
SET content = 'administrator edit attempt'
WHERE id = 'd1000000-0000-4000-8000-000000000001';
DELETE FROM public.messages
WHERE id = 'd1000000-0000-4000-8000-000000000001';
SELECT throws_ok(
  $$UPDATE public.user_gamification SET xp = 1 WHERE user_id =
    (SELECT id FROM public.profiles WHERE auth_user_id = 'a1000000-0000-4000-8000-000000000001')$$,
  '42501', NULL,
  'Authenticated users have no direct update privilege on protected gamification values'
);
RESET ROLE;

SET LOCAL ROLE service_role;
SELECT set_config('request.jwt.claims', jsonb_build_object('role', 'authenticated')::text, TRUE);
DO $gamification_guard_test$
DECLARE
  write_was_denied BOOLEAN := FALSE;
BEGIN
  IF auth.jwt() ->> 'role' <> 'authenticated' THEN
    RAISE EXCEPTION 'test JWT role was not authenticated';
  END IF;

  BEGIN
    UPDATE public.user_gamification
      SET xp = 1
      WHERE user_id = (
        SELECT id FROM public.profiles
        WHERE auth_user_id = 'a2000000-0000-4000-8000-000000000002'
      );
  EXCEPTION WHEN insufficient_privilege THEN
    write_was_denied := SQLERRM = 'gamification values can only be changed by trusted server operations';
  END;

  IF NOT write_was_denied THEN
    RAISE EXCEPTION 'gamification trigger did not reject authenticated client context';
  END IF;
END;
$gamification_guard_test$;
SELECT pass('Gamification trigger rejects authenticated client-context writes despite elevated table grants');
RESET ROLE;

SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub = 'a3000000-0000-4000-8000-000000000003';
SET LOCAL request.jwt.claims = '{"role":"authenticated","sub":"a3000000-0000-4000-8000-000000000003"}';
SELECT throws_ok(
  $$UPDATE public.profiles SET role = 'ADMIN' WHERE auth_user_id = 'a3000000-0000-4000-8000-000000000003'$$,
  '42501', NULL,
  'A regular user cannot promote themselves to administrator'
);
SELECT throws_ok(
  $$UPDATE public.profiles SET is_active = FALSE WHERE auth_user_id = 'a3000000-0000-4000-8000-000000000003'$$,
  '42501', NULL,
  'A regular user cannot change their active status'
);
SELECT throws_ok(
  $$UPDATE public.profiles SET auth_user_id = 'a2000000-0000-4000-8000-000000000002'
    WHERE auth_user_id = 'a3000000-0000-4000-8000-000000000003'$$,
  '42501', NULL,
  'A regular user cannot reassign their authentication identity'
);
SELECT throws_ok(
  $$UPDATE public.profiles SET username = 'another.username'
    WHERE auth_user_id = 'a3000000-0000-4000-8000-000000000003'$$,
  '42501', NULL,
  'A regular user cannot change their immutable username'
);
SELECT throws_ok(
  $$UPDATE public.goals SET owner_id = (SELECT other_profile_id FROM test_profile_refs)
    WHERE id = 'e2000000-0000-4000-8000-000000000002'$$,
  '42501', NULL,
  'Regular owners cannot transfer goal ownership'
);
SELECT throws_ok(
  $$UPDATE public.projects SET owner_id = (SELECT other_profile_id FROM test_profile_refs)
    WHERE id = 'e3000000-0000-4000-8000-000000000003'$$,
  '42501', NULL,
  'Regular owners cannot transfer project ownership'
);
SELECT is(
  (SELECT count(*)::integer FROM public.tasks WHERE id = 'f1000000-0000-4000-8000-000000000001'),
  1,
  'Project members can read tasks shared through project membership'
);

SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub = 'a2000000-0000-4000-8000-000000000002';
SET LOCAL request.jwt.claims = '{"role":"authenticated","sub":"a2000000-0000-4000-8000-000000000002"}';
SELECT is(
  (SELECT count(*)::integer FROM public.messages WHERE content = 'participant-only test message'),
  1,
  'Participant can still read original message after nonparticipant admin update/delete attempts'
);
SELECT lives_ok(
  $$INSERT INTO public.messages (id, conversation_id, sender_id, content)
    VALUES ('d2000000-0000-4000-8000-000000000002', 'c1000000-0000-4000-8000-000000000001',
      (SELECT id FROM public.profiles WHERE auth_user_id = 'a2000000-0000-4000-8000-000000000002'), 'participant-created message')$$,
  'A conversation participant can send a message as themselves'
);
SELECT throws_ok(
  $$INSERT INTO public.messages (conversation_id, sender_id, content)
    VALUES ('c1000000-0000-4000-8000-000000000001',
      (SELECT id FROM public.profiles WHERE auth_user_id = 'a1000000-0000-4000-8000-000000000001'),
      'spoofed sender')$$,
  '42501', NULL,
  'A participant cannot send a message with another profile as sender'
);
SELECT lives_ok(
  $$UPDATE public.messages SET content = 'participant-edited message'
    WHERE id = 'd2000000-0000-4000-8000-000000000002'$$,
  'A participant can edit their own message'
);
SELECT is(
  (SELECT edited_at IS NOT NULL FROM public.messages WHERE id = 'd2000000-0000-4000-8000-000000000002'),
  TRUE,
  'Message edits receive a database-generated edited_at timestamp'
);
SELECT lives_ok(
  $$DELETE FROM public.messages WHERE id = 'd2000000-0000-4000-8000-000000000002'$$,
  'A participant can delete their own message'
);

SELECT * FROM finish(true);
ROLLBACK;
