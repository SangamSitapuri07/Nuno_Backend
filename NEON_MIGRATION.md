# Render Postgres → Neon Migration

Render ka free Postgres 90 din baad delete ho jaata hai. Neon ka free tier permanent hai
(trial nahi), toh dobara ye dikkat nahi hogi.

## Pehle ye samajh lo — Cloudinary kaam nahi karega

Cloudinary ek **image/video CDN** hai, database nahi. Tumhare paas 11 Postgres tables hain
(User, Match, Friend, Leaderboard, etc.) SQL relations ke saath. Cloudinary usme ek row bhi
store nahi kar sakta.

Cloudinary sirf ek jagah useful hoga — jab users apni **avatar photo upload** karein. Tab
image Cloudinary pe jaayegi aur uska URL Postgres ke `User.avatarUrl` column me save hoga.
Ye baad ka feature hai, abhi zaroorat nahi.

## Kaunsa Postgres lein

| Service | Free storage | Catch |
|---|---|---|
| **Neon** ← recommended | 0.5 GB | Scale-to-zero, ~300-500ms cold start. Pause nahi hota. |
| Supabase | 500 MB | **7 din inactive = project paused**, manually restore karna padta hai |
| Render | 1 GB | **90 din baad DB delete** — yahi toh abhi hua |

Neon lo. Tumhara data (11 tables, chhota game) 0.5 GB me aaram se aa jayega.

---

## Step 1 — Neon pe database banao

1. https://neon.tech pe jao, GitHub se sign up karo (card nahi maangta)
2. New Project → naam `nuno` → region **Singapore** (India ke sabse paas, latency kam)
3. Ban jaane pe **Connection string** copy karo. Aisi dikhegi:

```
postgresql://neondb_owner:XXXXXXXX@ep-something-12345.ap-southeast-1.aws.neon.tech/neondb?sslmode=require
```

`sslmode=require` zaroori hai — hataana mat.

## Step 2 — Purana data bachao (agar abhi bhi zinda hai)

Render dashboard kholo aur dekho DB ka status kya hai.

**Agar DB abhi chal raha hai** — dump le lo:

```powershell
cd backend
pg_dump "PURANA_RENDER_DATABASE_URL" -F c -f nuno_backup.dump
```

`pg_dump` nahi mila to PostgreSQL client tools install karo:
https://www.postgresql.org/download/windows/ (installer me sirf "Command Line Tools" select karo)

**Agar DB pehle hi delete ho gaya** — data gaya, koi upaay nahi. Aage badho, schema naya
ban jayega. Test accounts hi the toh zyada nuksaan nahi.

## Step 3 — Schema Neon pe banao

`backend/.env` me `DATABASE_URL` badlo:

```
DATABASE_URL="postgresql://neondb_owner:XXXX@ep-xxx.ap-southeast-1.aws.neon.tech/neondb?sslmode=require"
```

Fir Prisma migrations chalao:

```powershell
cd backend
npx prisma migrate deploy
npx prisma generate
```

`migrate deploy` tumhari `prisma/migrations/20260630112958_init` migration apply karega.
Saare 11 tables ban jaayenge.

Verify:

```powershell
npx prisma studio
```

Browser khulega, saare tables khaali dikhne chahiye.

## Step 4 — Purana data restore karo (agar Step 2 me dump mila tha)

```powershell
pg_restore --no-owner --no-acl -d "NAYA_NEON_DATABASE_URL" nuno_backup.dump
```

`--no-owner --no-acl` zaroori hai — Render aur Neon ke DB users ke naam alag hain.

Kuch "already exists" errors aayein to ignore karo, wo tables Prisma pehle hi bana chuka hai.

## Step 5 — Render pe env var update karo

Ab Render pe sirf **web service** rahegi, database Neon pe.

1. Render dashboard → apni web service → **Environment**
2. `DATABASE_URL` edit karo → Neon wali connection string daalo
3. **Save Changes** → service khud restart ho jayegi

Purani Render Postgres service ko delete kar sakte ho (ya chhod do, expire ho hi rahi hai).

## Step 6 — Verify

Logs me ye dikhna chahiye:

```
Database connected
Postgres KV store ready
Shared state store: Postgres (no Redis configured)
```

`kv_store` table Neon pe khud ban jaayega — `pgstore.ts` me `CREATE TABLE IF NOT EXISTS`
hai, koi extra migration nahi chahiye.

Health check:

```powershell
curl https://nuno-backend-by35.onrender.com/health
```

Fir app se ek naya account banao — signup chala matlab sab theek.

---

## Neon cold start ka dhyan

Neon free tier 5 min idle pe compute band kar deta hai. Pehli query 300-500ms extra legi.
Render free tier ki 50-second sleep ke saamne ye kuch bhi nahi — app ke 90s timeouts already
isse handle kar lenge.

## Connection pooling

Neon do connection strings deta hai — **pooled** aur **direct**. Prisma ke liye **pooled**
wali use karo (usme `-pooler` hota hai host me). Render pe serverless-style restarts hote
hain, pooled string connection limit exhaust hone se bachati hai.

Agar dashboard me sirf ek string dikhe to "Connection pooling" toggle on karo.

## Backup lena mat bhoolna

Neon free tier me automatic backups nahi hain. Mahine me ek baar chala lena:

```powershell
pg_dump "NEON_DATABASE_URL" -F c -f "nuno_backup_$(Get-Date -Format 'yyyy-MM-dd').dump"
```
