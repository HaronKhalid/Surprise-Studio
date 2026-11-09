# Surprise Studio

Personalized digital-surprise platform. Architecture source of truth: [scratchpad.md](scratchpad.md).

## Layout
- `apps/api` NestJS + Prisma REST API
- `apps/web` Next.js public surprise pages (`/s/[slug]`)
- `apps/mobile` Flutter Android creator app
- `packages/*` shared types, config, template schema, validation
- `templates/*` data-driven template definitions ([docs/templates.md](docs/templates.md))
- `docs/*` [API](docs/api.md), architecture, security and deployment notes

## Prerequisites
Node.js >= 20, Docker, Flutter (for mobile).

## Local setup (API)
```
cp .env.example apps/api/.env      # then fill in JWT_SECRET and JWT_REFRESH_SECRET
npm run infra:up                   # Postgres + local S3-compatible storage (RustFS)
cd apps/api
npm install
npx prisma migrate deploy          # create the schema
npm run storage:init               # create the bucket (public read on assets/ only)
npm run templates:seed             # load templates/*/v*.json
npm run start:dev                  # http://localhost:4000/api/v1
```

Optional storage settings in `.env` (`STORAGE_PUBLIC_ENDPOINT`, `STORAGE_PUBLIC_URL`) may be left
blank, which means "use the default". Set `STORAGE_PUBLIC_ENDPOINT=http://10.0.2.2:9000` when testing
from the Android emulator so it can reach storage on your machine.

## Local setup (web)
The public surprise pages render from the API, so start the API first.
```
cd apps/web
npm install
npm run dev                        # http://localhost:3000, surprises at /s/<slug>
```
`API_URL` (server-side, falls back to `NEXT_PUBLIC_API_URL`) points at the API, and
`NEXT_PUBLIC_SITE_URL` is the public origin used in social previews. Defaults work for local development.
Pages are rendered on demand and never cached, so unpublishing or deleting takes effect immediately.

## Local setup (mobile)
Needs the Flutter and Android SDKs. See [docs/mobile.md](docs/mobile.md) for `adb reverse`, `--dart-define`
configuration, signing and the pre-release checklist.
```
cd apps/mobile && flutter pub get && flutter run
```

## Tests
```
cd apps/mobile && flutter analyze && flutter test
cd apps/api && npm test
cd apps/web && npm run typecheck && npm test   # web tests use Node's built-in runner: Node >= 22.18
```
Use `npm test`, not `npx jest`: Nest 12 is ESM-only and Jest needs `--experimental-vm-modules` to load it.

## Housekeeping and production
`npm run maintenance` (in `apps/api`, after `npm run build`) removes abandoned uploads, leftover photos of
deleted surprises and expired data. Schedule it daily in production; it is safe to run any time.

The API validates its configuration at startup and, with `NODE_ENV=production`, refuses weak secrets, a
blank `CORS_ORIGIN` and the local storage credentials. Container images, release order, scheduling and
monitoring are in [docs/deployment.md](docs/deployment.md). CI (`.github/workflows/ci.yml`) typechecks,
tests and builds both apps, checks that every schema change has a migration, and builds the images.
