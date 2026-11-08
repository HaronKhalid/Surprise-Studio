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

## Known gaps (not enforced yet)

- **Deleting or unpublishing a surprise does not delete its photos from storage.** The public *page*
  stops working immediately, but the image files remain at their (unguessable) URLs. Anyone who already
  saved a photo URL can still fetch it. Needs the storage-lifecycle cleanup job from the architecture doc
  (soft delete, retention period, then permanent deletion), plus deletion on account removal. Until then
  this should not be described to users as "deleted".
- Public photo URLs are unguessable but not secret once shared. If stricter privacy is wanted later,
  serve images through signed, expiring URLs or an authenticated proxy.
- Abandoned (never confirmed) upload rows are ignored by the photo limit once their URL expires but are
  not yet purged.
- No CSP header yet on the web app, and no abuse reporting or moderation.
- No privacy policy or terms of service pages (required before launch, and they need legal review).
