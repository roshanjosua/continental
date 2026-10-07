DO $block$
DECLARE
  table_name TEXT;
  application_tables TEXT[] := ARRAY[
    'profiles', 'goals', 'goal_members', 'projects', 'project_members', 'milestones',
    'tasks', 'task_assignees', 'task_dependencies', 'task_recurrences', 'task_instances',
    'habits', 'habit_entries', 'daily_goals', 'focus_sessions', 'journal_entries',
    'academic_terms', 'subjects', 'assignments', 'exams', 'calendar_events',
    'notifications', 'notification_preferences', 'comments', 'comment_mentions',
    'activity_events', 'conversations', 'conversation_members', 'messages',
    'user_gamification', 'achievements', 'user_achievements', 'xp_transactions',
    'user_streaks', 'user_preferences', 'audit_logs', 'external_links'
  ];
BEGIN
  FOREACH table_name IN ARRAY application_tables LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', table_name);
    EXECUTE format('REVOKE ALL ON TABLE public.%I FROM anon, authenticated', table_name);
    EXECUTE format('GRANT ALL ON TABLE public.%I TO service_role', table_name);
  END LOOP;
END;
$block$;

CREATE POLICY profiles_select_self_or_admin ON public.profiles
FOR SELECT TO authenticated
USING (auth_user_id = auth.uid() OR private.is_admin());

CREATE POLICY profiles_update_self_or_admin ON public.profiles
FOR UPDATE TO authenticated
USING (auth_user_id = auth.uid() OR private.is_admin())
WITH CHECK (auth_user_id = auth.uid() OR private.is_admin());

CREATE POLICY goals_select_authorized ON public.goals
FOR SELECT TO authenticated
USING (private.can_access_goal(id));

CREATE POLICY goals_insert_owner ON public.goals
FOR INSERT TO authenticated
WITH CHECK (owner_id = private.current_profile_id() OR private.is_admin());

CREATE POLICY goals_update_owner ON public.goals
FOR UPDATE TO authenticated
USING (private.can_manage_goal(id))
WITH CHECK (
  private.is_admin()
  OR (owner_id = private.current_profile_id() AND private.can_manage_goal(id))
);

CREATE POLICY goals_delete_owner ON public.goals
FOR DELETE TO authenticated
USING (private.can_manage_goal(id));

CREATE POLICY goal_members_select_authorized ON public.goal_members
FOR SELECT TO authenticated
USING (private.can_access_goal(goal_id));

CREATE POLICY goal_members_insert_manager ON public.goal_members
FOR INSERT TO authenticated
WITH CHECK (private.can_manage_goal(goal_id));

CREATE POLICY goal_members_delete_manager_or_self ON public.goal_members
FOR DELETE TO authenticated
USING (private.can_manage_goal(goal_id) OR user_id = private.current_profile_id());

CREATE POLICY projects_select_authorized ON public.projects
FOR SELECT TO authenticated
USING (private.can_access_project(id));

CREATE POLICY projects_insert_owner ON public.projects
FOR INSERT TO authenticated
WITH CHECK (owner_id = private.current_profile_id() OR private.is_admin());

CREATE POLICY projects_update_owner ON public.projects
FOR UPDATE TO authenticated
USING (private.can_manage_project(id))
WITH CHECK (
  private.is_admin()
  OR (owner_id = private.current_profile_id() AND private.can_manage_project(id))
);

CREATE POLICY projects_delete_owner ON public.projects
FOR DELETE TO authenticated
USING (private.can_manage_project(id));

CREATE POLICY project_members_select_authorized ON public.project_members
FOR SELECT TO authenticated
USING (private.can_access_project(project_id));

CREATE POLICY project_members_insert_manager ON public.project_members
FOR INSERT TO authenticated
WITH CHECK (private.can_manage_project(project_id));

CREATE POLICY project_members_delete_manager_or_self ON public.project_members
FOR DELETE TO authenticated
USING (private.can_manage_project(project_id) OR user_id = private.current_profile_id());

CREATE POLICY milestones_select_authorized ON public.milestones
FOR SELECT TO authenticated
USING (
  private.is_admin()
  OR private.can_access_project(project_id)
  OR (goal_id IS NOT NULL AND private.can_access_goal(goal_id))
);

CREATE POLICY milestones_insert_project_manager ON public.milestones
FOR INSERT TO authenticated
WITH CHECK (
  private.can_manage_project(project_id)
  AND (goal_id IS NULL OR private.can_access_goal(goal_id))
);

CREATE POLICY milestones_update_project_manager ON public.milestones
FOR UPDATE TO authenticated
USING (private.can_manage_project(project_id))
WITH CHECK (
  private.can_manage_project(project_id)
  AND (goal_id IS NULL OR private.can_access_goal(goal_id))
);

CREATE POLICY milestones_delete_project_manager ON public.milestones
FOR DELETE TO authenticated
USING (private.can_manage_project(project_id));

CREATE POLICY tasks_select_authorized ON public.tasks
FOR SELECT TO authenticated
USING (private.can_access_task(id));

CREATE POLICY tasks_insert_creator ON public.tasks
FOR INSERT TO authenticated
WITH CHECK (
  creator_id = private.current_profile_id()
  AND (goal_id IS NULL OR private.can_access_goal(goal_id))
  AND (project_id IS NULL OR private.can_access_project(project_id))
  AND (milestone_id IS NULL OR EXISTS (
    SELECT 1 FROM public.milestones AS m
    WHERE m.id = milestone_id AND private.can_access_project(m.project_id)
  ))
  AND (parent_task_id IS NULL OR private.can_access_task(parent_task_id))
);

CREATE POLICY tasks_update_manager ON public.tasks
FOR UPDATE TO authenticated
USING (private.can_manage_task(id))
WITH CHECK (
  (private.is_admin() OR creator_id = private.current_profile_id()
    OR (goal_id IS NOT NULL AND private.can_manage_goal(goal_id))
    OR (project_id IS NOT NULL AND private.can_manage_project(project_id))
    OR (milestone_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.milestones AS m
      WHERE m.id = milestone_id AND private.can_manage_project(m.project_id)
    )))
  AND (goal_id IS NULL OR private.can_access_goal(goal_id))
  AND (project_id IS NULL OR private.can_access_project(project_id))
  AND (milestone_id IS NULL OR EXISTS (
    SELECT 1 FROM public.milestones AS m
    WHERE m.id = milestone_id AND private.can_access_project(m.project_id)
  ))
  AND (parent_task_id IS NULL OR private.can_access_task(parent_task_id))
);

CREATE POLICY tasks_delete_manager ON public.tasks
FOR DELETE TO authenticated
USING (private.can_manage_task(id));

CREATE POLICY task_assignees_select_authorized ON public.task_assignees
FOR SELECT TO authenticated
USING (private.can_access_task(task_id));

CREATE POLICY task_assignees_insert_manager ON public.task_assignees
FOR INSERT TO authenticated
WITH CHECK (private.can_manage_task(task_id));

CREATE POLICY task_assignees_delete_manager_or_self ON public.task_assignees
FOR DELETE TO authenticated
USING (private.can_manage_task(task_id) OR user_id = private.current_profile_id());

CREATE POLICY task_dependencies_select_authorized ON public.task_dependencies
FOR SELECT TO authenticated
USING (private.can_access_task(task_id) AND private.can_access_task(depends_on_task_id));

CREATE POLICY task_dependencies_insert_manager ON public.task_dependencies
FOR INSERT TO authenticated
WITH CHECK (private.can_manage_task(task_id) AND private.can_access_task(depends_on_task_id));

CREATE POLICY task_dependencies_delete_manager ON public.task_dependencies
FOR DELETE TO authenticated
USING (private.can_manage_task(task_id));

CREATE POLICY task_recurrences_select_authorized ON public.task_recurrences
FOR SELECT TO authenticated
USING (private.can_access_task(task_id));

CREATE POLICY task_recurrences_insert_manager ON public.task_recurrences
FOR INSERT TO authenticated
WITH CHECK (private.can_manage_task(task_id));

CREATE POLICY task_recurrences_update_manager ON public.task_recurrences
FOR UPDATE TO authenticated
USING (private.can_manage_task(task_id))
WITH CHECK (private.can_manage_task(task_id));

CREATE POLICY task_recurrences_delete_manager ON public.task_recurrences
FOR DELETE TO authenticated
USING (private.can_manage_task(task_id));

CREATE POLICY task_instances_select_authorized ON public.task_instances
FOR SELECT TO authenticated
USING (private.can_access_task(task_id));

CREATE POLICY task_instances_insert_manager ON public.task_instances
FOR INSERT TO authenticated
WITH CHECK (
  private.can_manage_task(task_id)
  AND EXISTS (
    SELECT 1 FROM public.task_recurrences AS r
    WHERE r.id = recurrence_id AND r.task_id = task_id
  )
);

CREATE POLICY task_instances_update_manager ON public.task_instances
FOR UPDATE TO authenticated
USING (private.can_manage_task(task_id))
WITH CHECK (private.can_manage_task(task_id));

CREATE POLICY task_instances_delete_manager ON public.task_instances
FOR DELETE TO authenticated
USING (private.can_manage_task(task_id));

CREATE POLICY habits_owner_all ON public.habits
FOR ALL TO authenticated
USING (owner_id = private.current_profile_id() OR private.is_admin())
WITH CHECK (owner_id = private.current_profile_id() OR private.is_admin());

CREATE POLICY habit_entries_select_owner ON public.habit_entries
FOR SELECT TO authenticated
USING (EXISTS (
  SELECT 1 FROM public.habits AS h
  WHERE h.id = habit_id
    AND (h.owner_id = private.current_profile_id() OR private.is_admin())
));

CREATE POLICY habit_entries_insert_owner ON public.habit_entries
FOR INSERT TO authenticated
WITH CHECK (EXISTS (
  SELECT 1 FROM public.habits AS h
  WHERE h.id = habit_id
    AND (h.owner_id = private.current_profile_id() OR private.is_admin())
));

CREATE POLICY habit_entries_update_owner ON public.habit_entries
FOR UPDATE TO authenticated
USING (EXISTS (
  SELECT 1 FROM public.habits AS h
  WHERE h.id = habit_id
    AND (h.owner_id = private.current_profile_id() OR private.is_admin())
))
WITH CHECK (EXISTS (
  SELECT 1 FROM public.habits AS h
  WHERE h.id = habit_id
    AND (h.owner_id = private.current_profile_id() OR private.is_admin())
));

CREATE POLICY habit_entries_delete_owner ON public.habit_entries
FOR DELETE TO authenticated
USING (EXISTS (
  SELECT 1 FROM public.habits AS h
  WHERE h.id = habit_id
    AND (h.owner_id = private.current_profile_id() OR private.is_admin())
));

CREATE POLICY daily_goals_owner_all ON public.daily_goals
FOR ALL TO authenticated
USING (owner_id = private.current_profile_id() OR private.is_admin())
WITH CHECK (owner_id = private.current_profile_id() OR private.is_admin());

CREATE POLICY focus_sessions_owner_all ON public.focus_sessions
FOR ALL TO authenticated
USING (owner_id = private.current_profile_id() OR private.is_admin())
WITH CHECK (
  (owner_id = private.current_profile_id() OR private.is_admin())
  AND (task_id IS NULL OR private.can_access_task(task_id))
  AND (goal_id IS NULL OR private.can_access_goal(goal_id))
);

CREATE POLICY journal_entries_owner_all ON public.journal_entries
FOR ALL TO authenticated
USING (owner_id = private.current_profile_id() OR private.is_admin())
WITH CHECK (owner_id = private.current_profile_id() OR private.is_admin());

CREATE POLICY academic_terms_owner_all ON public.academic_terms
FOR ALL TO authenticated
USING (owner_id = private.current_profile_id() OR private.is_admin())
WITH CHECK (owner_id = private.current_profile_id() OR private.is_admin());

CREATE POLICY subjects_owner_all ON public.subjects
FOR ALL TO authenticated
USING (owner_id = private.current_profile_id() OR private.is_admin())
WITH CHECK (owner_id = private.current_profile_id() OR private.is_admin());

CREATE POLICY assignments_owner_all ON public.assignments
FOR ALL TO authenticated
USING (owner_id = private.current_profile_id() OR private.is_admin())
WITH CHECK (owner_id = private.current_profile_id() OR private.is_admin());

CREATE POLICY exams_owner_all ON public.exams
FOR ALL TO authenticated
USING (owner_id = private.current_profile_id() OR private.is_admin())
WITH CHECK (owner_id = private.current_profile_id() OR private.is_admin());

CREATE POLICY calendar_events_owner_all ON public.calendar_events
FOR ALL TO authenticated
USING (owner_id = private.current_profile_id() OR private.is_admin())
WITH CHECK (
  (owner_id = private.current_profile_id() OR private.is_admin())
  AND (related_task_id IS NULL OR private.can_access_task(related_task_id))
  AND (related_goal_id IS NULL OR private.can_access_goal(related_goal_id))
  AND (related_project_id IS NULL OR private.can_access_project(related_project_id))
  AND (related_exam_id IS NULL OR private.can_access_entity('exam', related_exam_id))
);

CREATE POLICY notifications_select_recipient_or_admin ON public.notifications
FOR SELECT TO authenticated
USING (recipient_id = private.current_profile_id() OR private.is_admin());

CREATE POLICY notifications_update_read_state ON public.notifications
FOR UPDATE TO authenticated
USING (recipient_id = private.current_profile_id())
WITH CHECK (recipient_id = private.current_profile_id());

CREATE POLICY notification_preferences_owner_all ON public.notification_preferences
FOR ALL TO authenticated
USING (user_id = private.current_profile_id() OR private.is_admin())
WITH CHECK (user_id = private.current_profile_id() OR private.is_admin());

CREATE POLICY comments_select_entity_access ON public.comments
FOR SELECT TO authenticated
USING (private.can_access_entity(entity_type, entity_id));

CREATE POLICY comments_insert_entity_access ON public.comments
FOR INSERT TO authenticated
WITH CHECK (
  user_id = private.current_profile_id()
  AND private.can_access_entity(entity_type, entity_id)
);

CREATE POLICY comments_update_author ON public.comments
FOR UPDATE TO authenticated
USING (user_id = private.current_profile_id() AND private.can_access_entity(entity_type, entity_id))
WITH CHECK (user_id = private.current_profile_id() AND private.can_access_entity(entity_type, entity_id));

CREATE POLICY comments_delete_author_or_admin ON public.comments
FOR DELETE TO authenticated
USING (user_id = private.current_profile_id() OR private.is_admin());

CREATE POLICY comment_mentions_select_authorized ON public.comment_mentions
FOR SELECT TO authenticated
USING (
  mentioned_user_id = private.current_profile_id()
  OR EXISTS (
    SELECT 1 FROM public.comments AS c
    WHERE c.id = comment_id
      AND private.can_access_entity(c.entity_type, c.entity_id)
  )
);

CREATE POLICY comment_mentions_insert_comment_author ON public.comment_mentions
FOR INSERT TO authenticated
WITH CHECK (EXISTS (
  SELECT 1 FROM public.comments AS c
  WHERE c.id = comment_id
    AND c.user_id = private.current_profile_id()
    AND private.can_access_entity(c.entity_type, c.entity_id)
));

CREATE POLICY comment_mentions_delete_comment_author ON public.comment_mentions
FOR DELETE TO authenticated
USING (EXISTS (
  SELECT 1 FROM public.comments AS c
  WHERE c.id = comment_id AND c.user_id = private.current_profile_id()
));

CREATE POLICY activity_events_select_authorized ON public.activity_events
FOR SELECT TO authenticated
USING (private.is_admin() OR private.can_access_entity(entity_type, entity_id));

CREATE POLICY activity_events_insert_actor ON public.activity_events
FOR INSERT TO authenticated
WITH CHECK (
  actor_id = private.current_profile_id()
  AND private.can_access_entity(entity_type, entity_id)
);

CREATE POLICY conversations_select_metadata ON public.conversations
FOR SELECT TO authenticated
USING (private.is_admin() OR private.is_conversation_member(id));

CREATE POLICY conversations_insert_creator ON public.conversations
FOR INSERT TO authenticated
WITH CHECK (created_by = private.current_profile_id());

CREATE POLICY conversations_update_creator_or_admin ON public.conversations
FOR UPDATE TO authenticated
USING (created_by = private.current_profile_id() OR private.is_admin())
WITH CHECK (created_by = private.current_profile_id() OR private.is_admin());

CREATE POLICY conversations_delete_creator ON public.conversations
FOR DELETE TO authenticated
USING (created_by = private.current_profile_id());

CREATE POLICY conversation_members_select_metadata ON public.conversation_members
FOR SELECT TO authenticated
USING (
  user_id = private.current_profile_id()
  OR private.is_admin()
  OR private.is_conversation_member(conversation_id)
  OR EXISTS (
    SELECT 1 FROM public.conversations AS c
    WHERE c.id = conversation_id AND c.created_by = private.current_profile_id()
  )
);

CREATE POLICY conversation_members_insert_participant_manager ON public.conversation_members
FOR INSERT TO authenticated
WITH CHECK (private.can_manage_conversation(conversation_id));

CREATE POLICY conversation_members_delete_self_or_manager ON public.conversation_members
FOR DELETE TO authenticated
USING (
  user_id = private.current_profile_id()
  OR private.can_manage_conversation(conversation_id)
);

CREATE POLICY messages_select_participants_only ON public.messages
FOR SELECT TO authenticated
USING (private.is_conversation_member(conversation_id));

CREATE POLICY messages_insert_participants_only ON public.messages
FOR INSERT TO authenticated
WITH CHECK (
  sender_id = private.current_profile_id()
  AND private.is_conversation_member(conversation_id)
);

CREATE POLICY messages_update_sender_participant_only ON public.messages
FOR UPDATE TO authenticated
USING (
  sender_id = private.current_profile_id()
  AND private.is_conversation_member(conversation_id)
)
WITH CHECK (
  sender_id = private.current_profile_id()
  AND private.is_conversation_member(conversation_id)
);

CREATE POLICY messages_delete_sender_participant_only ON public.messages
FOR DELETE TO authenticated
USING (
  sender_id = private.current_profile_id()
  AND private.is_conversation_member(conversation_id)
);

CREATE POLICY user_gamification_select_self_or_admin ON public.user_gamification
FOR SELECT TO authenticated
USING (user_id = private.current_profile_id() OR private.is_admin());

CREATE POLICY achievements_select_authenticated ON public.achievements
FOR SELECT TO authenticated
USING (TRUE);

CREATE POLICY user_achievements_select_self_or_admin ON public.user_achievements
FOR SELECT TO authenticated
USING (user_id = private.current_profile_id() OR private.is_admin());

CREATE POLICY xp_transactions_select_self_or_admin ON public.xp_transactions
FOR SELECT TO authenticated
USING (user_id = private.current_profile_id() OR private.is_admin());

CREATE POLICY user_streaks_select_self_or_admin ON public.user_streaks
FOR SELECT TO authenticated
USING (user_id = private.current_profile_id() OR private.is_admin());

CREATE POLICY user_preferences_owner_all ON public.user_preferences
FOR ALL TO authenticated
USING (user_id = private.current_profile_id() OR private.is_admin())
WITH CHECK (user_id = private.current_profile_id() OR private.is_admin());

CREATE POLICY audit_logs_admin_select ON public.audit_logs
FOR SELECT TO authenticated
USING (private.is_admin());

CREATE POLICY external_links_select_entity_access ON public.external_links
FOR SELECT TO authenticated
USING (
  owner_id = private.current_profile_id()
  OR private.is_admin()
  OR private.can_access_entity(entity_type, entity_id)
);

CREATE POLICY external_links_insert_owner ON public.external_links
FOR INSERT TO authenticated
WITH CHECK (
  owner_id = private.current_profile_id()
  AND private.can_access_entity(entity_type, entity_id)
);

CREATE POLICY external_links_update_owner ON public.external_links
FOR UPDATE TO authenticated
USING (owner_id = private.current_profile_id() OR private.is_admin())
WITH CHECK (
  (owner_id = private.current_profile_id() OR private.is_admin())
  AND private.can_access_entity(entity_type, entity_id)
);

CREATE POLICY external_links_delete_owner ON public.external_links
FOR DELETE TO authenticated
USING (owner_id = private.current_profile_id() OR private.is_admin());

GRANT USAGE ON SCHEMA public TO authenticated, service_role;

GRANT SELECT ON public.profiles TO authenticated;
GRANT UPDATE (username, display_name, avatar_url, bio, academic_info, interests)
ON public.profiles TO authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE ON
  public.goals, public.goal_members, public.projects, public.project_members,
  public.milestones, public.tasks, public.task_assignees, public.task_dependencies,
  public.task_recurrences, public.task_instances, public.habits, public.habit_entries,
  public.daily_goals, public.focus_sessions, public.journal_entries, public.academic_terms,
  public.subjects, public.assignments, public.exams, public.calendar_events,
  public.notification_preferences, public.comments, public.comment_mentions,
  public.conversations, public.conversation_members, public.user_preferences,
  public.external_links
TO authenticated;

GRANT SELECT ON public.notifications TO authenticated;
GRANT UPDATE (read_at) ON public.notifications TO authenticated;
GRANT SELECT, INSERT ON public.activity_events TO authenticated;
GRANT SELECT, INSERT, DELETE ON public.messages TO authenticated;
GRANT UPDATE (content, deleted_at) ON public.messages TO authenticated;
GRANT SELECT ON public.user_gamification, public.achievements,
  public.user_achievements, public.xp_transactions, public.user_streaks,
  public.audit_logs TO authenticated;
