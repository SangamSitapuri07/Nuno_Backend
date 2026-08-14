# Nuno — Flutter mobile client

Phone client for the **Nuno_Backend** multiplayer card game (Express + Socket.IO +
Prisma/Postgres + Redis).

Built with Flutter, Riverpod, GoRouter, Dio and socket_io_client.
**Landscape-only**, implementing a 30-screen UI reference sheet — see
`design/DESIGN_SPEC.md` for the sampled palette and full screen inventory.
(Drop the reference image in `design/UI.png` to keep it alongside the spec.)
Every screen is wired to a real backend endpoint or socket event.

---

## 1. Requirements

- Flutter **3.27+** (Dart 3.6+) — the theme uses `Color.withValues`, `CardThemeData`,
  `DialogThemeData` and `TabBarThemeData`
- The Nuno backend running with Postgres and Redis available
- A **landscape** device or emulator — the app locks to landscape orientation

## 2. Setup

```bash
cd nuno_app

# Generate the native platform folders (android/, ios/, ...) in place
flutter create .

flutter pub get
flutter run
```

### Pointing at your backend

The base URL is a compile-time constant defaulting to the hosted deployment:

```
https://nuno-backend-by35.onrender.com
```

So the app runs with no flags:

```bash
flutter run
```

Override for a local backend:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000     # Android emulator
flutter run --dart-define=API_BASE_URL=http://localhost:3000    # iOS sim / desktop
flutter build apk --dart-define=API_BASE_URL=https://api.yourdomain.com
```

#### Hosted-backend notes

* **Cold starts.** Render's free tier sleeps after ~15 minutes idle and takes up
  to a minute to wake. `AppConfig` widens HTTP and socket timeouts to 90s when
  the host is `onrender.com`, and the splash screen shows a
  "Waking the server..." hint (`core/network/server_wakeup.dart`).
* **Socket transport.** The client starts on HTTP polling and lets Socket.IO
  upgrade to websocket, because hosted proxies often reject a direct websocket
  handshake.
* **CORS.** Native Android/iOS send no `Origin` header, so the backend's
  `ALLOWED_ORIGINS` does not affect them. It only matters for a Flutter Web
  build.
* **Cleartext HTTP** is only needed when targeting a local `http://` backend;
  `setup.sh` configures Android and iOS for it automatically.

---

## 3. Architecture

```
lib/
├── core/
│   ├── config/       AppConfig — base URL, game constants (mirrors GAME_CONSTANTS)
│   ├── network/      ApiClient (Dio + auto token refresh), ApiException
│   ├── storage/      TokenStorage (flutter_secure_storage)
│   ├── router/       GoRouter + auth redirect guard
│   ├── theme/        AppColors / AppDimens / AppTextStyles / AppTheme
│   ├── widgets/      Shared UI kit (buttons, panels, avatar, states, fields)
│   ├── utils/        Formatters
│   └── providers.dart  Root Riverpod graph
├── data/
│   ├── models/       Typed models mirroring the backend payloads 1:1
│   └── repositories/ One repository per REST domain
├── services/
│   ├── socket_service.dart  Single Socket.IO connection + auth handshake
│   └── socket_events.dart   Mirror of SOCKET_EVENTS in utils/constants.ts
└── features/
    ├── auth/         Splash, login, register, AuthController
    ├── home/         Bottom-nav shell, hub, notifications, join-by-code
    ├── matchmaking/  Queue radar, match-found
    ├── lobby/        Room seats, ready-up, countdown, chat, invites
    ├── game/         The table — hand, piles, HUD, emotes, result
    ├── friends/      Friends, requests, player search
    ├── leaderboard/  Global + friends rankings with podium
    ├── store/        Cosmetics shop and inventory
    ├── profile/      Identity, career stats, match history
    └── settings/     Audio, gameplay, language
```

### State management

Riverpod throughout:

- `StateNotifier` for the stateful flows that own socket subscriptions —
  `AuthController`, `LobbyController`, `MatchmakingController`, `GameController`
- `AsyncNotifier` / `FutureProvider` for server data — friends, requests,
  notifications, stats, leaderboard, store, settings

### Auth flow

1. `POST /auth/login` returns `{ accessToken, refreshToken, expiresIn: 900 }`,
   stored in the keychain / encrypted shared preferences.
2. `ApiClient` attaches `Authorization: Bearer <token>` to every request.
3. On a `401` it transparently calls `POST /auth/refresh` **once** and replays the
   request. Concurrent callers share a single in-flight refresh.
4. If refreshing fails the session is cleared and the router redirects to login.
5. After connecting, the socket performs the backend's explicit
   `socket:authenticate` handshake and re-authenticates on every reconnect.

---

## 4. Backend coverage

### REST (`/api/v1`)

| Endpoint | Used by |
|---|---|
| `POST /auth/register`, `/auth/login`, `/auth/logout`, `/auth/refresh` | Auth |
| `GET/PUT /profile` | Profile |
| `GET/PUT /settings` | Settings |
| `GET /statistics` | Home, Profile |
| `GET /history` | Profile |
| `GET /friends`, `POST /friends/request`, `/accept`, `/reject`, `DELETE /friends/:id`, `GET /friends/requests` | Friends |
| `GET /players/search` | Friends → Search |
| `GET /notifications`, `PATCH /notifications/read` | Notifications sheet |
| `GET /leaderboard/global`, `/friends`, `/rank`, `/history` | Leaderboard, Home |
| `GET /store`, `POST /store/purchase`, `GET /inventory`, `GET /balance`, `POST /rewards/daily` | Store, Home |
| `POST /reports`, `POST /block`, `DELETE /block/:id`, `GET /block` | Friends → moderation |
| `GET /queue/status`, `GET /room` | Recovery helpers |

### Socket.IO

Matchmaking (`queue.join/leave`, `match.found`) · Rooms (`room.create/join/leave/
ready/kick`, `room.updated`, `room.countdown`, `room.hostChanged`) · Game
(`game.started`, `game.initialState`, `game.syncState`, `game.syncRequest`,
`card.play`, `card.draw`, `turn.changed`, `direction.changed`, `uno.call/called`,
`game.surrender`, `game.finished`) · Rematch · Chat, quick chat, emotes · DMs and
invites · Friend presence (`friend.statusUpdated`).

---

## 5. Gameplay notes

- **Turn timer** — 20s, matching `GAME_CONSTANTS.TURN_TIMER_SECONDS`. The server
  auto-draws on expiry (or after 3s with no playable card); the client clock is a
  visual mirror and resets on every `turn.changed`.
- **Card legality** — previewed locally (wild, colour match or value match) so
  unplayable cards are dimmed, but the server remains the source of truth.
- **Wild cards** — playing one opens the colour picker and sends `selectedColor`
  with `card.play`.
- **Playing a card** — tap to select (it lifts), tap again to confirm. The card
  is locked while the play is in flight to prevent double-submits.
- **UNO** — the `NUNO!` button only activates at exactly one card, matching the
  server's validation.
- **Reconnect** — the game screen fires `game.syncRequest` on mount; the backend
  restores `matchId`/`roomId` from Redis and replays the state.

---

## 6. Theming

All visual tokens live in `lib/core/theme/`, sampled from the reference sheet:

- `app_colors.dart` — palette, gradients, card/rarity/tier colours, table glow
- `app_dimens.dart` — spacing, radii, playing-card geometry
- `app_text_styles.dart` — type scale

Screens reference tokens only, never raw values, so re-skinning is localised to
these three files.

### Shared building blocks

- `TitledPanel` / `PanelScreen` — the reference's dark panel with a centered
  uppercase header strip; used by nearly every non-game screen
- `SideNav` — the vertical section switcher on Profile and Settings
- `CurrencyPill` / `CoinTag` — coin and gem readouts
- `UnoLogo` — the tilted red oval wordmark
- `PlayingCardView` / `CardBackView` — card faces and backs
