# Nuno UI — reference spec

Derived from the "UNO GAME — COMPLETE UI FLOW (LANDSCAPE)" reference sheet (30 screens).

## Global

| Property | Value |
|---|---|
| **Orientation** | **LANDSCAPE** (all 30 screens) |
| Players | 2–7 |
| Background | Very dark navy/indigo, subtle vignette |
| Panels | Slightly lighter navy, 1px violet-ish border, ~12–16px radius |
| Panel headers | Centered uppercase caption on a lighter strip |

## Palette (sampled from the reference)

| Token | Hex | Used for |
|---|---|---|
| `background` | `#0A0B1E` | App background |
| `backgroundAlt` | `#0E1030` | Header strips |
| `surface` | `#161A3A` | Panels/cards |
| `surfaceHigh` | `#1E2350` | Raised rows, inputs |
| `surfaceStroke` | `#2A2F5E` | Panel borders |
| `primaryRed` | `#E01B24` | PLAY button, UNO logo, destructive |
| `redDark` | `#8B0F16` | PLAY gradient end |
| `gold` | `#FFC107` | Primary CTAs (CREATE ROOM, START GAME, CLAIM, PLAY AGAIN) |
| `blue` | `#2196F3` | Secondary CTAs (LOBBY), Quick Match tile |
| `green` | `#4CAF50` | JOIN, your-turn glow, online dot |
| `violet` | `#6C4BF6` | Play-menu tiles, accents |
| `cyan` | `#22D3EE` | Gem currency |
| Card R/B/G/Y | `#E53935` / `#1E88E5` / `#43A047` / `#FDD835` | Playing cards |

### Category accents (legend on the sheet)
Lobby/Nav `#3B82F6` · Gameplay `#22C55E` · Social `#E040FB` · Profile `#FF9800` ·
Store `#FFC107` · System `#9E9E9E`

## Screen inventory

| # | Screen | Backend support |
|---|---|---|
| 1 | Splash (UNO logo) | — |
| 2 | Home (avatar, coins, gems, PLAY, bottom nav) | `/profile` |
| 3 | Play Menu (Quick Match / Create Room / Join Room / Match History) | sockets |
| 4 | Create Room (name, max players 2–7, rules) | `room.create` |
| 5 | Room Lobby (code + copy, player list, invite, start) | `room.*` |
| 6 | Join Room (6-char code + numeric keypad) | `room.join` |
| 7 | Gameplay — opponent turn (RED glow) | `game.syncState` |
| 8 | Gameplay — your turn (GREEN glow) | `game.syncState` |
| 9 | Card Action popup (wild colour choice) | `card.play` |
| 10 | UNO Declared (starburst) | `uno.call` |
| 11 | Draw Penalty (+4) | `player.drewCard` |
| 12 | Game Over (crown, standings, Play Again / Lobby) | `game.finished` |
| 13 | Chat Panel (Room/Team tabs) | `chat.*` — Team tab unsupported |
| 14 | Quick Chat / Emotes | `chat.quick`, `emote.send` |
| 15 | Voice Panel (speaking levels, mute all) | `voice.*` (WebRTC signalling only) |
| 16 | Invite Friends | `invite.send` |
| 17 | Friends List (All/Friends/Recent) | `/friends` |
| 18 | Recent Players | ❌ no endpoint |
| 19 | Profile (sidebar nav) | `/profile` |
| 20 | Stats | `/statistics` — no "Best Score" field |
| 21 | Achievements | ❌ no endpoint |
| 22 | Leaderboard (Global/Country/Friends) | `/leaderboard/*` — no Country |
| 23 | Store (Featured/Cards/Tables/Emotes) | `/store` |
| 24 | Daily Rewards (7-day track) | `/rewards/daily` — no streak state |
| 25 | Settings (sidebar nav) | `/settings` |
| 26 | Notifications | `/notifications` |
| 27 | Season Pass | ❌ no endpoint |
| 28 | Event Screen | ❌ no endpoint |
| 29 | Tutorial (1/5) | client-only |
| 30 | Exit Confirm | client-only |

## Gaps vs. backend

These appear in the reference but have **no backend support**:

- **Gems** — `User` has `coins` only. Shown read-only as 0.
- **Achievements / Titles** — no model or route.
- **Season Pass / Events** — no model or route.
- **Recent Players** — no route.
- **Country leaderboard** — only global + friends.
- **Team chat** — chat is room-wide.
- **Best Score** stat — not in `PlayerStatistics`.
- **Max 7 players** — backend `GAME_CONSTANTS.MAX_PLAYERS` is 10; UI caps at 7 per the design.
