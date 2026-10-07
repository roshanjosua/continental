# Technology stack

This project is locked to the following technology choices for V1.0 and future implementation versions unless a genuine technical incompatibility is discovered.

## Frontend

- Next.js: application framework for the React UI and static export compatibility.
- React: component-based user interface library.
- TypeScript: static typing and safer application development.
- Tailwind CSS: utility-first styling foundation.
- shadcn/ui: consistent component primitives and design system foundation.

## Backend and data

- Supabase: backend platform providing authentication, PostgreSQL, Row Level Security, Realtime, and Edge Functions.
- PostgreSQL: authoritative relational database for persistent application data.

## Authentication and authorization

- Supabase Auth: handles authentication flows.
- PostgreSQL RLS: final authorization boundary for stored data.

## Data fetching and state

- TanStack Query: client-side server state management.

## Quality and testing

- Vitest: unit and component validation.
- Playwright: browser smoke testing and end-to-end verification.

## PWA and delivery

- Web App Manifest: foundation for installable web application metadata.
- Service Worker: future offline capability foundation.
- IndexedDB: later offline persistence and synchronization layer.

## Versioning, operations, and hosting

- Git and GitHub: version control and collaboration.
- GitHub Actions: CI pipeline for quality checks.
- Cloudflare Pages: static host for the production frontend.
