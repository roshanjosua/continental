CREATE TABLE public.goals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  category public.goal_category NOT NULL,
  duration_type public.goal_duration NOT NULL,
  start_date DATE NOT NULL,
  target_date DATE,
  priority public.priority NOT NULL DEFAULT 'MEDIUM',
  status public.goal_status NOT NULL DEFAULT 'NOT_STARTED',
  progress_mode public.goal_progress_mode NOT NULL DEFAULT 'MANUAL',
  manual_progress SMALLINT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ,
  deleted_at TIMESTAMPTZ,
  deleted_by UUID REFERENCES public.profiles (id) ON DELETE SET NULL,
  CONSTRAINT goals_manual_progress_range CHECK (manual_progress IS NULL OR manual_progress BETWEEN 0 AND 100),
  CONSTRAINT goals_task_based_progress_is_derived CHECK (progress_mode <> 'TASK_BASED' OR manual_progress IS NULL),
  CONSTRAINT goals_target_not_before_start CHECK (target_date IS NULL OR target_date >= start_date)
);

CREATE TABLE public.goal_members (
  goal_id UUID NOT NULL REFERENCES public.goals (id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  role public.member_role NOT NULL DEFAULT 'MEMBER',
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (goal_id, user_id)
);

CREATE TABLE public.projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  status public.project_status NOT NULL DEFAULT 'PLANNED',
  priority public.priority NOT NULL DEFAULT 'MEDIUM',
  start_date DATE,
  target_date DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ,
  deleted_at TIMESTAMPTZ,
  deleted_by UUID REFERENCES public.profiles (id) ON DELETE SET NULL,
  CONSTRAINT projects_name_nonempty CHECK (length(btrim(name)) > 0),
  CONSTRAINT projects_target_not_before_start CHECK (
    start_date IS NULL OR target_date IS NULL OR target_date >= start_date
  ),
  CONSTRAINT projects_id_owner_unique UNIQUE (id, owner_id)
);

CREATE TABLE public.project_members (
  project_id UUID NOT NULL REFERENCES public.projects (id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  role public.member_role NOT NULL DEFAULT 'MEMBER',
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (project_id, user_id)
);

CREATE TABLE public.milestones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES public.projects (id) ON DELETE CASCADE,
  goal_id UUID REFERENCES public.goals (id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  due_date DATE,
  priority public.priority NOT NULL DEFAULT 'MEDIUM',
  status TEXT NOT NULL DEFAULT 'NOT_STARTED',
  progress SMALLINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ,
  deleted_at TIMESTAMPTZ,
  deleted_by UUID REFERENCES public.profiles (id) ON DELETE SET NULL,
  CONSTRAINT milestones_progress_range CHECK (progress BETWEEN 0 AND 100),
  CONSTRAINT milestones_title_nonempty CHECK (length(btrim(title)) > 0)
);

CREATE TABLE public.tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  creator_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  status public.task_status NOT NULL DEFAULT 'TODO',
  priority public.priority NOT NULL DEFAULT 'MEDIUM',
  category TEXT,
  goal_id UUID REFERENCES public.goals (id) ON DELETE SET NULL,
  milestone_id UUID REFERENCES public.milestones (id) ON DELETE SET NULL,
  project_id UUID REFERENCES public.projects (id) ON DELETE SET NULL,
  parent_task_id UUID REFERENCES public.tasks (id) ON DELETE SET NULL,
  due_date DATE,
  due_time TIME WITHOUT TIME ZONE,
  estimated_minutes INTEGER,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ,
  completion_notes TEXT,
  deleted_at TIMESTAMPTZ,
  deleted_by UUID REFERENCES public.profiles (id) ON DELETE SET NULL,
  CONSTRAINT tasks_title_nonempty CHECK (length(btrim(title)) > 0),
  CONSTRAINT tasks_estimated_minutes_positive CHECK (estimated_minutes IS NULL OR estimated_minutes > 0)
);

CREATE TABLE public.task_assignees (
  task_id UUID NOT NULL REFERENCES public.tasks (id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  assigned_by UUID REFERENCES public.profiles (id) ON DELETE SET NULL,
  PRIMARY KEY (task_id, user_id)
);

CREATE TABLE public.task_dependencies (
  task_id UUID NOT NULL REFERENCES public.tasks (id) ON DELETE CASCADE,
  depends_on_task_id UUID NOT NULL REFERENCES public.tasks (id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (task_id, depends_on_task_id),
  CONSTRAINT task_dependencies_not_self CHECK (task_id <> depends_on_task_id)
);

CREATE TABLE public.task_recurrences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES public.tasks (id) ON DELETE CASCADE,
  frequency public.recurrence_frequency NOT NULL,
  interval INTEGER NOT NULL DEFAULT 1,
  days_of_week SMALLINT[],
  day_of_month SMALLINT,
  start_date DATE NOT NULL,
  end_date DATE,
  next_occurrence DATE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT task_recurrences_interval_positive CHECK (interval > 0),
  CONSTRAINT task_recurrences_end_not_before_start CHECK (end_date IS NULL OR end_date >= start_date),
  CONSTRAINT task_recurrences_day_of_month_valid CHECK (day_of_month IS NULL OR day_of_month BETWEEN 1 AND 31),
  CONSTRAINT task_recurrences_days_of_week_valid CHECK (
    days_of_week IS NULL OR (
      cardinality(days_of_week) BETWEEN 1 AND 7
      AND 0 <= ALL (days_of_week)
      AND 6 >= ALL (days_of_week)
    )
  ),
  CONSTRAINT task_recurrences_custom_has_schedule CHECK (
    frequency <> 'CUSTOM' OR days_of_week IS NOT NULL OR day_of_month IS NOT NULL
  ),
  CONSTRAINT task_recurrences_id_task_unique UNIQUE (id, task_id)
);

CREATE TABLE public.task_instances (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recurrence_id UUID NOT NULL,
  task_id UUID NOT NULL,
  scheduled_date DATE NOT NULL,
  scheduled_time TIME WITHOUT TIME ZONE,
  status public.task_status NOT NULL DEFAULT 'TODO',
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT task_instances_recurrence_date_unique UNIQUE (recurrence_id, scheduled_date),
  CONSTRAINT task_instances_recurrence_task_fk FOREIGN KEY (recurrence_id, task_id)
    REFERENCES public.task_recurrences (id, task_id) ON DELETE CASCADE
);

CREATE TABLE public.habits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  frequency public.habit_frequency NOT NULL,
  target NUMERIC(10, 2) NOT NULL,
  unit TEXT NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE,
  priority public.priority NOT NULL DEFAULT 'MEDIUM',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  deleted_by UUID REFERENCES public.profiles (id) ON DELETE SET NULL,
  CONSTRAINT habits_target_positive CHECK (target > 0),
  CONSTRAINT habits_end_not_before_start CHECK (end_date IS NULL OR end_date >= start_date),
  CONSTRAINT habits_name_nonempty CHECK (length(btrim(name)) > 0)
);

CREATE TABLE public.habit_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  habit_id UUID NOT NULL REFERENCES public.habits (id) ON DELETE CASCADE,
  date DATE NOT NULL,
  status public.habit_entry_status NOT NULL,
  value NUMERIC(10, 2),
  notes TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT habit_entries_value_nonnegative CHECK (value IS NULL OR value >= 0),
  CONSTRAINT habit_entries_habit_date_unique UNIQUE (habit_id, date)
);

CREATE TABLE public.daily_goals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  date DATE NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  target_value NUMERIC(10, 2),
  target_unit TEXT,
  status TEXT NOT NULL DEFAULT 'NOT_STARTED',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT daily_goals_target_positive CHECK (target_value IS NULL OR target_value > 0),
  CONSTRAINT daily_goals_target_unit_requires_value CHECK (target_unit IS NULL OR target_value IS NOT NULL)
);

CREATE TABLE public.focus_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  task_id UUID REFERENCES public.tasks (id) ON DELETE SET NULL,
  goal_id UUID REFERENCES public.goals (id) ON DELETE SET NULL,
  started_at TIMESTAMPTZ NOT NULL,
  ended_at TIMESTAMPTZ,
  duration_minutes INTEGER,
  session_type public.focus_session_type NOT NULL DEFAULT 'FOCUS',
  completed BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT focus_sessions_end_after_start CHECK (ended_at IS NULL OR ended_at >= started_at),
  CONSTRAINT focus_sessions_duration_positive CHECK (duration_minutes IS NULL OR duration_minutes > 0)
);

CREATE TABLE public.journal_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  date DATE NOT NULL,
  content TEXT NOT NULL,
  mood TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  deleted_by UUID REFERENCES public.profiles (id) ON DELETE SET NULL
);

CREATE TABLE public.academic_terms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  academic_year TEXT NOT NULL,
  semester SMALLINT NOT NULL,
  name TEXT NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  is_current BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT academic_terms_semester_valid CHECK (semester BETWEEN 1 AND 8),
  CONSTRAINT academic_terms_end_not_before_start CHECK (end_date >= start_date),
  CONSTRAINT academic_terms_owner_year_semester_unique UNIQUE (owner_id, academic_year, semester),
  CONSTRAINT academic_terms_id_owner_unique UNIQUE (id, owner_id)
);

CREATE TABLE public.subjects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  term_id UUID NOT NULL,
  name TEXT NOT NULL,
  code TEXT,
  faculty TEXT,
  credits NUMERIC(4, 1),
  schedule JSONB,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  deleted_by UUID REFERENCES public.profiles (id) ON DELETE SET NULL,
  CONSTRAINT subjects_term_owner_fk FOREIGN KEY (term_id, owner_id)
    REFERENCES public.academic_terms (id, owner_id) ON DELETE CASCADE,
  CONSTRAINT subjects_credits_positive CHECK (credits IS NULL OR credits > 0),
  CONSTRAINT subjects_id_owner_unique UNIQUE (id, owner_id)
);

CREATE TABLE public.assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  subject_id UUID NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  assigned_date DATE,
  due_date DATE,
  priority public.priority NOT NULL DEFAULT 'MEDIUM',
  status public.assignment_status NOT NULL DEFAULT 'NOT_STARTED',
  submission_url TEXT,
  notes TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ,
  deleted_at TIMESTAMPTZ,
  deleted_by UUID REFERENCES public.profiles (id) ON DELETE SET NULL,
  CONSTRAINT assignments_subject_owner_fk FOREIGN KEY (subject_id, owner_id)
    REFERENCES public.subjects (id, owner_id) ON DELETE CASCADE,
  CONSTRAINT assignments_due_not_before_assigned CHECK (
    assigned_date IS NULL OR due_date IS NULL OR due_date >= assigned_date
  )
);

CREATE TABLE public.exams (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  subject_id UUID NOT NULL,
  title TEXT NOT NULL,
  exam_type public.exam_type NOT NULL,
  date DATE NOT NULL,
  start_time TIME WITHOUT TIME ZONE,
  end_time TIME WITHOUT TIME ZONE,
  venue TEXT,
  syllabus TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  deleted_by UUID REFERENCES public.profiles (id) ON DELETE SET NULL,
  CONSTRAINT exams_subject_owner_fk FOREIGN KEY (subject_id, owner_id)
    REFERENCES public.subjects (id, owner_id) ON DELETE CASCADE,
  CONSTRAINT exams_end_after_start CHECK (
    start_time IS NULL OR end_time IS NULL OR end_time > start_time
  )
);

CREATE TABLE public.calendar_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  event_type TEXT NOT NULL,
  start_at TIMESTAMPTZ NOT NULL,
  end_at TIMESTAMPTZ NOT NULL,
  location TEXT,
  related_task_id UUID REFERENCES public.tasks (id) ON DELETE SET NULL,
  related_goal_id UUID REFERENCES public.goals (id) ON DELETE SET NULL,
  related_project_id UUID REFERENCES public.projects (id) ON DELETE SET NULL,
  related_exam_id UUID REFERENCES public.exams (id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  deleted_by UUID REFERENCES public.profiles (id) ON DELETE SET NULL,
  CONSTRAINT calendar_events_end_after_start CHECK (end_at > start_at)
);

CREATE TABLE public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  related_entity_type TEXT,
  related_entity_id UUID,
  scheduled_at TIMESTAMPTZ,
  sent_at TIMESTAMPTZ,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.notification_preferences (
  user_id UUID PRIMARY KEY REFERENCES public.profiles (id) ON DELETE CASCADE,
  task_reminders BOOLEAN NOT NULL DEFAULT TRUE,
  goal_reminders BOOLEAN NOT NULL DEFAULT TRUE,
  exam_reminders BOOLEAN NOT NULL DEFAULT TRUE,
  assignment_reminders BOOLEAN NOT NULL DEFAULT TRUE,
  habit_reminders BOOLEAN NOT NULL DEFAULT TRUE,
  morning_plan BOOLEAN NOT NULL DEFAULT FALSE,
  evening_review BOOLEAN NOT NULL DEFAULT FALSE,
  streak_warning BOOLEAN NOT NULL DEFAULT TRUE,
  conflict_warning BOOLEAN NOT NULL DEFAULT TRUE,
  push_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  email_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  quiet_hours_start TIME WITHOUT TIME ZONE,
  quiet_hours_end TIME WITHOUT TIME ZONE,
  default_reminder_minutes INTEGER[] NOT NULL DEFAULT ARRAY[15],
  CONSTRAINT notification_preferences_quiet_hours_pair CHECK (
    (quiet_hours_start IS NULL) = (quiet_hours_end IS NULL)
  ),
  CONSTRAINT notification_preferences_reminder_minutes_positive CHECK (
    0 < ALL (default_reminder_minutes)
  )
);

CREATE TRIGGER goals_set_updated_at BEFORE UPDATE ON public.goals
FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER projects_set_updated_at BEFORE UPDATE ON public.projects
FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER milestones_set_updated_at BEFORE UPDATE ON public.milestones
FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER tasks_set_updated_at BEFORE UPDATE ON public.tasks
FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER task_recurrences_set_updated_at BEFORE UPDATE ON public.task_recurrences
FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER habits_set_updated_at BEFORE UPDATE ON public.habits
FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER daily_goals_set_updated_at BEFORE UPDATE ON public.daily_goals
FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER journal_entries_set_updated_at BEFORE UPDATE ON public.journal_entries
FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER academic_terms_set_updated_at BEFORE UPDATE ON public.academic_terms
FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER subjects_set_updated_at BEFORE UPDATE ON public.subjects
FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER assignments_set_updated_at BEFORE UPDATE ON public.assignments
FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER exams_set_updated_at BEFORE UPDATE ON public.exams
FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER calendar_events_set_updated_at BEFORE UPDATE ON public.calendar_events
FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
