# Sirf Backend Changes Kaise Laayein (Flutter app ke bina)

Tumhara backend alag folder/repo me hai. `git pull` karoge to `nuno_app/` (Flutter frontend)
bhi aa jayega. Usse bachne ke 3 tareeke hain — **Tarika 1 sabse safe aur recommended hai.**

Backend me total sirf **10 files** badli hain:

```
.gitignore
RENDER_SETUP.md
package-lock.json
src/config/pgstore.ts        <-- NAYI file (Postgres KV store)
src/config/redis.ts
src/friends/friends.controller.ts
src/friends/friends.service.ts
src/rooms/room.handler.ts
src/server.ts
src/websocket/socket.handler.ts
```

`package.json` me koi change nahi hai — `redis` aur `@socket.io/redis-adapter` pehle se hi
dependencies me the. Matlab `npm install` chalane ki bhi zaroorat nahi (chala lo to bhi theek).

---

## Tarika 1 — `fetch` + selective `checkout` (RECOMMENDED)

`git fetch` sirf data download karta hai, tumhari files ko **haath nahi lagata**.
Fir hum sirf backend ke paths checkout karenge. `nuno_app/` kabhi disk pe aayega hi nahi.

Apne backend folder me ye chalao:

```bash
# 1. Agar remote add nahi hai to add karo (ek hi baar)
git remote -v
# agar 'origin' pehle se SangamSitapuri07/Nuno_Backend hai to skip karo
git remote add nuno https://github.com/SangamSitapuri07/Nuno_Backend.git

# 2. Sirf download karo, merge nahi
git fetch nuno arena/019fff1a-nuno-backend

# 3. Sirf backend files apne folder me le aao
git checkout nuno/arena/019fff1a-nuno-backend -- src/ RENDER_SETUP.md package-lock.json

# 4. Dekho kya kya aaya
git status
```

> Agar remote pehle se `origin` hai to `nuno` ki jagah `origin` likho:
> `git fetch origin arena/019fff1a-nuno-backend`
> `git checkout origin/arena/019fff1a-nuno-backend -- src/ RENDER_SETUP.md package-lock.json`

Ab check karo:

```bash
ls src/config/pgstore.ts    # honi chahiye
ls nuno_app                 # "No such file" aana chahiye  <-- ye confirm karta hai frontend nahi aaya
npx tsc --noEmit            # clean pass hona chahiye
```

Fir commit + apne backend repo pe push:

```bash
git add -A
git commit -m "fix(realtime): Postgres shared store, queued emits, cross-instance events"
git push
```

Render auto-deploy kar dega.

### PowerShell wali line (Windows)
Upar wale commands PowerShell me bhi waise hi chalte hain, koi change nahi.

---

## Tarika 2 — Patch file (agar git remote ka jhamela nahi karna)

Maine ek ready patch bana ke repo me daal diya hai: `backend_only.patch`
(sirf backend diff, `nuno_app/` ka ek byte bhi nahi).

Download karo:

```bash
curl -L -o backend_only.patch https://raw.githubusercontent.com/SangamSitapuri07/Nuno_Backend/arena/019fff1a-nuno-backend/backend_only.patch
```

PowerShell:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SangamSitapuri07/Nuno_Backend/arena/019fff1a-nuno-backend/backend_only.patch" -OutFile backend_only.patch
```

Fir apply:

```bash
git apply --check backend_only.patch   # pehle test — koi output = sab theek
git apply backend_only.patch
```

Agar `--check` error de (matlab tumhare backend me kuch aur badla hua hai), to:

```bash
git apply --3way backend_only.patch
```

Ye conflict markers daal dega jinhe manually solve karna hoga.

---

## Tarika 3 — Merge karo par frontend hata do

Sabse gandha tareeka, sirf tab jab upar wale kaam na karein:

```bash
git pull nuno arena/019fff1a-nuno-backend
git rm -r --cached nuno_app
rm -rf nuno_app
echo "nuno_app/" >> .gitignore
git add -A
git commit -m "backend only"
```

---

## Aage se ye problem na ho iske liye

Backend folder me `.git/info/exclude` (ya `.gitignore`) me daal do:

```
nuno_app/
```

Isse `nuno_app/` kabhi tumhare backend repo ka hissa nahi banega, chahe galti se pull ho jaye.

---

## Deploy ke baad kya verify karna hai

Render logs me ye lines dikhni chahiye:

```
Postgres KV store ready
Shared state store: Postgres (no Redis configured)
```

Agar `In-memory store` dikhe to `DATABASE_URL` env var missing hai — Render dashboard me check karo.

Fir do phone se test:
1. Dono login → dono ek dusre ko **ONLINE** dikhne chahiye (pehle offline dikh raha tha)
2. Phone A: Create Room → room code aana chahiye (pehle kuch nahi hota tha)
3. Phone B: Join Code → dono ko 2 players dikhne chahiye
4. Dono Ready → countdown → match start
5. Friend request bhejo → **turant** dikhna chahiye, restart ke bina
