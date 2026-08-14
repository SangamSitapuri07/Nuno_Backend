# Getting started in VS Code

The app is preconfigured to use your hosted backend at
`https://nuno-backend-by35.onrender.com`, so there is **nothing to run locally
except the app itself**.

---

## 1. Install the prerequisites

| Tool | Version | Link |
|---|---|---|
| Flutter SDK | **3.27 or newer** | https://docs.flutter.dev/get-started/install |
| VS Code | any recent | https://code.visualstudio.com |
| VS Code extensions | Flutter + Dart | search `Dart-Code.flutter` in Extensions |

```bash
flutter --version     # must print 3.27.x or higher
flutter doctor        # fix anything with an [X]
```

> The project uses `Color.withValues`, `CardThemeData` and `DialogThemeData`,
> which are **Flutter 3.27+ only**. On an older SDK run `flutter upgrade`.

---

## 2. Open the project

Unzip, then open **the `nuno_app` folder itself** in VS Code
(`File → Open Folder…`). Opening a parent folder stops the Dart extension from
finding `pubspec.yaml`.

---

## 3. Run setup once

The zip ships only Dart source, so this generates the native `android/` and
`ios/` folders and installs packages.

**macOS / Linux**
```bash
cd nuno_app
./setup.sh
```

**Windows**
```bat
cd nuno_app
setup.bat
```

<details>
<summary>Manual equivalent</summary>

```bash
flutter create --project-name nuno_app --org com.nuno .
flutter pub get
```
</details>

---

## 4. Run it

**VS Code:** press **F5** → choose **`Nuno (hosted backend — default)`**.

**Terminal:**
```bash
flutter run
```

That's it — no `--dart-define` needed. The hosted URL is the default.

> **Landscape only.** Rotate your emulator (`Ctrl`/`Cmd` + `←`/`→`).

### First launch is slow — that's expected

Render's free tier spins the server down after ~15 minutes idle. The first
request wakes it, which takes **up to a minute**. The splash screen shows
*"Waking the server…"* so you know it isn't frozen. Subsequent launches are fast.

---

## 5. Create an account

Register in the app. The backend requires 8+ characters with an uppercase
letter, a lowercase letter, a number **and** a symbol — e.g. `Nuno@2026`.

A real match needs two players: run two emulators, or use a second device and
join by room code.

---

## Switching to a local backend

Only if you want to develop against `npm run dev`:

| Target | Command |
|---|---|
| Android emulator | `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000` |
| iOS sim / desktop | `flutter run --dart-define=API_BASE_URL=http://localhost:3000` |
| Physical device | `flutter run --dart-define=API_BASE_URL=http://<LAN-IP>:3000` |

The matching launch configs are already in `.vscode/launch.json`, and `setup.sh`
has already enabled cleartext HTTP for local dev.

---

## Server-side checklist

Two things your Render deployment needs. Both cause failures that look like app
bugs, so worth confirming:

**1. Redis must be reachable.**
The socket handshake stores sessions in Redis (`src/websocket/socket.auth.ts`),
and matchmaking, rooms and live game state all live there. Without it, login
may succeed over REST but the socket never authenticates — so matchmaking and
gameplay silently do nothing. Set `REDIS_URL` on your Render service.

**2. Postgres must be migrated.**
Run `npx prisma migrate deploy` against your production `DATABASE_URL`.

**3. `ALLOWED_ORIGINS` — only matters for Flutter Web.**
It defaults to `http://localhost:3000` (`src/config/config.ts`). Native Android
and iOS builds do **not** send an `Origin` header, so CORS does not apply and
the app works as-is. If you later build for web, add that origin to the
`ALLOWED_ORIGINS` env var (comma-separated).

Verify the deployment is alive:
```bash
curl https://nuno-backend-by35.onrender.com/api/v1/health
```
Expect `{"success":true,"data":{"status":"healthy",...}}`. The first call may
take a minute if the instance is asleep.

---

## Troubleshooting

**Splash sits on "Waking the server…"**
Normal on the first launch — allow 60s. If it becomes *"Cannot reach the
server"*, check the health URL above in a browser.

**Login works, but matchmaking/rooms do nothing**
Almost always Redis. Check the Render logs for Redis connection errors.

**"Cannot reach the server"**
Confirm the Render service is deployed and not suspended, and that the health
endpoint responds in a browser.

**Analyzer errors about `withValues` / `CardThemeData`**
Flutter older than 3.27 — run `flutter upgrade`.

**Changed `--dart-define` but nothing happened**
Dart-defines are compiled in. Fully stop and relaunch; hot reload won't pick up
a new URL.

---

## Where things live

```
lib/
├── core/        config, networking, theme tokens, shared widgets, router
├── data/        models + repositories (one per REST domain)
├── services/    Socket.IO connection and event names
└── features/    one folder per screen group
design/          DESIGN_SPEC.md — sampled palette and screen inventory
```

Architecture notes are in `README.md`.
