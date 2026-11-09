# Deployment

The system is three stateless processes plus two managed services. Nothing here assumes a particular
cloud: every piece is a container or a standard protocol (Postgres, S3, HTTP).

```
 phone / browser ──► web  (Next.js, port 3000) ──► api (NestJS, port 4000) ──► Postgres
                                                        │
 browser ───────── image URLs ──► object storage / CDN ◄┘  (api writes, public reads assets/ only)
```

## Images

Build from the repository root (the API image needs `templates/`):

```
docker build -f apps/api/Dockerfile -t surprise-api .
docker build -f apps/web/Dockerfile \
  --build-arg NEXT_PUBLIC_API_URL=https://api.example.com/api/v1 \
  --build-arg NEXT_PUBLIC_SITE_URL=https://example.com -t surprise-web .
```

Both run as a non-root user and have health checks. `NEXT_PUBLIC_*` values are baked into the browser
bundle, so a different public URL needs a rebuild; the server-side `API_URL` is read at runtime.

## Configuration

Set as environment variables (never bake secrets into images). The API refuses to start with a missing or
unsafe configuration and prints every problem at once.

| variable | required | notes |
|---|---|---|
| `NODE_ENV` | yes | `production` turns on the strict checks below |
| `DATABASE_URL` | yes | managed Postgres, TLS on (`?sslmode=require`) |
| `JWT_SECRET`, `JWT_REFRESH_SECRET` | yes | different from each other, ≥ 32 random characters in production (`openssl rand -base64 48`) |
| `STORAGE_ENDPOINT`, `STORAGE_BUCKET`, `STORAGE_ACCESS_KEY`, `STORAGE_SECRET_KEY` | yes | the dev defaults (`minioadmin`) are refused in production |
| `STORAGE_REGION` | | `auto` for Cloudflare R2, the real region for S3 |
| `STORAGE_PUBLIC_URL` | recommended | the CDN origin that serves `assets/` (see Storage) |
| `STORAGE_PUBLIC_ENDPOINT` | | only if clients reach storage on a different host than the API does |
| `CORS_ORIGIN` | yes in production | comma-separated web origins, e.g. `https://example.com`; blank or `*` is refused |
| `TRUST_PROXY` | **set it** | number of proxies in front of the API (usually `1`). Without it every client shares one rate-limit bucket |
| `PORT` | | default 4000 |

Web: `NEXT_PUBLIC_API_URL`, `NEXT_PUBLIC_SITE_URL` (build args) and optionally `API_URL` (runtime).
`CORS_ORIGIN` on the API must include the web origin, because the browser reports analytics events to it.

## Release order

1. **Back up the database** (or confirm the managed service's point-in-time recovery is on).
2. **Migrate**: `npx prisma migrate deploy` using the new API image, as a one-off job *before* starting the new
   version. Migrations are forward-only and CI verifies they match `schema.prisma`. For anything destructive
   (dropping or renaming a column) ship it in two releases so the old version keeps working during the roll.
3. **Seed templates**: `npm run templates:seed`. It is idempotent and refuses to change an existing template
   version (add `v2.json` instead; see [templates.md](templates.md)). Never use `--force` in production.
4. **Roll out the API**, then the web app. Readiness is `GET /api/v1/health/ready` (checks the database);
   liveness is `GET /api/v1/health` (checks nothing else on purpose, so a database blip does not restart healthy
   servers). The process drains in-flight requests on `SIGTERM`.
5. **First deploy only**: create the bucket with `npm run storage:init`.

## Scheduled maintenance

Run **`npm run maintenance`** (`node dist/maintenance/run.js`) at least daily, from any scheduler (cron, a
platform scheduler, a Kubernetes CronJob). It prints one JSON line and exits non-zero on failure, so alert on the
exit code. It is idempotent and safe to run concurrently, so redundancy is fine. It:

- removes uploads that were requested but never confirmed (after 1 hour),
- removes leftover photos of deleted surprises (the normal path erases them immediately; this catches storage
  outages),
- purges surprises deleted more than 30 days ago, expired and old revoked refresh tokens, and analytics events
  older than 400 days.

The policy lives in one file, `apps/api/src/maintenance/retention.ts`.

## Storage and the CDN

Only the processed `assets/` prefix is public; `uploads/` (raw files, deleted seconds after upload) is not. Put a
CDN in front of the bucket and set `STORAGE_PUBLIC_URL` to it. Image files are immutable (random keys, never
overwritten) and sent with `Cache-Control: public, max-age=31536000, immutable`, so cache them for as long as the
CDN allows. Moving providers is a configuration change: the code only speaks S3.

## What to watch

- **Logs**: the API writes one JSON line per request (`requestId`, `route`, `status`, `ms`, `userId`). The route is
  the pattern, never the URL, so unlisted-surprise slugs do not reach your log store. Send `X-Request-Id` from the
  gateway to follow one request across services.
- **Alerts worth having**: readiness failing, 5xx rate, `maintenance` exiting non-zero, storage 5xx, database
  connections near the limit, disk or storage growth.
- **Capacity**: image processing (`sharp`) runs in the API process and is the CPU-heavy part. If upload volume
  grows, move `complete` onto a queue with its own workers before scaling the whole API.

## Not yet in place

A Content-Security-Policy for the web app, abuse reporting and moderation, error tracking (Sentry or similar),
and automated deploys (CI builds the images but does not push them). See [security.md](security.md).
