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

## Chat-specific security boundary

Chat messages have a special security boundary: ADMIN users must not automatically have access to chat message contents. Only conversation participants can access message contents. This requirement remains unchanged in all future implementation versions.

## Deployment and static hosting

This application is intentionally designed to avoid server-side database access and dynamic rendering in the browser flow. The production frontend is expected to be deployed as a static Next.js build to Cloudflare Pages, while Supabase provides the runtime backend services.
