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
- A Supabase project for later integration

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

- This application is intentionally not feature-complete in V1.0.
- No authentication flows, data models, dashboards, or core feature modules are implemented here.
- The project is structured to support future versions without architectural redesign.
