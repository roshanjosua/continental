CREATE TABLE public.comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  entity_type TEXT NOT NULL,
  entity_id UUID NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  deleted_by UUID REFERENCES public.profiles (id) ON DELETE SET NULL,
  CONSTRAINT comments_content_nonempty CHECK (length(btrim(content)) > 0)
);

CREATE TABLE public.comment_mentions (
  comment_id UUID NOT NULL REFERENCES public.comments (id) ON DELETE CASCADE,
  mentioned_user_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (comment_id, mentioned_user_id)
);

CREATE TABLE public.activity_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id UUID NOT NULL,
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type public.conversation_type NOT NULL,
  created_by UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.conversation_members (
  conversation_id UUID NOT NULL REFERENCES public.conversations (id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (conversation_id, user_id)
);

CREATE TABLE public.messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES public.conversations (id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  edited_at TIMESTAMPTZ,
  deleted_at TIMESTAMPTZ,
  CONSTRAINT messages_content_nonempty CHECK (length(btrim(content)) > 0)
);

CREATE TABLE public.user_gamification (
  user_id UUID PRIMARY KEY REFERENCES public.profiles (id) ON DELETE CASCADE,
  xp BIGINT NOT NULL DEFAULT 0,
  level INTEGER NOT NULL DEFAULT 1,
  achievement_currency BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT user_gamification_xp_nonnegative CHECK (xp >= 0),
  CONSTRAINT user_gamification_level_positive CHECK (level >= 1),
  CONSTRAINT user_gamification_currency_nonnegative CHECK (achievement_currency >= 0)
);

CREATE TABLE public.achievements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  icon TEXT,
  xp_reward INTEGER NOT NULL DEFAULT 0,
  currency_reward INTEGER NOT NULL DEFAULT 0,
  criteria JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT achievements_xp_reward_nonnegative CHECK (xp_reward >= 0),
  CONSTRAINT achievements_currency_reward_nonnegative CHECK (currency_reward >= 0)
);

CREATE TABLE public.user_achievements (
  user_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  achievement_id UUID NOT NULL REFERENCES public.achievements (id) ON DELETE CASCADE,
  earned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, achievement_id)
);

CREATE TABLE public.xp_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  amount INTEGER NOT NULL,
  reason TEXT NOT NULL,
  entity_type TEXT,
  entity_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.user_streaks (
  user_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  streak_type public.streak_type NOT NULL,
  current_streak INTEGER NOT NULL DEFAULT 0,
  best_streak INTEGER NOT NULL DEFAULT 0,
  last_activity_date DATE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, streak_type),
  CONSTRAINT user_streaks_current_nonnegative CHECK (current_streak >= 0),
  CONSTRAINT user_streaks_best_nonnegative CHECK (best_streak >= 0),
  CONSTRAINT user_streaks_best_at_least_current CHECK (best_streak >= current_streak)
);

CREATE TABLE public.user_preferences (
  user_id UUID PRIMARY KEY REFERENCES public.profiles (id) ON DELETE CASCADE,
  gamification_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  xp_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  badges_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  leaderboards_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  theme TEXT NOT NULL DEFAULT 'system',
  accent_color TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT user_preferences_theme_valid CHECK (theme IN ('light', 'dark', 'system'))
);

CREATE TABLE public.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID REFERENCES public.profiles (id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id UUID,
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.external_links (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  entity_type TEXT NOT NULL,
  entity_id UUID NOT NULL,
  title TEXT NOT NULL,
  url TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  deleted_by UUID REFERENCES public.profiles (id) ON DELETE SET NULL,
  CONSTRAINT external_links_http_url CHECK (url ~* '^https?://'),
  CONSTRAINT external_links_title_nonempty CHECK (length(btrim(title)) > 0)
);

CREATE INDEX goals_owner_status_target_idx ON public.goals (owner_id, status, target_date) WHERE deleted_at IS NULL;
CREATE INDEX goal_members_user_idx ON public.goal_members (user_id, goal_id);
CREATE INDEX projects_owner_status_target_idx ON public.projects (owner_id, status, target_date) WHERE deleted_at IS NULL;
CREATE INDEX project_members_user_idx ON public.project_members (user_id, project_id);
CREATE INDEX milestones_project_due_idx ON public.milestones (project_id, due_date) WHERE deleted_at IS NULL;
CREATE INDEX milestones_goal_idx ON public.milestones (goal_id) WHERE goal_id IS NOT NULL;
CREATE INDEX tasks_creator_due_idx ON public.tasks (creator_id, due_date) WHERE deleted_at IS NULL;
CREATE INDEX tasks_goal_idx ON public.tasks (goal_id) WHERE goal_id IS NOT NULL;
CREATE INDEX tasks_project_idx ON public.tasks (project_id) WHERE project_id IS NOT NULL;
CREATE INDEX tasks_milestone_idx ON public.tasks (milestone_id) WHERE milestone_id IS NOT NULL;
CREATE INDEX tasks_parent_idx ON public.tasks (parent_task_id) WHERE parent_task_id IS NOT NULL;
CREATE INDEX tasks_status_priority_idx ON public.tasks (status, priority) WHERE deleted_at IS NULL;
CREATE INDEX task_assignees_user_idx ON public.task_assignees (user_id, task_id);
CREATE INDEX task_dependencies_depends_on_idx ON public.task_dependencies (depends_on_task_id, task_id);
CREATE INDEX task_recurrences_schedule_idx ON public.task_recurrences (next_occurrence) WHERE is_active;
CREATE INDEX task_recurrences_task_idx ON public.task_recurrences (task_id);
CREATE INDEX task_instances_scheduled_idx ON public.task_instances (scheduled_date, status);
CREATE INDEX task_instances_task_idx ON public.task_instances (task_id);
CREATE INDEX habits_owner_active_idx ON public.habits (owner_id, is_active) WHERE deleted_at IS NULL;
CREATE INDEX habit_entries_date_idx ON public.habit_entries (date, habit_id);
CREATE INDEX daily_goals_owner_date_idx ON public.daily_goals (owner_id, date);
CREATE INDEX focus_sessions_owner_started_idx ON public.focus_sessions (owner_id, started_at DESC);
CREATE INDEX journal_entries_owner_date_idx ON public.journal_entries (owner_id, date DESC) WHERE deleted_at IS NULL;
CREATE INDEX academic_terms_owner_current_idx ON public.academic_terms (owner_id, is_current);
CREATE INDEX subjects_owner_term_idx ON public.subjects (owner_id, term_id) WHERE deleted_at IS NULL;
CREATE INDEX assignments_owner_due_idx ON public.assignments (owner_id, due_date) WHERE deleted_at IS NULL;
CREATE INDEX exams_owner_date_idx ON public.exams (owner_id, date) WHERE deleted_at IS NULL;
CREATE INDEX calendar_events_owner_start_idx ON public.calendar_events (owner_id, start_at) WHERE deleted_at IS NULL;
CREATE INDEX notifications_recipient_unread_idx ON public.notifications (recipient_id, created_at DESC) WHERE read_at IS NULL;
CREATE INDEX notifications_scheduled_idx ON public.notifications (scheduled_at) WHERE sent_at IS NULL AND scheduled_at IS NOT NULL;
CREATE INDEX comments_entity_created_idx ON public.comments (entity_type, entity_id, created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX comment_mentions_user_idx ON public.comment_mentions (mentioned_user_id, comment_id);
CREATE INDEX activity_events_entity_created_idx ON public.activity_events (entity_type, entity_id, created_at DESC);
CREATE INDEX activity_events_actor_created_idx ON public.activity_events (actor_id, created_at DESC);
CREATE INDEX conversation_members_user_idx ON public.conversation_members (user_id, conversation_id);
CREATE INDEX messages_conversation_created_idx ON public.messages (conversation_id, created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX messages_sender_idx ON public.messages (sender_id, created_at DESC);
CREATE INDEX user_achievements_user_earned_idx ON public.user_achievements (user_id, earned_at DESC);
CREATE INDEX xp_transactions_user_created_idx ON public.xp_transactions (user_id, created_at DESC);
CREATE INDEX audit_logs_actor_created_idx ON public.audit_logs (actor_id, created_at DESC);
CREATE INDEX external_links_owner_entity_idx ON public.external_links (owner_id, entity_type, entity_id) WHERE deleted_at IS NULL;

CREATE FUNCTION private.handle_new_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  base_username TEXT;
  normalized_username TEXT;
  preferred_name TEXT;
BEGIN
  base_username := COALESCE(
    NEW.raw_user_meta_data ->> 'username',
    split_part(COALESCE(NEW.email, ''), '@', 1),
    'user'
  );
  normalized_username := regexp_replace(lower(btrim(base_username)), '[^a-z0-9._-]+', '_', 'g');
  normalized_username := btrim(normalized_username, '._-');
  IF normalized_username = '' THEN
    normalized_username := 'user';
  END IF;
  normalized_username := left(normalized_username, 48) || '_' || left(NEW.id::text, 8);

  preferred_name := COALESCE(
    nullif(btrim(NEW.raw_user_meta_data ->> 'display_name'), ''),
    nullif(btrim(NEW.raw_user_meta_data ->> 'name'), ''),
    nullif(btrim(NEW.email), ''),
    normalized_username
  );

  INSERT INTO public.profiles (auth_user_id, username, display_name, email)
  VALUES (NEW.id, normalized_username, preferred_name, NEW.email)
  ON CONFLICT (auth_user_id) DO NOTHING;

  RETURN NEW;
END;
$function$;

CREATE FUNCTION private.create_profile_companions()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  INSERT INTO public.user_gamification (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO public.user_preferences (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$function$;

CREATE TRIGGER profiles_create_companions
AFTER INSERT ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION private.create_profile_companions();

CREATE TRIGGER auth_user_create_profile
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION private.handle_new_auth_user();

CREATE FUNCTION private.sync_auth_user_email()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF NEW.email IS DISTINCT FROM OLD.email THEN
    UPDATE public.profiles
      SET email = NEW.email
      WHERE auth_user_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$function$;

CREATE TRIGGER auth_user_sync_profile_email
AFTER UPDATE OF email ON auth.users
FOR EACH ROW
EXECUTE FUNCTION private.sync_auth_user_email();

CREATE FUNCTION private.can_access_goal(p_goal_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT private.is_admin() OR EXISTS (
    SELECT 1
    FROM public.goals AS g
    WHERE g.id = p_goal_id
      AND (
        g.owner_id = private.current_profile_id()
        OR EXISTS (
          SELECT 1
          FROM public.goal_members AS gm
          WHERE gm.goal_id = g.id
            AND gm.user_id = private.current_profile_id()
        )
      )
  );
$function$;

CREATE FUNCTION private.can_manage_goal(p_goal_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT private.is_admin() OR EXISTS (
    SELECT 1
    FROM public.goals AS g
    WHERE g.id = p_goal_id
      AND g.owner_id = private.current_profile_id()
  );
$function$;

CREATE FUNCTION private.can_access_project(p_project_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT private.is_admin() OR EXISTS (
    SELECT 1
    FROM public.projects AS p
    WHERE p.id = p_project_id
      AND (
        p.owner_id = private.current_profile_id()
        OR EXISTS (
          SELECT 1
          FROM public.project_members AS pm
          WHERE pm.project_id = p.id
            AND pm.user_id = private.current_profile_id()
        )
      )
  );
$function$;

CREATE FUNCTION private.can_manage_project(p_project_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT private.is_admin() OR EXISTS (
    SELECT 1
    FROM public.projects AS p
    WHERE p.id = p_project_id
      AND p.owner_id = private.current_profile_id()
  );
$function$;

CREATE FUNCTION private.can_access_task(p_task_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT private.is_admin() OR EXISTS (
    SELECT 1
    FROM public.tasks AS t
    WHERE t.id = p_task_id
      AND (
        t.creator_id = private.current_profile_id()
        OR EXISTS (
          SELECT 1
          FROM public.task_assignees AS ta
          WHERE ta.task_id = t.id
            AND ta.user_id = private.current_profile_id()
        )
        OR (t.goal_id IS NOT NULL AND private.can_access_goal(t.goal_id))
        OR (t.project_id IS NOT NULL AND private.can_access_project(t.project_id))
        OR EXISTS (
          SELECT 1
          FROM public.milestones AS m
          WHERE m.id = t.milestone_id
            AND private.can_access_project(m.project_id)
        )
      )
  );
$function$;

CREATE FUNCTION private.can_manage_task(p_task_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT private.is_admin() OR EXISTS (
    SELECT 1
    FROM public.tasks AS t
    WHERE t.id = p_task_id
      AND (
        t.creator_id = private.current_profile_id()
        OR (t.goal_id IS NOT NULL AND private.can_manage_goal(t.goal_id))
        OR (t.project_id IS NOT NULL AND private.can_manage_project(t.project_id))
        OR EXISTS (
          SELECT 1
          FROM public.milestones AS m
          WHERE m.id = t.milestone_id
            AND private.can_manage_project(m.project_id)
        )
      )
  );
$function$;

CREATE FUNCTION private.is_conversation_member(p_conversation_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.conversation_members AS cm
    WHERE cm.conversation_id = p_conversation_id
      AND cm.user_id = private.current_profile_id()
  );
$function$;

CREATE FUNCTION private.can_manage_conversation(p_conversation_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.conversations AS c
    WHERE c.id = p_conversation_id
      AND (
        c.created_by = private.current_profile_id()
        OR private.is_conversation_member(c.id)
      )
  );
$function$;

CREATE FUNCTION private.can_access_entity(p_entity_type TEXT, p_entity_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  profile_id UUID := private.current_profile_id();
BEGIN
  IF private.is_admin() THEN
    RETURN TRUE;
  END IF;
  IF profile_id IS NULL OR p_entity_id IS NULL THEN
    RETURN FALSE;
  END IF;

  CASE lower(p_entity_type)
    WHEN 'goal' THEN RETURN private.can_access_goal(p_entity_id);
    WHEN 'project' THEN RETURN private.can_access_project(p_entity_id);
    WHEN 'milestone' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.milestones AS m
        WHERE m.id = p_entity_id
          AND (
            private.can_access_project(m.project_id)
            OR (m.goal_id IS NOT NULL AND private.can_access_goal(m.goal_id))
          )
      );
    WHEN 'task' THEN RETURN private.can_access_task(p_entity_id);
    WHEN 'habit' THEN
      RETURN EXISTS (SELECT 1 FROM public.habits AS h WHERE h.id = p_entity_id AND h.owner_id = profile_id);
    WHEN 'daily_goal' THEN
      RETURN EXISTS (SELECT 1 FROM public.daily_goals AS d WHERE d.id = p_entity_id AND d.owner_id = profile_id);
    WHEN 'focus_session' THEN
      RETURN EXISTS (SELECT 1 FROM public.focus_sessions AS f WHERE f.id = p_entity_id AND f.owner_id = profile_id);
    WHEN 'journal_entry' THEN
      RETURN EXISTS (SELECT 1 FROM public.journal_entries AS j WHERE j.id = p_entity_id AND j.owner_id = profile_id);
    WHEN 'academic_term' THEN
      RETURN EXISTS (SELECT 1 FROM public.academic_terms AS a WHERE a.id = p_entity_id AND a.owner_id = profile_id);
    WHEN 'subject' THEN
      RETURN EXISTS (SELECT 1 FROM public.subjects AS s WHERE s.id = p_entity_id AND s.owner_id = profile_id);
    WHEN 'assignment' THEN
      RETURN EXISTS (SELECT 1 FROM public.assignments AS a WHERE a.id = p_entity_id AND a.owner_id = profile_id);
    WHEN 'exam' THEN
      RETURN EXISTS (SELECT 1 FROM public.exams AS e WHERE e.id = p_entity_id AND e.owner_id = profile_id);
    WHEN 'calendar_event' THEN
      RETURN EXISTS (SELECT 1 FROM public.calendar_events AS c WHERE c.id = p_entity_id AND c.owner_id = profile_id);
    WHEN 'conversation' THEN RETURN private.is_conversation_member(p_entity_id);
    ELSE RETURN FALSE;
  END CASE;
END;
$function$;

CREATE FUNCTION private.prevent_task_dependency_cycle()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  would_cycle BOOLEAN;
BEGIN
  PERFORM pg_advisory_xact_lock(165107, 2);

  WITH RECURSIVE dependency_path(task_id) AS (
    SELECT d.depends_on_task_id
    FROM public.task_dependencies AS d
    WHERE d.task_id = NEW.depends_on_task_id
      AND (TG_OP <> 'UPDATE' OR d.task_id <> OLD.task_id OR d.depends_on_task_id <> OLD.depends_on_task_id)
    UNION
    SELECT d.depends_on_task_id
    FROM public.task_dependencies AS d
    JOIN dependency_path AS path ON d.task_id = path.task_id
    WHERE TG_OP <> 'UPDATE' OR d.task_id <> OLD.task_id OR d.depends_on_task_id <> OLD.depends_on_task_id
  )
  SELECT EXISTS (
    SELECT 1 FROM dependency_path WHERE task_id = NEW.task_id
  ) INTO would_cycle;

  IF would_cycle THEN
    RAISE EXCEPTION USING
      ERRCODE = '23514',
      MESSAGE = 'task dependencies cannot contain a cycle';
  END IF;

  RETURN NEW;
END;
$function$;

CREATE TRIGGER task_dependencies_prevent_cycle
BEFORE INSERT OR UPDATE ON public.task_dependencies
FOR EACH ROW
EXECUTE FUNCTION private.prevent_task_dependency_cycle();

CREATE FUNCTION private.set_message_edited_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $function$
BEGIN
  IF NEW.content IS DISTINCT FROM OLD.content THEN
    NEW.edited_at := clock_timestamp();
  END IF;
  RETURN NEW;
END;
$function$;

CREATE TRIGGER messages_set_edited_at
BEFORE UPDATE OF content ON public.messages
FOR EACH ROW
EXECUTE FUNCTION private.set_message_edited_at();

CREATE FUNCTION private.protect_gamification_values()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $function$
BEGIN
  IF COALESCE(auth.jwt() ->> 'role', '') IN ('anon', 'authenticated')
    AND (
      NEW.xp IS DISTINCT FROM OLD.xp
      OR NEW.level IS DISTINCT FROM OLD.level
      OR NEW.achievement_currency IS DISTINCT FROM OLD.achievement_currency
    ) THEN
    RAISE EXCEPTION USING
      ERRCODE = '42501',
      MESSAGE = 'gamification values can only be changed by trusted server operations';
  END IF;
  NEW.updated_at := clock_timestamp();
  RETURN NEW;
END;
$function$;

CREATE TRIGGER user_gamification_protect_values
BEFORE UPDATE ON public.user_gamification
FOR EACH ROW
EXECUTE FUNCTION private.protect_gamification_values();

CREATE TRIGGER comments_set_updated_at BEFORE UPDATE ON public.comments
FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER user_preferences_set_updated_at BEFORE UPDATE ON public.user_preferences
FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER external_links_set_updated_at BEFORE UPDATE ON public.external_links
FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();

REVOKE ALL ON FUNCTION private.handle_new_auth_user() FROM PUBLIC;
REVOKE ALL ON FUNCTION private.create_profile_companions() FROM PUBLIC;
REVOKE ALL ON FUNCTION private.sync_auth_user_email() FROM PUBLIC;
REVOKE ALL ON FUNCTION private.prevent_task_dependency_cycle() FROM PUBLIC;
REVOKE ALL ON FUNCTION private.protect_gamification_values() FROM PUBLIC;
REVOKE ALL ON FUNCTION private.set_message_edited_at() FROM PUBLIC;

REVOKE ALL ON FUNCTION private.can_access_goal(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.can_manage_goal(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.can_access_project(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.can_manage_project(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.can_access_task(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.can_manage_task(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.is_conversation_member(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.can_manage_conversation(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.can_access_entity(TEXT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.can_access_goal(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.can_manage_goal(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.can_access_project(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.can_manage_project(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.can_access_task(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.can_manage_task(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.is_conversation_member(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.can_manage_conversation(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.can_access_entity(TEXT, UUID) TO authenticated, service_role;
