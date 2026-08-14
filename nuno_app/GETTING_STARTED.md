# Getting started in VS Code

Five minutes from zip to running app.

---

## 1. Install the prerequisites

| Tool | Version | Link |
|---|---|---|
| Flutter SDK | **3.27 or newer** | https://docs.flutter.dev/get-started/install |
| VS Code | any recent | https://code.visualstudio.com |
| VS Code extensions | Flutter + Dart | search `Dart-Code.flutter` in the Extensions panel |

Verify Flutter is on your PATH and healthy:

```bash
flutter --version     # must print 3.27.x or higher
flutter doctor        # fix anything with an [X]
```

> The project uses `Color.withValues`, `CardThemeData` and `DialogThemeData`,
> which are **Flutter 3.27+ only**. On an older SDK you will get analyzer
> errors — run `flutter upgrade` first.

---

## 2. Open the project

Unzip `nuno_app.zip`, then open **the `nuno_app` folder itself** in VS Code
(`File → Open Folder…`). Opening a parent folder will stop the Dart extension
from finding `pubspec.yaml`.

---

## 3. Run setup once

This generates the native `android/` and `ios/` folders (the zip ships only the
Dart source), installs packages, and patches the platform configs so the app can
reach a backend over plain HTTP during development.

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
<summary>Prefer to do it manually?</summary>

```bash
flutter create --project-name nuno_app --org com.nuno .
flutter pub get
```

Then add to the `<application>` tag in
`android/app/src/main/AndroidManifest.xml`:

```xml
android:usesCleartextTraffic="true"
```

and to `ios/Runner/Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <true/>
</dict>
```
</details>

---

## 4. Start the backend

The app is a pure client — it needs `Nuno_Backend` running with **PostgreSQL**
and **Redis** available.

```bash
cd ..                 # into the backend repo root
npm install
npx prisma migrate dev
npm run dev           # listens on :3000
```

Confirm it is alive:

```bash
curl http://localhost:3000/api/v1/health
```

You should get `{"success":true,"data":{"status":"healthy",...}}`.

---

## 5. Point the app at your backend

The base URL is a compile-time constant. Pick the value that matches where you
are running the app:

| Target | `API_BASE_URL` |
|---|---|
| Android emulator | `http://10.0.2.2:3000` ← the emulator's alias for your host |
| iOS simulator / desktop | `http://localhost:3000` |
| Physical phone | `http://<your-computer-LAN-IP>:3000` |

Find your LAN IP with `ipconfig` (Windows) or `ifconfig | grep inet` (macOS/Linux).

---

## 6. Run it

**In VS Code:** press **F5** and pick a configuration from the dropdown —
`Nuno (Android emulator)`, `Nuno (iOS simulator / desktop)` or
`Nuno (physical device — EDIT IP)`. Edit the IP in `.vscode/launch.json` for the
last one.

**From the terminal:**

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

> **The app is landscape-only.** Rotate your emulator (`Ctrl`/`Cmd` + `←`/`→`)
> or it will look wrong.

---

## 7. Create an account

Register in the app. The backend enforces a strong password:
8+ characters with an uppercase letter, a lowercase letter, a number **and** a
symbol — e.g. `Nuno@2026`.

To play a real match you need two players: run a second emulator, or open a
second device and join via room code.

---

## Troubleshooting

**"Connection refused" / "No connection"**
The most common cause is a wrong `API_BASE_URL`. `localhost` inside an Android
emulator means *the emulator itself*, not your computer — use `10.0.2.2`. On a
physical device both machines must be on the same Wi-Fi and you must use the
LAN IP.

**CORS errors**
Add your origin to `config.cors.allowedOrigins` in the backend
(`src/config/config.ts`).

**Cleartext HTTP blocked on Android**
`setup.sh` handles this. If you set up manually, add
`android:usesCleartextTraffic="true"` to the `<application>` tag.

**Analyzer errors about `withValues` or `CardThemeData`**
Your Flutter is older than 3.27. Run `flutter upgrade`.

**Socket never authenticates**
Check the backend log — Redis must be reachable, since the socket handshake
stores its session there.

**Stale build after changing `--dart-define`**
Dart-defines are compiled in. Fully stop and relaunch; hot reload will not pick
up a new URL.

---

## Where things live

```
lib/
├── core/        config, networking, theme tokens, shared widgets, router
├── data/        models + repositories (one per REST domain)
├── services/    Socket.IO connection and event names
└── features/    one folder per screen group
design/          the UI reference sheet + DESIGN_SPEC.md
```

Full architecture notes are in `README.md`.
