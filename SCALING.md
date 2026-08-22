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

### 1. Redis

Turns every shared-state operation from a network round trip to Neon into a
sub-millisecond call, and **switches on the Socket.IO Redis adapter
automatically** (`src/server.ts` attaches it whenever a Redis client exists).

**Step 1 - create the instance.**

Render dashboard -> **New +** -> **Key Value** (Render's name for its managed
Redis; it was called "Redis" until recently).

- **Name:** `nuno-redis`
- **Region:** the *same region as the web service*. A different region adds
  cross-region latency to every call and undoes the point of the change.
- **Maxmemory policy:** `noeviction`. This matters. The default,
  `allkeys-lru`, lets Redis silently throw away keys when memory fills - and
  the keys here are live match state and room membership, so a game would
  vanish mid-hand.
- **Plan:** the free tier is fine to start.

Create it, then open it and copy the **Internal Key Value URL**. It looks
like:

```
redis://red-xxxxxxxxxxxxxxxxxxxx:6379
```

Use the *internal* URL, not the external one: internal traffic stays inside
Render's network, is faster, and is not billed as bandwidth.

**Step 2 - point the service at it.**

Web service -> **Environment** -> **Add Environment Variable**:

| Key | Value |
|---|---|
| `REDIS_URL` | the internal URL from step 1 |

Save. Render restarts the service.

**Step 3 - confirm it took.**

In the service logs you want these two lines:

```
Redis connected {"url":"redis://red-xxxx:6379"}
Socket.IO Redis adapter attached
```

If instead you see either of these, Redis is **not** in use and the server
has quietly fallen back to Postgres:

```
Shared state store: Postgres (no Redis configured)
Redis connection failed; trying Postgres instead
```

The fallback is deliberate - a bad `REDIS_URL` degrades the server rather
than taking it down - which is exactly why the log line has to be checked
rather than assumed.

---

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

Redis first. It is the change that moves the numbers, and it is independently
verifiable from the logs. Do the pooler after, once Redis is confirmed, so a
problem is attributable to one change rather than two.

## Realistic capacity

- **Today, single instance, Postgres-backed KV, after these fixes:** several
  hundred concurrent players comfortably. The remaining per-action cost is
  one read plus one write per card played.
- **With Redis:** the KV layer stops being the constraint; the socket fan-out
  and CPU become the limit, which is a much higher ceiling.
- **With Redis + sticky sessions + multiple instances:** scales horizontally.

The one thing that does not scale by adding instances is the match timer's
in-process registry, noted above.
