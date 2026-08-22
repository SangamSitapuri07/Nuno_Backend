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

Both are Render dashboard changes. Neither needs a redeploy of the code -
saving an environment variable restarts the service on its own.

---

### 1. Redis — optional, and probably not yet

A free Redis was tried before and filled up during testing, so this section
starts with the measurement rather than the recommendation.

**How much memory this app actually needs.** Every key written during one
live 4-player match, measured by instrumenting the store:

| Bytes | Key |
|---|---|
| 11,153 | `game:<matchId>` — the whole match state |
| 1,119 | `room:<roomId>` |
| 4 x 96 | `match:player:<userId>` |
| 4 x 89 | `player:room:<userId>` |
| 51 | `room:code:<code>` |
| **13,063** | **total per table** |

With Redis' per-key overhead that is about **13.7 KB per live table**:

| Tables | Players | Memory |
|---|---|---|
| 100 | 400 | 1.3 MB |
| 500 | 2,000 | 6.7 MB |
| 1,000 | 4,000 | 13.4 MB |

A 25 MB free tier fits roughly 1,800 simultaneous tables. So **memory is not
the thing that runs out** — if a free instance filled during testing, the
cause was almost certainly one of:

- **Keys with no expiry accumulating.** Exactly one existed: the rematch path
  wrote `match:player:` without a TTL while the other three writers all used
  an hour. Fixed, and `ttl.py` now fails the build if any `set` omits `EX`.
- **A command or connection quota**, not a memory quota. Free Redis plans
  often cap monthly commands. This app issues **2 commands per card played**;
  a completed 4-player game is ~240 including timer reads. At 1,000 games a
  day that is ~7.2M commands a month, which will exhaust a small free
  allowance regardless of how little memory is used.

**Recommendation: stay on Postgres for now.** The timer fix cut steady-state
reads by 90%, which was the actual problem. Postgres has no command quota,
it is already provisioned, and at a few hundred concurrent players it is
comfortable. Add Redis when either of these is true:

- more than one instance is needed (Redis is mandatory then — the Socket.IO
  adapter attaches only when `REDIS_URL` is set, and without it players on
  different instances cannot see each other), or
- the Neon dashboard shows the database straining.

**If and when Redis is added**, use a paid instance rather than a free one,
put it in the **same region** as the web service, and set the maxmemory
policy to **`noeviction`** — the default `allkeys-lru` silently discards keys
under pressure, and these keys are live match state, so a game would vanish
mid-hand. Then set:

| Key | Value |
|---|---|
| `REDIS_URL` | the internal connection URL |

and confirm in the logs:

```
Redis connected
Socket.IO Redis adapter attached
```

If instead the logs say `Shared state store: Postgres (no Redis configured)`
or `Redis connection failed; trying Postgres instead`, Redis is not being
used — the fallback is deliberate, so a bad URL degrades the server quietly
rather than taking it down, which is why the log has to be read.

### 2. Neon connection pooling

The direct endpoint gives each instance a small connection ceiling. Prisma
opens a pool per instance, so the ceiling is reached sooner than expected.
The pooler multiplexes and is what Neon recommends for hosts like Render.

**Step 1 - get the pooled string.**

Neon console -> your project -> **Connection Details** -> enable **Connection
pooling** (or pick the "Pooled connection" tab).

The only difference is `-pooler` inserted into the host:

```
# direct  (current)
postgresql://user:pass@ep-rapid-union-azjk1rqk.c-3.ap-southeast-1.aws.neon.tech/neondb?sslmode=require

# pooled  (want)
postgresql://user:pass@ep-rapid-union-azjk1rqk-pooler.c-3.ap-southeast-1.aws.neon.tech/neondb?sslmode=require
```

You can also just add `-pooler` to the existing host yourself - the rest of
the string, including the password, stays identical.

**Step 2 - update the variable.**

Web service -> **Environment** -> edit `DATABASE_URL` -> paste the pooled
string -> Save.

**Step 3 - confirm.**

```
Database connected successfully
```

and the app behaves normally.

**If a deploy's migration step fails against the pooler**, that is the one
known caveat: `prisma migrate deploy` wants a session it owns and the pooler
multiplexes. The schema already declares `directUrl = env("DIRECT_URL")`, so
the fix is one more variable - keep `DATABASE_URL` pooled for the app and add:

| Key | Value |
|---|---|
| `DIRECT_URL` | the **un**pooled string (host without `-pooler`) |

Leaving `DIRECT_URL` unset is safe: Prisma falls back to `url`, which is the
behaviour before this change.

---

### Order

Do the **pooler** — it is a one-variable change with no cost attached. Leave
Redis alone until a second instance is genuinely needed, or Neon starts to
strain. The measurements above are why: memory was never the constraint, and
a free Redis will hit a command quota long before it hits a memory limit.

## Realistic capacity

- **Today, single instance, Postgres-backed KV, after these fixes:** several
  hundred concurrent players comfortably. The remaining per-action cost is
  one read plus one write per card played.
- **With Redis:** the KV layer stops being the constraint; the socket fan-out
  and CPU become the limit, which is a much higher ceiling.
- **With Redis + sticky sessions + multiple instances:** scales horizontally.

The one thing that does not scale by adding instances is the match timer's
in-process registry, noted above.
