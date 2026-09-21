// Fake prisma + an in-memory KV, so the voice handler can run for real.
const Module = require('module');
const orig = Module._load;

const kv = new Map();
global.__kv = kv;

Module._load = function (req) {
  if (req === '@prisma/client') {
    return {
      PrismaClient: function () {
        return {
          $connect: async () => {},
          $disconnect: async () => {},
          user: {
            findUnique: async ({ where }) => ({
              id: where.id,
              username: 'u_' + where.id,
              accountStatus: 'ACTIVE',
            }),
            findMany: async ({ where }) =>
              (where?.id?.in ?? []).map((id) => ({
                id, username: 'u_' + id, level: 1,
              })),
          },
          leaderboard: { findUnique: async () => ({ rating: 1000 }) },
        };
      },
    };
  }
  return orig.apply(this, arguments);
};
