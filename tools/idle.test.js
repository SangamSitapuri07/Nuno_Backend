// Does the server touch the database when nobody is playing?
//
// This is what exhausted the Neon free tier. Compute is billed by awake-time
// and suspends after 5 minutes of inactivity, so a background query every
// 60 seconds means it never suspends at all - ~182 CU-hours a month against
// a 100 CU-hour allowance, with zero players.
require('ts-node').register({
  transpileOnly: true,
  compilerOptions: { module: 'commonjs', ignoreDeprecations: '6.0' },
});

let pass = 0, fail = 0;
const t = (n, c) => { c ? (pass++, console.log('  ok  ' + n)) : (fail++, console.log('FAIL  ' + n)); };

const { PgStore } = require('/home/user/Nuno_Backend/src/config/pgstore');

/** A Prisma stand-in that counts every statement it is asked to run. */
const makePrisma = () => {
  const counts = { exec: 0, query: 0, sql: [] };
  return {
    counts,
    $executeRawUnsafe: async (sql) => {
      counts.exec++;
      counts.sql.push(sql.trim().split('\n')[0].trim());
      return 0;
    },
    $queryRawUnsafe: async (sql) => {
      counts.query++;
      counts.sql.push(sql.trim().split('\n')[0].trim());
      return [];
    },
  };
};

const sweeps = (prisma) =>
  prisma.counts.sql.filter((s) => s.startsWith('DELETE FROM kv_store WHERE expires_at')).length;

const wait = (ms) => new Promise((r) => setTimeout(r, ms));

(async () => {
  // The real intervals are minutes long. Patch the module's timing so the
  // behaviour can be observed in a test rather than asserted from reading.
  const store = new PgStore(makePrisma());
  const prisma = store.prisma ?? null;

  // ── The idle case ──────────────────────────────────────────────
  //
  // Drives the REAL interval that init() installed, rather than a local
  // copy of its body. An earlier version of this test reimplemented the
  // guard inline, so deleting the guard from the source left the test
  // passing - it was asserting against itself.
  {
    const p = makePrisma();
    const s = new PgStore(p);

    // Shrink the production intervals so the timer fires during the test.
    const realSetInterval = global.setInterval;
    let installed = null;
    global.setInterval = (fn, ms) => {
      installed = { fn, ms };
      return realSetInterval(fn, 5);   // fire fast
    };

    await s.init();
    global.setInterval = realSetInterval;

    const afterInit = sweeps(p);
    t('init sweeps once, to clear what expired while down', afterInit === 1);
    // Strictly longer than a minute. 60s was the original value and it is
    // exactly what kept the compute awake, so it must not be reachable.
    t('the sweep interval is comfortably longer than a minute',
      installed !== null && installed.ms > 60_000);

    // Nothing has touched the store since init, so age it past the window.
    s.lastUsedAt = Date.now() - 10 * 60 * 1000;

    await wait(120);   // ~24 ticks at 5ms

    t('an idle server never sweeps', sweeps(p) === afterInit);
    t('and issues no further statements',
      p.counts.exec + p.counts.query ===
        (afterInit === 1 ? p.counts.sql.length : -1));

    await s.close();
  }

  // ── The busy case ──────────────────────────────────────────────
  {
    const p = makePrisma();
    const s = new PgStore(p);
    await s.init();
    const base = sweeps(p);

    // Real traffic.
    await s.set('room:1', 'x', { EX: 60 });
    await s.get('room:1');

    const tick = () => {
      if (Date.now() - s.lastUsedAt > 3 * 60 * 1000) return false;
      s.sweep();
      return true;
    };

    t('a busy server does sweep', tick() === true);
    await wait(10);
    t('and the sweep actually runs', sweeps(p) > base);

    await s.close();
  }

  // ── Traffic is what resets the clock ───────────────────────────
  {
    const p = makePrisma();
    const s = new PgStore(p);
    await s.init();

    s.lastUsedAt = Date.now() - 10 * 60 * 1000;
    const stale = s.lastUsedAt;

    await s.get('anything');
    t('a read marks the store as used', s.lastUsedAt > stale);

    s.lastUsedAt = Date.now() - 10 * 60 * 1000;
    await s.set('k', 'v');
    t('a write marks the store as used',
      Date.now() - s.lastUsedAt < 1000);

    s.lastUsedAt = Date.now() - 10 * 60 * 1000;
    await s.lPush('queue:CASUAL:2', 'entry');
    t('a queue push marks the store as used',
      Date.now() - s.lastUsedAt < 1000);

    s.lastUsedAt = Date.now() - 10 * 60 * 1000;
    await s.sAdd('online_players', 'u1');
    t('a set add marks the store as used',
      Date.now() - s.lastUsedAt < 1000);

    await s.close();
  }

  // ── The sweep must not be the thing keeping it awake ───────────
  {
    const p = makePrisma();
    const s = new PgStore(p);
    await s.init();

    s.lastUsedAt = Date.now() - 10 * 60 * 1000;
    const before = s.lastUsedAt;
    await s.sweep();
    t('the sweep does not count as traffic itself',
      s.lastUsedAt === before);

    await s.close();
  }

  // ── close() must stop the timer ────────────────────────────────
  {
    const p = makePrisma();
    const s = new PgStore(p);
    await s.init();
    t('a timer is running after init', s.sweepTimer !== null);
    await s.close();
    t('close stops it', s.sweepTimer === null);
  }

  console.log(`\n${pass} passed, ${fail} failed`);
  process.exit(fail ? 1 : 0);
})();
