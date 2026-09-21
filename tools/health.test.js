// Does hitting /health touch Postgres?
//
// This is the question that decides whether an uptime monitor is safe. On
// Neon, compute is billed by awake-time and suspends after 5 minutes idle,
// so a monitor pinging every 5 minutes is fine ONLY if the endpoint it hits
// never reaches the database.
//
// Counting queries is the only honest way to answer it. Reading the handler
// is not enough: middleware runs first, and a rate limiter or a session
// lookup could touch the database without appearing in the route.

const Module = require('module');
const orig = Module._load;

// Every Prisma call is counted, including the raw helpers the KV store uses.
const db = { count: 0, statements: [] };

const rec = (label) => (...args) => {
  db.count++;
  db.statements.push(label + (typeof args[0] === 'string'
    ? ': ' + String(args[0]).trim().split('\n')[0].slice(0, 60)
    : ''));
  return Promise.resolve([]);
};

const model = new Proxy({}, {
  get: (_t, op) => rec(String(op)),
});

Module._load = function (req) {
  if (req === '@prisma/client') {
    return {
      PrismaClient: function () {
        return new Proxy({
          $connect: async () => {},
          $disconnect: async () => {},
          $queryRawUnsafe: rec('$queryRawUnsafe'),
          $executeRawUnsafe: rec('$executeRawUnsafe'),
          $transaction: async (o) =>
            Array.isArray(o) ? Promise.all(o) : o({}),
        }, {
          get: (t, k) => (k in t ? t[k] : model),
        });
      },
    };
  }
  return orig.apply(this, arguments);
};

require('ts-node').register({
  transpileOnly: true,
  compilerOptions: { module: 'commonjs', ignoreDeprecations: '6.0' },
});

const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const http = require('http');

let pass = 0, fail = 0;
const t = (n, c) => { c ? (pass++, console.log('  ok  ' + n)) : (fail++, console.log('FAIL  ' + n)); };

const SRC = '/home/user/Nuno_Backend/src/';
const config = require(SRC + 'config/config').default;
const { apiRateLimit } = require(SRC + 'middleware/rateLimit.middleware');
const {
  sanitizeInput, validateContentType, securityLogger, preventParamPollution,
} = require(SRC + 'middleware/security.middleware');

const get = (base, path) =>
  new Promise((resolve) => {
    http.get(base + path, (res) => {
      let body = '';
      res.on('data', (c) => (body += c));
      res.on('end', () => resolve({ status: res.statusCode, body }));
    });
  });

(async () => {
  // Rebuild the middleware chain exactly as server.ts does, in the same
  // order, so anything that would run before /health runs here too.
  const app = express();
  app.use(helmet());
  app.use(cors({ origin: config.cors.allowedOrigins, credentials: true }));
  app.use(express.json({ limit: '10kb' }));
  app.use(express.urlencoded({ extended: true }));
  app.use(apiRateLimit);
  app.use(sanitizeInput);
  app.use(validateContentType);
  app.use(securityLogger);
  app.use(preventParamPollution);

  app.get('/api/v1/health', (req, res) => {
    res.status(200).json({
      success: true,
      data: {
        status: 'healthy',
        version: config.server.appVersion,
        environment: config.server.nodeEnv,
        timestamp: new Date().toISOString(),
      },
    });
  });

  const srv = http.createServer(app);
  await new Promise((r) => srv.listen(0, r));
  const base = `http://127.0.0.1:${srv.address().port}`;

  // ── A control: a route that DOES use the database ──────────────
  // If the counter never fires, the test proves nothing. This confirms it
  // would have caught a database call.
  //
  // Run BEFORE the flood below: 288 requests trips the rate limiter, and a
  // probe that gets a 429 never reaches the database, so the control would
  // pass vacuously in the wrong direction.
  app.get('/api/v1/_probe', async (req, res) => {
    const prisma = require(SRC + 'config/database').default;
    await prisma.user.findUnique({ where: { id: 'x' } });
    res.json({ ok: true });
  });

  db.count = 0;
  const probe = await get(base, '/api/v1/_probe');
  t('the probe route is reachable', probe.status === 200);
  t('the counter does detect a real database call', db.count > 0);

  // ── One ping ───────────────────────────────────────────────────
  db.count = 0;
  db.statements = [];
  const r = await get(base, '/api/v1/health');

  t('/health answers 200', r.status === 200);
  t('and reports healthy', JSON.parse(r.body).data.status === 'healthy');
  t('one ping runs ZERO database statements', db.count === 0);
  if (db.count) console.log('        touched:', db.statements.join(' | '));

  // ── What an uptime monitor actually does ───────────────────────
  // UptimeRobot's free plan checks every 5 minutes: 288 times a day.
  // The limiter will start answering 429 partway through. That is fine for
  // this question - a 429 is produced without touching the database either,
  // and the point is that no path through the stack reaches Postgres.
  db.count = 0;
  db.statements = [];
  let ok = 0, limited = 0;
  for (let i = 0; i < 288; i++) {
    const res = await get(base, '/api/v1/health');
    res.status === 200 ? ok++ : limited++;
  }

  t('the flood actually ran', ok + limited === 288);
  t('a full day of 5-minute pings runs ZERO statements', db.count === 0);
  if (db.count) console.log('        touched:', db.statements.slice(0, 5).join(' | '));

  srv.close();
  console.log(`\n${pass} passed, ${fail} failed`);
  process.exit(fail ? 1 : 0);
})();
