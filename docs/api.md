# API

Base URL: `/api/v1`. JSON in, JSON out.

```jsonc
// success
{ "success": true, "data": … }
// error (never includes a stack trace)
{ "success": false, "error": { "code": "TEMPLATE_NOT_FOUND", "message": "Template not found" } }
```

Protected routes need `Authorization: Bearer <accessToken>`. The user is always taken from the token;
a `userId` sent by the client is ignored. Touching someone else's resource returns `403 FORBIDDEN`.
Validation failures are `400` with code `BAD_REQUEST`. Routes are rate limited (register 5/min, login
10/min, upload URLs 30/min, 120/min otherwise).

## Auth

| method | path | notes |
|---|---|---|
| POST | `/auth/register` | `{ email, password (8–128), displayName? }` |
| POST | `/auth/login` | `{ email, password }` |
| POST | `/auth/refresh` | `{ refreshToken }`; rotates the refresh token |
| POST | `/auth/logout` | revokes the refresh token |
| GET | `/auth/me` | current user |
| DELETE | `/auth/me` | `{ password }`. Permanently deletes the account, all its surprises and photos (erased from storage first; if that fails nothing is deleted and you can retry). The access token keeps working for up to 15 minutes but every endpoint then answers 401/404. |

## Health (no auth, never rate limited)

| method | path | notes |
|---|---|---|
| GET | `/health` | liveness: the process is up |
| GET | `/health/ready` | readiness: `503 NOT_READY` if the database does not answer |

Every response carries `X-Request-Id`. Send your own (8-64 chars of `A-Za-z0-9._-`) to trace a request.

## Analytics (no auth)

`POST /analytics/events` with `{ eventType, slug?, metadata?: { source?, template?, step? } }` returns `202`.
`eventType` is one of `app_opened`, `create_started`, `surprise_created`, `template_selected`, `photo_uploaded`,
`preview_opened`, `surprise_published`, `share_clicked`, `public_page_opened`, `public_view_completed`,
`cta_clicked`. Metadata values are short tokens (`[a-z0-9_-]`, up to 30 characters); anything else is `400`.
Nothing about the caller is stored (no IP, user agent or user id). An unknown or unpublished `slug` is accepted
and simply not linked, so the endpoint reveals nothing about which slugs exist. 60 requests/min per IP.

## Templates (public, cached 5 min)

| method | path | notes |
|---|---|---|
| GET | `/templates?occasion=birthday` | latest active version of each template, in display order |
| GET | `/templates/:slug` | one template; `404 TEMPLATE_NOT_FOUND` |

Each item is `{ id, slug, name, occasion, version, configuration }`. Use `id` as `templateId` when
creating or updating a surprise. See [templates.md](templates.md) for `configuration`.

## Public surprise (no auth)

| method | path | notes |
|---|---|---|
| GET | `/public/surprises/:slug` | what the web page renders; 60 requests/min per IP |

Returns `{ slug, occasion, recipient: { name, nickname }, message, content, theme, template: { slug, version, sections }, photos: [{ width, height, urls: { thumb, medium, large } }], publishedAt }`.
The list of fields is an allowlist built from the **published snapshot**, never the live draft: no user
id or email, no database ids, no storage keys, no relationship. `theme` is the fully resolved set of
tokens, so the renderer does not merge anything.

`GET /public/previews/:token` returns the same shape for an **unpublished draft**, so the creator app can show
the real renderer before publishing. The token comes from `POST /surprises/:id/preview` (owner only) and is
scoped to that surprise, valid for 10 minutes, and signed with a key derived from (not equal to) the access-token
secret, so it cannot be used as a login and a login token cannot be used as a preview. The result is built by the
same function that publishing uses, so a preview is exactly what would be published. The web app shows it at
`/preview/<token>` with a "not published yet" badge and records no analytics. Any bad, expired or forged token
is the same `404 SURPRISE_NOT_FOUND`.

Only surprises that are `PUBLISHED` **and** `UNLISTED` are served at `/public/surprises/:slug`. Unpublished, deleted, `PRIVATE`,
malformed and nonexistent slugs all return the same `404 SURPRISE_NOT_FOUND`, so the endpoint cannot be
used to discover which slugs exist. Responses are `Cache-Control: no-store` so unpublishing and deleting
take effect immediately, and carry `X-Robots-Tag: noindex`.

## Surprises (protected)

| method | path | notes |
|---|---|---|
| POST | `/surprises` | create a draft |
| GET | `/surprises` | your surprises (not deleted) |
| GET | `/surprises/:id` | includes template and assets |
| PATCH | `/surprises/:id` | partial update; `templateId: null` clears the template |
| DELETE | `/surprises/:id` | soft delete; the public link stops working immediately |
| POST | `/surprises/:id/publish` | freezes a snapshot, assigns a slug; calling again republishes the same URL |
| POST | `/surprises/:id/preview` | `{ token, expiresIn }` for the draft preview (needs a template; 30/min) |
| POST | `/surprises/:id/unpublish` | back to draft, slug kept |

Body fields: `recipientName` (required on create, ≤ 80), `recipientNickname`, `relationship`,
`occasion`, `message`, `templateId`, `visibility` (`PRIVATE`/`UNLISTED`),
`content` (`intro`, `ending`, `memories[]`), `theme` (`colors.accent`, `font`; see templates.md).

Error codes beyond the standard ones:

| code | when |
|---|---|
| `TEMPLATE_NOT_FOUND` | unknown or inactive `templateId` |
| `TEMPLATE_REQUIRED` | theme sent with no template, or publishing without one |
| `THEME_INVALID` | colour/font not allowed by the template, or unsupported theme key |
| `THEME_LOW_CONTRAST` | the chosen colours make text or accents hard to read |
| `TOO_MANY_MEMORIES` | more memories than the template supports |
| `PHOTOS_REQUIRED`, `MESSAGE_REQUIRED`, `MEMORIES_REQUIRED` | publish: a required section has no content (all problems are listed in `message`; `code` is the first) |

## Assets (protected)

Photos go straight to object storage; they never pass through the API.

1. `POST /assets/upload-url` with `{ surpriseId, mimeType, size }` returns
   `{ assetId, uploadUrl, method: "PUT", headers, expiresIn }`.
2. `PUT` the file bytes to `uploadUrl` with exactly those `headers`. The size is signed into the URL:
   sending a different number of bytes than declared is refused by storage.
3. `POST /assets/complete` with `{ assetId }`. The server inspects the stored file, then creates
   320/960/1920 px WebP variants and returns `{ id, width, height, sortOrder, confirmed, urls }`.

| method | path | notes |
|---|---|---|
| GET | `/assets?surpriseId=` | confirmed photos in order |
| PATCH | `/assets/:id/order` | `{ sortOrder }` |
| DELETE | `/assets/:id` | removes the record and all stored files |

Rules: JPEG, PNG or WebP only (checked against the file's real bytes, not the declared type or
extension); ≤ 10 MB; each side 100–12000 px; ≤ 10 photos per surprise. Originals are not kept, and
re-encoding strips EXIF metadata including GPS location.

| code | when |
|---|---|
| `PHOTO_LIMIT_REACHED` | 10 photos already |
| `UPLOAD_NOT_FOUND` | `complete` called but nothing (or a wrong-size body) was stored |
| `INVALID_FILE_TYPE` | bytes are not JPEG/PNG/WebP |
| `MIME_MISMATCH` | real type differs from the declared `mimeType` |
| `INVALID_IMAGE`, `INVALID_DIMENSIONS`, `FILE_TOO_LARGE`, `SIZE_MISMATCH` | as named |

A failed `complete` deletes the asset record and the raw upload, so nothing unvalidated lingers.
