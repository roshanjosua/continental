# Continental

Continental is a private productivity and collaboration web application under active development. This V1.0 release establishes the repository, development environment, foundations, and required validation checks required before future feature implementation begins.

## Purpose

This project is intended to become a private productivity and academic planning platform with collaboration, accountability, and gamification support for a small team of users. V1.0 intentionally does not implement business features; it sets up a clean, extensible foundation for later versions.

## Technology stack

- Next.js
- React
- TypeScript
- Tailwind CSS
- shadcn/ui
- Supabase
- PostgreSQL
- Supabase Auth
- PostgreSQL Row Level Security
- Supabase Realtime
- Supabase Edge Functions
- TanStack Query
- Vitest
- Playwright
- Cloudflare Pages

## Local development requirements

- Node.js 20+
- npm
- Git
- Docker Desktop for local Supabase services

## Installation

```bash
npm install
```

## Development

```bash
npm run dev
```

Open http://localhost:3000 to view the local application.

## Production build

```bash
npm run build
```

## Testing

```bash
npm run test
npm run test:e2e
```

## Local database development

The local Supabase stack is isolated from both hosted projects and uses the committed migrations:

```bash
npm run db:start
npm run db:test
npm run db:reset
npm run db:stop
```

The database scripts invoke the pinned Supabase CLI 2.120.0 through `npx` (network access is needed on first use). Docker Desktop must be running. Do not link local development to PROD.

## Linting

```bash
npm run lint
```

## Type checking

```bash
npm run typecheck
```

## Project structure

```text
src/
  app/
  components/
  features/
  hooks/
  lib/
  providers/
  types/
  utils/

tests/
  unit/
  e2e/

docs/

supabase/
  migrations/
  seed/
  functions/

.github/
  workflows/
```

## Environment variables

Create a local environment file based on `.env.example`:

```bash
cp .env.example .env.local
```

The browser-safe Supabase keys are:

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`

Do not commit secrets. Do not add browser-side service-role credentials.

## Development workflow

1. Create a feature branch from `main`.
2. Keep changes small and focused.
3. Run linting, type checking, unit tests, and build validation before merging.
4. Keep the application static-export compatible for the eventual Cloudflare Pages deployment.

## Branch strategy

- `main`: protected production-ready branch.
- Feature branches: short-lived branches for focused work.
- Release branches: only when a stable milestone requires staged validation.

## Deployment architecture

The frontend is designed for static deployment to Cloudflare Pages. Supabase provides backend services, while the browser communicates through the Supabase client and future Edge Functions. The application architecture explicitly avoids direct server-only database access in the Next.js frontend layer.

## Important notes

- This application is under active development and is not feature-complete.
- V1.1 establishes database schema and authorization policies only; product feature UI and authentication flows are not implemented.
- Remote migrations must be deliberately linked to DEV. PROD deployment is withheld until its approved release checkpoint.
