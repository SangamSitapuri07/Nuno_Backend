# Google Sign-In setup

The code is complete on both sides. What remains is registering the app with
Google and handing two values to the two builds. There is no `google-services.json`
step: the app passes `serverClientId` directly, which is the supported path and
avoids adding the Google Services Gradle plugin.

## 1. Create the OAuth clients

You need **two** OAuth clients. Only one of them is the "server client id"
the app and the backend both use.

| Client | Why it exists | Used in code? |
|---|---|---|
| **Android** | Lets Google recognise your app by package name + signing key. Without it sign-in is refused. | No - never referenced |
| **Web** | Its id becomes the token's `aud`, which is what the backend verifies. | **Yes - this is the server client id** |

Using the Android id as the server client id is the single most common
mistake and fails silently with a null token.

### 1a. Get your SHA-1 first

You need this for the Android client. From the Flutter project:

```
cd "C:\Users\sanga\Desktop\NUNO flutter\nuno-frontend\nuno_app\android"
.\gradlew signingReport
```

Look for the block that says `Variant: debug` and copy the `SHA1:` line -
it is 20 hex pairs separated by colons.

If `gradlew` errors, use keytool on the debug keystore directly:

```
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

### 1b. Create the clients

Go to <https://console.cloud.google.com/apis/credentials>.

1. Create a project (top-left project picker -> New project), or reuse one.

2. **OAuth consent screen** (left sidebar) - this must be done before any
   client can be created:
   - User type: **External** -> Create
   - App name, user support email, developer contact email -> Save
   - While the app is in "Testing" only listed test users can sign in, so
     either add your own Google account under **Test users**, or press
     **Publish app**.

3. **Credentials** -> **+ Create credentials** -> **OAuth client ID**, and do
   this twice:

   **Android client**
   - Application type: **Android**
   - Package name: `com.nuno.nuno_app`
   - SHA-1: the value from step 1a
   - Create. You never copy this id anywhere.

   **Web client**
   - Application type: **Web application**
   - Name: anything, e.g. "Nuno server"
   - Leave *Authorized JavaScript origins* and *redirect URIs* empty
   - Create.
   - **Copy the Client ID shown.** It looks like
     `847263910284-a1b2c3d4e5f6g7h8.apps.googleusercontent.com`.

That copied value is your **server client id**. It goes in two places -
sections 2 and 3 below - and it must be the *same* string in both.

### Finding it again later

Credentials page -> under **OAuth 2.0 Client IDs**, click the row whose Type
column says **Web application** -> the Client ID is on the right, with a copy
button.

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

## A release build needs its own SHA-1

The debug and release builds are signed with different keys, so the release
APK's SHA-1 must be added to the **same Android OAuth client** (edit it and
press "Add fingerprint") before sign-in works outside debug. Nothing else
changes - the server client id stays the same.

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
