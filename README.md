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

## Tests
```
cd apps/api && npm test
```
Use `npm test`, not `npx jest`: Nest 12 is ESM-only and Jest needs `--experimental-vm-modules` to load it.

## Production notes
Point `STORAGE_*` at Cloudflare R2 or S3 instead of RustFS and run `npm run storage:init` once. Run
`npm run templates:seed` on deploy; it never changes a released template version (see
[docs/templates.md](docs/templates.md)).
