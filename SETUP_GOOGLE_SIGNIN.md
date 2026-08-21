# Google Sign-In setup

The code is complete on both sides. What remains is registering the app with
Google and handing two values to the two builds. There is no `google-services.json`
step: the app passes `serverClientId` directly, which is the supported path and
avoids adding the Google Services Gradle plugin.

## 1. Create the OAuth clients

In the [Google Cloud console](https://console.cloud.google.com/apis/credentials):

1. Create a project (or reuse one).
2. Configure the OAuth consent screen -> External -> fill in app name and
   support email. While it is in "Testing", only accounts you list as test
   users can sign in, so either add yourself or hit "Publish app".
3. Create credentials -> OAuth client ID, **twice**:

   **a) Android client**
   - Application type: Android
   - Package name: `com.nuno.nuno_app`
   - SHA-1: get it with
     ```
     cd "C:\Users\sanga\Desktop\NUNO flutter\nuno-frontend\nuno_app\android"
     .\gradlew signingReport
     ```
     Use the SHA1 under `Variant: debug` for testing. A release build is
     signed with a different key, so its SHA-1 must be added too before
     release sign-in works.

   **b) Web client**
   - Application type: Web application
   - No redirect URIs needed.
   - **This client's ID is the one both the app and the server use.** Android
     tokens are addressed to the web client, which is what makes them
     verifiable by the backend.

## 2. Give the server the web client ID

On Render -> your service -> Environment, add:

```
GOOGLE_CLIENT_IDS = <web client id>.apps.googleusercontent.com
```

Several ids may be listed comma-separated (e.g. when an iOS client is added
later). Without this the `/auth/google` route returns 503 rather than
trusting anything.

## 3. Give the app the same web client ID

It is compiled in, so it is passed at build time:

```
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>.apps.googleusercontent.com
```

```
flutter build apk --release --dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>.apps.googleusercontent.com
```

To avoid retyping it, create `nuno_app/dart_defines.json`:

```json
{ "GOOGLE_SERVER_CLIENT_ID": "<web client id>.apps.googleusercontent.com" }
```

and run `flutter run --dart-define-from-file=dart_defines.json`.

## 4. Apply the migration

The backend deploy runs `npx prisma migrate deploy`, which applies
`20260821090000_google_auth_and_uid`. It adds `uid`, `googleId` and
`usernameSet`, makes `passwordHash` nullable, and backfills a distinct
10-digit uid for every account that already exists.

## Troubleshooting

**Sign-in dialog opens, then fails immediately** - the SHA-1 of the build you
are running is not registered on the Android OAuth client. Debug and release
have different keys.

**"Google sign-in is not configured correctly for this build"** - the app was
built without `GOOGLE_SERVER_CLIENT_ID`, so no ID token came back.

**Server replies 503 GOOGLE_NOT_CONFIGURED** - `GOOGLE_CLIENT_IDS` is not set
on Render.

**Server replies 401 INVALID_GOOGLE_TOKEN** - the id in `GOOGLE_CLIENT_IDS`
does not match the one the app was built with. They must be the same web
client id.
