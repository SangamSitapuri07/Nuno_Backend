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

### 1. Redis — measured first, because a free tier died last time

A free Redis was tried before and was exhausted during testing. Rather than
recommend one again, here is what this app actually consumes.

**Memory.** Every key written by one live 4-player match:

| Bytes | Key |
|---|---|
| 11,153 | `game:<matchId>` — the whole match state |
| 1,119 | `room:<roomId>` |
| ~740 | nine smaller keys |
| **13,063** | **per table** |

With per-key overhead that is ~13.7 KB per live table:

| Tables | Players | Memory |
|---|---|---|
| 500 | 2,000 | 6.7 MB |
| 1,000 | 4,000 | 13.4 MB |

Against a 256 MB free tier that is nothing. **Memory was never the problem.**

**Commands.** This is what runs out. Measured per operation:

| Operation | Commands |
|---|---|
| Create a room | 4 |
| Three players join | 15 |
| Deal the match | 9 |
| **One card play** | **2** |
| Timer, per turn | ~2 |

A complete 4-player game — 60 plays — is **~268 commands**.

Against Upstash's free 500K commands/month:

| Games/day | Commands/month | % of free tier |
|---|---|---|
| 10 | 80,400 | 16% — fits |
| 25 | 201,000 | 40% — fits |
| 50 | 402,000 | 80% — tight |
| 100 | 804,000 | **161% — exceeds** |

So a free tier is fine for testing and a small launch, and dies at roughly
**50 games a day**. That is almost certainly what happened before: not
memory, but the command allowance.

#### Which provider

Checked against the providers' own docs, because the answer is not the
obvious one.

| | Free tier | Runs out at | Catch |
|---|---|---|---|
| **Upstash** | 500K cmds/mo, 256 MB | ~50 games/day | Command quota — this is what killed the last one |
| **Render Key Value** | one instance, no command cap | memory | **Data lost on every restart**, and Render restarts it whenever it likes |
| **Aiven (Valkey)** | 1 GB, no command cap | memory | Needs a separate account; not in Render's private network |
| **Redis Cloud** | 30 MB, **100 ops/sec** | throughput | 100 ops/sec is roughly 25 games/day here |

**Render's free Key Value is in-memory only.** Its docs are explicit: it does
not persist to disk, Render may restart it at any time, and a restart deletes
everything. For this app that means every open room and every live match
disappears mid-hand — worse than the Postgres store we have now, which
survives restarts.

So the honest ranking for *this* workload:

1. **Stay on Postgres.** It is already shared, already survives restarts, has
   no command quota, and the timer fix removed 90% of the reads.
2. **Render Key Value at $10/mo (Starter)** when Redis is actually needed —
   paid instances get disk-backed persistence, and there is no command cap.
3. **Aiven free (1 GB)** if the cost matters more than the extra latency of
   leaving Render's network.
4. **Upstash free** only for a low-traffic launch, knowing it dies around
   50 games a day.

Redis Cloud's 30 MB free tier is fine on memory but capped at 100 ops/sec,
which this app would hit at about 25 games a day — not worth it.

#### Is it needed yet?

No, not for correctness on one instance. Postgres already works and the timer
fix removed 90% of the load. Redis becomes **mandatory** the moment a second
instance is added: the Socket.IO adapter only attaches when `REDIS_URL` is
set, and without it players on different instances cannot see each other.

### 2. Neon connection pooling

The direct endpoint gives each instance a small connection ceiling, and
Prisma opens a pool per instance, so it is reached sooner than expected. The
pooler multiplexes and is what Neon recommends for hosts like Render.

**Set BOTH variables at once.** Your Render start command is

```
npx prisma migrate deploy && npm start
```

so a migration runs on every deploy. `migrate deploy` needs a session it
owns and can fail against the pooler, which would break the deploy rather
than just the migration. Setting `DIRECT_URL` in the same pass avoids that
entirely — the app uses the pooler, migrations use the direct host. The
schema already declares `directUrl = env("DIRECT_URL")`.

**`DIRECT_URL` is required, not optional.** Prisma resolves `env()` during
schema validation, so a missing variable is a hard error — P1012,
"Environment variable not found" — and not a silent fall back to `url`.
Setting only `DATABASE_URL` would fail the deploy at the migrate step. Both
go in together.

**Step 1 — copy your current value.**

Render → web service → **Environment** → copy the existing `DATABASE_URL`
somewhere. That is the direct string; you need it for `DIRECT_URL`.

It looks like:

```
postgresql://neondb_owner:PASSWORD@ep-rapid-union-azjk1rqk.c-3.ap-southeast-1.aws.neon.tech/neondb?sslmode=require
```

**Step 2 — make the pooled version.**

Insert `-pooler` immediately after the endpoint id, before the first dot.
Nothing else changes — same user, same password, same database.

```
                    ...azjk1rqk-pooler.c-3.ap-southeast-1...
                              ^^^^^^^
```

(You can also get it from the Neon console → your project → **Connection
Details** → tick **Connection pooling**. Same string either way.)

**Step 3 — set the two variables.**

| Key | Value |
|---|---|
| `DATABASE_URL` | the **pooled** string (host has `-pooler`) |
| `DIRECT_URL` | the **direct** string (host has no `-pooler`) |

Save. Render restarts the service.

**Step 4 — confirm.**

The deploy log should show the migration step succeed and then:

```
Database connected successfully
```

If the migration step fails, `DIRECT_URL` is wrong or missing — check that
its host does **not** contain `-pooler`.

**Rollback,** if anything looks off: set **both** variables to the original
direct string. Do not delete `DIRECT_URL` - the schema references it, so
removing it fails validation. Same value in both is exactly the behaviour
before the pooler.

### Order

The pooler is done. **Redis is not the next thing to do** — Postgres already
gives shared, restart-surviving state with no command quota, and the timer
fix removed 90% of the load.

Redis becomes mandatory only when a second instance is added, because the
Socket.IO adapter attaches only when `REDIS_URL` is set. At that point pay
the $10/mo for a Render Key Value Starter instance rather than using a free
one: every free option here fails on something this app cares about —
Upstash on commands, Render's free tier on losing all data at restart, Redis
Cloud on a 100 ops/sec cap.

## Realistic capacity

- **Today, single instance, Postgres-backed KV, after these fixes:** several
  hundred concurrent players comfortably. The remaining per-action cost is
  one read plus one write per card played.
- **With Redis:** the KV layer stops being the constraint; the socket fan-out
  and CPU become the limit, which is a much higher ceiling.
- **With Redis + sticky sessions + multiple instances:** scales horizontally.

The one thing that does not scale by adding instances is the match timer's
in-process registry, noted above.
