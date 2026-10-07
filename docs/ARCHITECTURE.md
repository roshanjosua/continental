# Architecture

## System overview

Users
↓
Next.js / React / PWA
↓
Supabase
├── Auth
├── PostgreSQL
├── RLS
├── Realtime
└── Edge Functions

## Current design intent

- PostgreSQL is the authoritative source for persistent application data.
- PostgreSQL Row Level Security is the final authorization boundary.
- Supabase Auth handles user authentication.
- Realtime provides authorized live updates for clients that are permitted to access the relevant data.
- Edge Functions handle privileged server-side operations that cannot be performed safely from the browser.
- The frontend is statically deployed and is designed to remain compatible with Cloudflare Pages.
- Offline support will use IndexedDB in a later implementation version.
- TanStack Query manages server state on the client.
- Ordered SQL migrations in `supabase/migrations/` are the source of truth for the PostgreSQL schema.
- Local development uses an isolated Supabase stack. Hosted development targets DEV; production migrations require a deliberate release action.
- Browser credentials are limited to the Supabase URL and anon/publishable key. Database passwords, access tokens, and service-role keys are never exposed to browser code.

## Chat-specific security boundary

Chat messages have a special security boundary: ADMIN users must not automatically have access to chat message contents. Only conversation participants can access message contents. This requirement remains unchanged in all future implementation versions.

## Deployment and static hosting

This application is intentionally designed to avoid server-side database access and dynamic rendering in the browser flow. The production frontend is expected to be deployed as a static Next.js build to Cloudflare Pages, while Supabase provides the runtime backend services.

## Database security boundaries

RLS is enabled on every application table. `private` schema helper functions use fixed search paths and are granted only to roles that need them. Administrators have broad application-data access, but chat message rows are excluded from the administrator bypass and remain conversation-participant-only. Audit records are append-only to clients, and XP/currency values are writable only by trusted server operations.
