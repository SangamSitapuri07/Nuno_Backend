# Making multiplayer work on Render

The socket protocol is fine — the problem is **shared state**. Two settings
decide whether players can see each other.

---

## 1. REDIS_URL — required

`src/config/redis.ts` previously *always* used an in-process map, whatever you
configured. Rooms, matchmaking queues, live match state and socket sessions all
live in that store, so:

* every instance had its own private set of rooms
* a restart wiped every room and match
* Render's free tier sleeps after ~15 min idle, so this happened constantly

It now uses real Redis whenever `REDIS_URL` is set, and logs a loud warning
when it is not.

**Set it up:**

1. Render dashboard → **New → Key Value** (Redis). The free plan is enough.
2. Copy its **Internal Redis URL**.
3. On your web service → **Environment** → add:

   ```
   REDIS_URL = redis://red-xxxxx:6379
   ```

4. Deploy.

Confirm in the logs:

```
Redis connected
Socket.IO Redis adapter attached
```

If you instead see `REDIS_URL is not set`, the variable did not apply.

---

## 2. Socket.IO Redis adapter — required if you ever scale past one instance

Socket.IO keeps room membership per process. `io.to(roomId).emit(...)` only
reaches sockets on *that* instance, so two players on different instances never
see each other even with Redis configured for application state.

`src/server.ts` now attaches `@socket.io/redis-adapter` automatically when
`REDIS_URL` is present. Nothing else to do.

---

## 3. Free tier cold starts

The instance sleeps after ~15 minutes idle. On wake:

* the first request takes up to a minute (the app shows "Waking the server…")
* **every socket is dropped**, and the server forgets which rooms each socket
  was in

The client now handles this: it re-authenticates, then re-syncs game state and
rejoins its room by code. Verified against a simulated drop — without the
rejoin the client silently stops receiving room events, which is exactly the
"nothing is real-time" symptom.

To avoid sleeping entirely, either upgrade the instance or ping
`/api/v1/health` every 10 minutes from a free uptime monitor.

---

## 4. Quick verification

```bash
curl https://nuno-backend-by35.onrender.com/api/v1/health
```

Then, with two devices (or two emulators):

1. Both sign in → each should appear in the other's friends list as **Online**
2. One taps **Create Room**, shares the code
3. The other taps **Join Code** → both should see **2 players** immediately
4. Both tap **Ready** → countdown → the match starts on both

If step 1 works but step 3 does not, it is almost always `REDIS_URL`.
