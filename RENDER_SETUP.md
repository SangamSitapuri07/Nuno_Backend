# Making multiplayer work on Render

**You do not need Redis.** The app now uses your existing Postgres for shared
state, so the expired free-tier Redis is not a problem.

---

## What was actually broken

Five separate bugs, all found by probing the socket layer with two simulated
clients:

### 1. There was no shared state at all
`src/config/redis.ts` always used an in-process `Map`, ignoring `REDIS_URL`
entirely. Rooms, matchmaking queues, match state and sessions all live there,
so every instance had a private view and every restart wiped it.

**Fixed:** real Redis when `REDIS_URL` is set, otherwise a Postgres-backed
key/value store (`src/config/pgstore.ts`) that gives the same shared,
restart-surviving behaviour on the database you already pay for.

### 2. Taps during connection were silently dropped
The backend registers its gameplay handlers *inside* the
`socket:authenticate` callback. Anything emitted before that arrives at a
socket with no listener and is discarded — no room, no error. On a cold Render
start that window is up to a minute, which is why **Create Room did nothing**.

**Fixed:** the client queues emits until authentication completes, then
replays them. Verified: a tap 200 ms into a connect that authenticates at
800 ms now succeeds.

### 3. Friends showed OFFLINE while both were online
`broadcastUserStatus` looped `io.sockets.sockets`, which only contains
sockets on the current instance.

**Fixed:** presence is emitted to each friend's `user:<id>` room, which the
Redis adapter routes across instances.

### 4. Friend requests only appeared after a restart
Same local-scan bug in `friends.controller.ts`.

**Fixed:** emits to `user:<id>` instead. Requests now arrive immediately.

### 5. Reconnects lost room membership
After a drop the server no longer has the socket in the room, but the client
carried on. Reproduced: the client stops receiving room events entirely.

**Fixed:** on every re-authentication the lobby rejoins by room code and the
game re-syncs its state.

---

## What you need to do

Nothing, if `DATABASE_URL` is already set — Postgres is used automatically.

Confirm in the Render logs after deploying:

```
Postgres KV store ready
Shared state store: Postgres (no Redis configured)
```

If you later add Redis, set `REDIS_URL` and it will be preferred:

```
Redis connected
Socket.IO Redis adapter attached
```

> **Scaling note:** the Postgres store shares state correctly, but Socket.IO
> still needs the Redis adapter to route events between *multiple* instances.
> On Render's free tier you run a single instance, so this is fine. If you
> scale to 2+, add Redis.

---

## Two-device test

1. Sign in on both → each shows the other as **Online**
2. One taps **Create Room**, shares the code
3. The other taps **Join Code** → both see **2 players** at once
4. Both tap **Ready** → countdown → match starts on both
5. Send a friend request → it appears **without restarting**

---

## Cold starts

The free instance sleeps after ~15 minutes. The first request takes up to a
minute and every socket is dropped. The client handles this now, but you can
avoid it by pinging `/api/v1/health` every 10 minutes from a free uptime
monitor.
