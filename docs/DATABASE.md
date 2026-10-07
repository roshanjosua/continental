# Database foundation

## Schema overview

The PostgreSQL schema is organized into four ordered migrations:

1. Core extension, approved enums, profiles, profile/auth synchronization, timestamp and active-admin safeguards.
2. Goals, projects, milestones, tasks and recurrence, habits/productivity, academic records, calendar, and notifications.
3. Collaboration, participant-based chat, gamification records, audit logs, and external links.
4. Table grants and row-level security policies.

The migration files are the schema source of truth. There are no dashboard-only schema changes, application file storage, task stopwatch fields, attendance tables, marks, GPA, or CGPA.

## DEV and PROD separation

There are two hosted Supabase projects: DEV and PROD. Local development uses the local Supabase CLI stack and committed migrations, not PROD. Hosted development and migration experimentation target DEV only.

Do not put database passwords, Supabase access tokens, or service-role keys in browser-prefixed variables. `.env.example` contains safe variable names only. `SUPABASE_DEV_PROJECT_REF`, `SUPABASE_DEV_DB_PASSWORD`, and `SUPABASE_ACCESS_TOKEN` are for CLI workflows; keep their actual values in ignored local environment files or an approved secret store. Map the DEV database password to the CLI's `SUPABASE_DB_PASSWORD` only in the shell/session used for an explicit DEV operation.

PROD is intentionally not linked, migrated, or configured by this version. Before a future production migration, verify the target project ref, review the migration diff, back up according to the release process, and require an explicit release approval. Never use PROD for local development or migration experiments.

## Migration workflow

The repository database scripts invoke Supabase CLI 2.120.0 through `npx` (network access is needed on first use). With Docker running, use:

```bash
npm run db:start
npm run db:test
npm run db:reset
npm run db:stop
```

`db:reset` targets only the local CLI stack. It discards that local database and reapplies all committed migrations. Do not run it against a hosted project.

To prepare an explicit hosted DEV migration, set the DEV-only project ref and CLI credentials, link to DEV, inspect `supabase db push --dry-run`, then apply only after review. Do not add automatic remote migration deployment to CI. The GitHub Actions job starts a fresh local stack and runs database tests only.

## PostgreSQL rules

- `pgcrypto` is the only application extension enabled by migrations; it supports UUID generation.
- Application entity primary keys are UUIDs.
- Moments use `TIMESTAMPTZ`; date-only concepts use `DATE`. There are no per-user timezone columns. The application timezone is Asia/Kolkata.
- Mutable records receive database-generated `created_at`/`updated_at` values where specified.
- PostgreSQL constraints enforce date, range, positive-value, uniqueness, and foreign-key rules.
- Task dependencies reject self-references and cycles in a serialized database trigger.
- Profile creation and auth email synchronization are database-triggered; passwords remain exclusively in Supabase Auth.
- The first active administrator is bootstrapped only through a service-role request. A transaction-level advisory lock plus trigger prevents removal/demotion of the last active admin.

## Deletion strategy

Permanent parent deletion cascades into intrinsically owned child records: goal/project memberships, project milestones, task assignments/dependencies/recurrences/instances, habit entries, academic subjects and their assignments/exams, conversation membership/messages, and per-user records.

References that should preserve shared or historical records use `SET NULL`: task goal/project/milestone/parent links, calendar related resources, deleting users from audit actors, and `deleted_by` attribution. Most user-facing entities also support soft deletion through `deleted_at` and `deleted_by`; no permanent conflict flag is stored for calendar events.

## RLS philosophy

RLS is enabled on every application table and is the final authorization boundary. Active users may access their own private data and resources shared through explicit memberships. Administrators receive broad application-data access except for the explicit chat restriction. Client grants further restrict sensitive columns and protected tables; frontend visibility is not authorization.

Profiles default to `USER`; authenticated clients cannot update profile roles, active-admin state, or email. Authenticated clients cannot write audit logs or directly mutate XP, level, achievement currency, transaction history, or streak records. Trusted service operations remain responsible for protected changes.

## Chat security boundary

Message `SELECT` requires membership in the corresponding conversation. Admin role is deliberately absent from every messages policy. Message inserts require that `sender_id` matches the current profile and that profile is a conversation member. Updates/deletes are restricted to the sender while they remain a member. Administrators who are not participants can inspect limited conversation metadata under the general admin policy but cannot read message contents.

## Database tests

`supabase/tests/*.test.sql` contains pgTAP structural and behavioral suites. Tests cover schema/enums, constraints and indexes, timestamp and auth-profile triggers, profile defaults, active-admin protection, shared-project access, protected gamification writes, and positive/negative chat membership behavior including a nonparticipant administrator.

The CI workflow starts a fresh local Supabase stack and runs `supabase test db`. The V1.1 migrations were applied to a fresh local Supabase Postgres 15 stack and both pgTAP suites passed (48 assertions total). The same four migrations were applied to the explicitly linked `continental-dev` project; the remote migration ledger matches local, `supabase db lint --linked` reported no schema errors, and a read-only catalog check found 37/37 RLS-enabled application tables, none without policies, and no message admin-bypass policy. PROD remains intentionally untouched.
