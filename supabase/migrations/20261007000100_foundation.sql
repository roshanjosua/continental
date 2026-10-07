CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC;
GRANT USAGE ON SCHEMA private TO authenticated, service_role;

CREATE TYPE public.user_role AS ENUM ('ADMIN', 'USER');
CREATE TYPE public.goal_category AS ENUM (
  'ACADEMIC',
  'CAREER',
  'PERSONAL_DEVELOPMENT',
  'HEALTH_FITNESS',
  'FINANCIAL',
  'HOBBY_INTEREST',
  'CUSTOM'
);
CREATE TYPE public.goal_duration AS ENUM (
  'DAILY',
  'WEEKLY',
  'MONTHLY',
  'LONG_TERM',
  'CUSTOM'
);
CREATE TYPE public.priority AS ENUM ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL');
CREATE TYPE public.goal_status AS ENUM (
  'NOT_STARTED',
  'IN_PROGRESS',
  'COMPLETED',
  'PAUSED',
  'ABANDONED'
);
CREATE TYPE public.goal_progress_mode AS ENUM ('MANUAL', 'TASK_BASED');
CREATE TYPE public.project_status AS ENUM (
  'PLANNED',
  'IN_PROGRESS',
  'ON_HOLD',
  'COMPLETED',
  'CANCELLED'
);
CREATE TYPE public.member_role AS ENUM ('OWNER', 'MEMBER');
CREATE TYPE public.task_status AS ENUM (
  'TODO',
  'IN_PROGRESS',
  'COMPLETED',
  'SKIPPED',
  'CANCELLED'
);
CREATE TYPE public.recurrence_frequency AS ENUM (
  'DAILY',
  'WEEKDAYS',
  'WEEKLY',
  'MONTHLY',
  'CUSTOM'
);
CREATE TYPE public.habit_frequency AS ENUM ('DAILY', 'WEEKLY', 'CUSTOM');
CREATE TYPE public.habit_entry_status AS ENUM ('COMPLETED', 'MISSED', 'SKIPPED', 'PARTIAL');
CREATE TYPE public.assignment_status AS ENUM (
  'NOT_STARTED',
  'IN_PROGRESS',
  'COMPLETED',
  'SUBMITTED',
  'LATE',
  'CANCELLED'
);
CREATE TYPE public.exam_type AS ENUM ('INTERNAL', 'MODEL', 'SEMESTER', 'PRACTICAL', 'VIVA', 'CUSTOM');
CREATE TYPE public.conversation_type AS ENUM ('DIRECT', 'GROUP', 'PROJECT');
CREATE TYPE public.focus_session_type AS ENUM ('FOCUS', 'SHORT_BREAK', 'LONG_BREAK', 'CUSTOM');
CREATE TYPE public.streak_type AS ENUM ('TASK', 'GOAL', 'HABIT', 'FOCUS', 'PRODUCTIVITY');

CREATE TABLE public.profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_user_id UUID NOT NULL UNIQUE REFERENCES auth.users (id) ON DELETE CASCADE,
  username TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  email TEXT NOT NULL,
  avatar_url TEXT,
  bio TEXT,
  academic_info TEXT,
  interests TEXT,
  role public.user_role NOT NULL DEFAULT 'USER',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT profiles_username_lowercase CHECK (username = lower(username)),
  CONSTRAINT profiles_username_nonempty CHECK (length(btrim(username)) > 0),
  CONSTRAINT profiles_display_name_nonempty CHECK (length(btrim(display_name)) > 0),
  CONSTRAINT profiles_email_nonempty CHECK (length(btrim(email)) > 0)
);

CREATE FUNCTION private.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $function$
BEGIN
  NEW.updated_at := clock_timestamp();
  RETURN NEW;
END;
$function$;

CREATE FUNCTION private.normalize_profile_username()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $function$
BEGIN
  NEW.username := lower(btrim(NEW.username));
  RETURN NEW;
END;
$function$;

CREATE TRIGGER profiles_normalize_username
BEFORE INSERT OR UPDATE OF username ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION private.normalize_profile_username();

CREATE TRIGGER profiles_set_updated_at
BEFORE UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION private.set_updated_at();

REVOKE ALL ON FUNCTION private.set_updated_at() FROM PUBLIC;
REVOKE ALL ON FUNCTION private.normalize_profile_username() FROM PUBLIC;

CREATE FUNCTION private.current_profile_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT p.id
  FROM public.profiles AS p
  WHERE p.auth_user_id = auth.uid()
    AND p.is_active
  LIMIT 1;
$function$;

CREATE FUNCTION private.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles AS p
    WHERE p.auth_user_id = auth.uid()
      AND p.role = 'ADMIN'::public.user_role
      AND p.is_active
  );
$function$;

CREATE FUNCTION private.protect_last_active_admin()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  remaining_admins BIGINT;
  removes_active_admin BOOLEAN;
BEGIN
  removes_active_admin := OLD.role = 'ADMIN'::public.user_role AND OLD.is_active;

  IF TG_OP = 'UPDATE' THEN
    removes_active_admin := removes_active_admin
      AND (NEW.role <> 'ADMIN'::public.user_role OR NOT NEW.is_active);
  END IF;

  IF removes_active_admin THEN
    PERFORM pg_advisory_xact_lock(165107, 1);

    SELECT count(*)
      INTO remaining_admins
      FROM public.profiles AS p
      WHERE p.role = 'ADMIN'::public.user_role
        AND p.is_active
        AND p.id <> OLD.id;

    IF remaining_admins = 0 THEN
      RAISE EXCEPTION USING
        ERRCODE = '23514',
        MESSAGE = 'at least one active administrator must remain';
    END IF;
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$function$;

CREATE TRIGGER profiles_protect_last_active_admin
BEFORE UPDATE OF role, is_active OR DELETE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION private.protect_last_active_admin();

REVOKE ALL ON FUNCTION private.protect_last_active_admin() FROM PUBLIC;

CREATE FUNCTION private.bootstrap_first_admin(p_auth_user_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  profile_id UUID;
BEGIN
  IF COALESCE(auth.jwt() ->> 'role', '') <> 'service_role' THEN
    RAISE EXCEPTION USING
      ERRCODE = '42501',
      MESSAGE = 'first administrator bootstrap requires a service-role request';
  END IF;

  PERFORM pg_advisory_xact_lock(165107, 1);

  IF EXISTS (
    SELECT 1
    FROM public.profiles AS p
    WHERE p.role = 'ADMIN'::public.user_role
      AND p.is_active
  ) THEN
    RAISE EXCEPTION USING
      ERRCODE = '23514',
      MESSAGE = 'an active administrator already exists';
  END IF;

  UPDATE public.profiles
    SET role = 'ADMIN'::public.user_role,
        is_active = TRUE
    WHERE auth_user_id = p_auth_user_id
    RETURNING id INTO profile_id;

  IF profile_id IS NULL THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0002',
      MESSAGE = 'profile for the supplied auth user does not exist';
  END IF;

  RETURN profile_id;
END;
$function$;

REVOKE ALL ON FUNCTION private.bootstrap_first_admin(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.bootstrap_first_admin(UUID) TO service_role;

REVOKE ALL ON FUNCTION private.current_profile_id() FROM PUBLIC;
REVOKE ALL ON FUNCTION private.is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.current_profile_id() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.is_admin() TO authenticated, service_role;
