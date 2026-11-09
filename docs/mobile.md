# Creator app (Flutter, Android)

`apps/mobile`. Creators sign in, make a surprise in five short steps, preview it, publish and share the link.
Recipients never use this app: they open the link in a browser (see [templates.md](templates.md)).

## Run it

You need the Flutter SDK and the Android SDK (Android Studio installs both). Start the backend first
(`npm run infra:up`, then the API and web app, see the README).

```
cd apps/mobile
flutter pub get
adb reverse tcp:4000 tcp:4000    # API
adb reverse tcp:3000 tcp:3000    # web app (draft preview)
adb reverse tcp:9000 tcp:9000    # storage (photo URLs)
flutter run
```

`adb reverse` makes the phone's `localhost` reach your computer, so the same URLs work on an emulator and a
real device, including the photo URLs the API returns. Point a build elsewhere with `--dart-define`:

```
flutter run --dart-define=API_URL=https://api.example.com/api/v1 --dart-define=SITE_URL=https://example.com
```

Debug builds may use plain `http` for local development. **Release builds cannot**: Android blocks cleartext
traffic, so a release build only works against `https` URLs.

## Tests

```
flutter analyze
flutter test                                   # 90+ tests, offline, a few seconds
SURPRISE_API_URL=http://localhost:4000/api/v1 flutter test test/contract   # against a running API
```

- **Unit tests** cover the API client (envelope handling, token refresh, single-flight refresh), models,
  validators, the draft controller (uploads, reordering, rollback) and the router redirects.
- **Widget tests** drive the whole app, router included, against in-memory fakes: onboarding, sign-in, the
  full create-to-share flow, editing, deleting, settings and account deletion.
- **Contract tests** run the real data layer against the real API: registration, create/update, presigned
  photo upload, ordering, preview, publish/unpublish, token rotation, account deletion. They create and then
  delete a throwaway account, and registration is rate limited to 5/min, so do not loop them.

The contract tests are the guard against the app and server drifting apart; run them after changing either side.

## How it is built

Feature folders under `lib/features`, shared code in `lib/core`, wiring in `lib/app`.

- **State**: Riverpod. Screens read providers; providers depend on interfaces (`SurpriseRepository`,
  `AuthRepository`, `TemplateRepository`, `Sharer`, `PhotoPicker`, `Analytics`), so tests swap in fakes with no
  mocking library and no plugins.
- **Networking**: one Dio client (`core/network/api_client.dart`). It unwraps the `{success, data | error}`
  envelope, attaches the token and refreshes it on a 401. Concurrent 401s share **one** refresh, because the
  server rotates refresh tokens and treats reuse of a spent one as theft. Photo bytes go to storage through a
  separate client that never sends our `Authorization` header.
- **Session**: tokens live in the Android Keystore (`flutter_secure_storage`). Auto-backup is off so encrypted
  tokens are never restored onto a device without the key. An offline start shows a retry; only a rejected
  session signs the user out.
- **Preview**: the app opens the real web renderer in a WebView, fed from the unpublished draft by a short-lived
  token (see [api.md](api.md)). There is no second implementation of the layout to drift. The WebView may only
  navigate within the site's own origin, because the preview URL carries a credential.
- **Drafts**: the surprise is created on the server as soon as the first step is saved and every step saves as
  you go, so a draft survives the app being closed and "edit" is the same wizard.
- **Photos**: the system photo picker (no gallery permission), one upload at a time with per-photo state, the
  10-photo limit counted including photos in flight, and the real file type taken from the bytes.
- **Colours**: the accent picker only offers colours that stay readable on the chosen style, using the same
  contrast rule as the server, so a pick is never rejected.
- **Analytics**: only an event name and up to two short tokens, never content or identifiers.

## Before the first Play Store release

Things that need a decision or an asset from you, in rough order:

1. **Application id.** It is `com.digitaltakhleeq.surprise_studio` (`android/app/build.gradle.kts`). It is
   permanent once published; change it now if you want a different one.
2. **Release signing.** Create a keystore and `android/key.properties` (both git-ignored):
   ```
   storeFile=/absolute/path/upload-keystore.jks
   storePassword=...
   keyAlias=upload
   keyPassword=...
   ```
   Without it the release build is signed with the debug key and Google Play will reject it (Gradle prints a
   warning). Enrol in Play App Signing and keep the keystore backed up somewhere safe: losing the upload key is
   recoverable, but only through Google support.
3. **Launcher icon and splash.** The generated Flutter icon is still in place.
4. **Production URLs.** Build with `--dart-define=API_URL=...` and `SITE_URL=...` (https only).
5. **Privacy policy and terms.** Required by Google Play because the app handles accounts and personal photos,
   and needed for the Data safety form. They need legal review and are not written yet. The in-app account
   deletion (Settings) is already there, which Play also requires.
6. **Versioning.** Bump the build number in `pubspec.yaml` (`version: 0.1.0+1`) for every upload.
7. **Deep links.** Opening `https://<domain>/s/<slug>` in the app (Android App Links) is not implemented; links
   open in the browser, which is the intended recipient experience.

## What has and has not been verified

Verified: `flutter analyze` is clean; all unit and widget tests pass; the contract tests pass against a running
API (the full registration to publish to deletion path).

**Not yet verified on a device or emulator**: the Android Gradle build, the WebView preview, the system photo
picker, sharing and secure storage, because the Android SDK is not installed on the machine this was written
on. CI runs `flutter build apk --release` on a runner that has it, which will catch manifest and Gradle problems,
but the first run on a real phone should be treated as the real test of those plugin-backed pieces.
