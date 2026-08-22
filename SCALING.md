# Scaling notes

Measured, not estimated. The numbers below come from counting every KV
operation and every Prisma query on the real code paths.

## What was costing the most

| Source | Before | After |
|---|---|---|
| Match timer, per match | 1 state read **every second** | ~2 reads per 20s turn |
| Table sync, 4 players | 4 `findMany` for usernames | 0 after the first |
| Finding a player's socket | walk of every connected socket | one map lookup |

The timer dominated because it scales with the number of open tables rather
than with anything players are doing: 500 idle matches cost 500 reads/sec
before, and 50 now.

### Steady-state KV reads per second

| Matches | Players | Before | After |
|---|---|---|---|
| 50 | 200 | 50 | 5 |
| 100 | 400 | 100 | 10 |
| 250 | 1,000 | 250 | 25 |
| 500 | 2,000 | 500 | 50 |
| 1,000 | 4,000 | 1,000 | 100 |

Turn timing is unchanged: auto-draw still fires at ~3s when a hand has
nothing playable and the turn still expires at ~20s, verified to within a
second.

## Still to configure (no code change needed)

### 1. Redis

Without `REDIS_URL` the shared store falls back to Postgres, so every KV
operation is a network round trip to Neon. Redis turns those into sub-
millisecond calls and, just as importantly, **switches on the Socket.IO Redis
adapter automatically** (`src/server.ts` attaches it when a Redis client
exists).

Set on Render:

```
REDIS_URL = redis://<user>:<password>@<host>:<port>
```

Until this is set the server logs:

```
Socket.IO is running without the Redis adapter. This is fine on a single
instance, but rooms will not be shared if you scale out.
```

### 2. More than one instance

Two instances **cannot** be run until `REDIS_URL` is set - players on
different instances would not see each other. Even then, one detail is still
single-instance: `activeMatchTimers` is an in-process `Set`, so each instance
runs timers only for matches it started. That is correct as long as the
socket that starts a match stays on that instance, which it does with sticky
sessions. Enable sticky sessions before scaling out.

### 3. Neon connection pooling

Use the `-pooler` endpoint in `DATABASE_URL`. The direct endpoint gives each
instance its own small connection ceiling; the pooler multiplexes and is what
Neon recommends for serverless-style hosts.

```
DATABASE_URL = postgresql://...@ep-xxx-pooler.<region>.aws.neon.tech/neondb?sslmode=require
```

## Realistic capacity

- **Today, single instance, Postgres-backed KV, after these fixes:** several
  hundred concurrent players comfortably. The remaining per-action cost is
  one read plus one write per card played.
- **With Redis:** the KV layer stops being the constraint; the socket fan-out
  and CPU become the limit, which is a much higher ceiling.
- **With Redis + sticky sessions + multiple instances:** scales horizontally.

The one thing that does not scale by adding instances is the match timer's
in-process registry, noted above.
