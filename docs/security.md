# Security notes

What is enforced today, and what is not yet. The full pre-production checklist is in
[scratchpad.md](../scratchpad.md) section 49.

## Enforced

**Authorization.** The user always comes from the access token; a client-sent `userId` is ignored.
Every surprise and asset route checks ownership (`403 FORBIDDEN`). Refresh tokens are stored hashed and
rotated; presenting an already-used refresh token revokes all of that user's tokens.

**Uploads.** Photos go straight to storage through short-lived presigned URLs whose size is signed in,
so storage itself refuses a body of a different length. After upload the server re-checks everything
against the real bytes: file signature (JPEG/PNG/WebP, never the declared type or extension), size
≤ 10 MB, dimensions 100–12000 px, ≤ 10 photos per surprise (enforced again at confirm time). The raw
file is then re-encoded to WebP variants, which strips EXIF including GPS location, and deleted.
Anything that fails validation is deleted along with its database row.

**Theme and content are untrusted input that is rendered on a public page.** Colours must be `#rrggbb`
and fonts a key from a fixed list, so a theme value can never carry CSS (`url(...)`, `;}`) or markup.
Overrides are validated against what the template allows and a contrast floor. Unknown keys are rejected,
and content has length and count limits. The public endpoint re-applies these rules on the way out, so a
malformed or tampered snapshot degrades to the template defaults instead of reaching the page.

**Public endpoint.** Output is an allowlist built from the published snapshot (see
[api.md](api.md#public-surprise-no-auth)). Every unavailable case returns an identical 404, malformed
slugs are rejected before touching the database, and the route is rate limited. Slugs are 10 random
characters from a 64-symbol alphabet (about 60 bits).

**Public image URLs** are random (`assets/<24 random chars>/…`), not derived from database ids, so a
photo URL reveals nothing about the surprise, the owner or other photos. Only the processed `assets/`
prefix is publicly readable; `uploads/` (raw files) is not.

**Other.** Passwords hashed with argon2, global and per-route rate limits (register 5/min, login 10/min),
a consistent error envelope that never includes stack traces, `.env` never committed.

**Deletion.** Deleting a surprise erases its photos from storage immediately and soft-deletes the row
(purged after 30 days). Deleting an account (`DELETE /auth/me`, password required) erases every photo first
and aborts if storage fails, so a retry never leaves files behind. A scheduled `npm run maintenance` mops up
anything that slipped through (storage outages, abandoned uploads) and applies the retention policy in
`apps/api/src/maintenance/retention.ts`. Storage reports per-key delete failures and these are treated as errors,
never silently ignored. *Unpublishing* keeps the photos (so republishing works) and they stay reachable at their
unguessable URLs; deleting is what removes them.

**Production configuration is checked at startup.** The API refuses to boot in production with weak or equal
JWT secrets, a blank or `*` CORS origin, or the local development storage credentials.

**Logging and analytics.** Request logs are structured JSON that record the route pattern, never the URL, query,
headers or body, so slugs, tokens and passwords cannot reach the log store. Analytics events carry an event name,
the surprise and up to three short tokens; no IP, user agent or user id is stored. The web app reports views from
the browser (link-preview bots do not run JavaScript), honours Do Not Track and counts once per session.

**Login timing.** Unknown emails take as long to reject as wrong passwords, and concurrent sign-ups for one email
resolve to a clean `EMAIL_TAKEN`. (Registration still reveals whether an email is taken, which is the usual
trade-off for a usable sign-up form; the rate limit applies.)

## Known gaps (not enforced yet)

- Public photo URLs are unguessable but not secret once shared. If stricter privacy is wanted later, serve
  images through signed, expiring URLs or an authenticated proxy.
- Files that exist in storage with no database row (for example after a crash between upload and record) are
  not detected; that needs a periodic bucket listing job.
- No Content-Security-Policy on the web app yet, and no abuse reporting or moderation.
- No email verification or password reset (needs an email provider), and no account lockout beyond rate limits.
- No privacy policy or terms of service pages (required before launch, and they need legal review).
- No error tracking (Sentry or similar) and no automated dependency-vulnerability gate beyond Dependabot.
