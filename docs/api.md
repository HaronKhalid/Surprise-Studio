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

## Templates (public, cached 5 min)

| method | path | notes |
|---|---|---|
| GET | `/templates?occasion=birthday` | latest active version of each template, in display order |
| GET | `/templates/:slug` | one template; `404 TEMPLATE_NOT_FOUND` |

Each item is `{ id, slug, name, occasion, version, configuration }`. Use `id` as `templateId` when
creating or updating a surprise. See [templates.md](templates.md) for `configuration`.

## Surprises (protected)

| method | path | notes |
|---|---|---|
| POST | `/surprises` | create a draft |
| GET | `/surprises` | your surprises (not deleted) |
| GET | `/surprises/:id` | includes template and assets |
| PATCH | `/surprises/:id` | partial update; `templateId: null` clears the template |
| DELETE | `/surprises/:id` | soft delete; the public link stops working immediately |
| POST | `/surprises/:id/publish` | freezes a snapshot, assigns a slug; calling again republishes the same URL |
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
