/**
 * Grant coins to specific accounts, by player UID.
 *
 * For testing the shop: the whole catalogue costs 72,600 coins, so the
 * default grant of 100,000 covers every item with room to spare.
 *
 * Deliberately takes UIDs rather than usernames or emails: the uid is the
 * number printed on the profile screen, it is unique, and it does not change
 * when somebody renames themselves.
 *
 * Usage - run this from INSIDE the backend folder, the one that holds
 * package.json. From the repository root it fails with
 * "Cannot find module ./grant-coins.ts", because scripts/ lives under
 * backend/, not at the top.
 *
 *   cd backend
 *   npm run grant -- 1234567890 9876543210
 *   npm run grant -- --amount 50000 1234567890
 *   npm run grant -- --set 0 1234567890
 *
 * Or, without the npm script:
 *
 *   npx ts-node scripts/grant-coins.ts 1234567890 9876543210
 *
 * --amount ADDS to the current balance (the default).
 * --set    REPLACES it, which is the one to use when re-testing from zero.
 */

import path from 'path';
import fs from 'fs';
import dotenv from 'dotenv';

// The script is usually run by hand from a shell that has never seen the
// Render environment, so load backend/.env before anything touches Prisma.
dotenv.config({ path: path.resolve(__dirname, '..', '.env'), quiet: true });

if (!process.env.DATABASE_URL) {
  console.error(
    'DATABASE_URL is not set.\n' +
      'Run this from the backend folder with a .env beside package.json, ' +
      'or set it for this one command:\n' +
      '  $env:DATABASE_URL="postgresql://..."   (PowerShell)\n'
  );
  process.exit(1);
}

// Fail loudly on the mistake that actually happens: running from the repo
// root, where scripts/ does not exist and ts-node reports a confusing
// "Cannot find module" for a file that is plainly there.
if (!fs.existsSync(path.resolve(__dirname, '..', 'package.json'))) {
  console.error(
    'Run this from the backend folder (the one containing package.json).\n' +
      '  cd backend\n' +
      '  npm run grant -- 1234567890\n'
  );
  process.exit(1);
}

// Required lazily: `import` statements are hoisted above the guards above,
// and constructing PrismaClient without DATABASE_URL throws a far less
// helpful error than the one printed there.
// eslint-disable-next-line @typescript-eslint/no-var-requires
const prisma = require('../src/config/database').default as typeof import('../src/config/database').default;
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { isValidUid, normaliseUid } = require('../src/auth/uid') as typeof import('../src/auth/uid');

const DEFAULT_AMOUNT = 100_000;

interface Args {
  uids: string[];
  amount: number;
  replace: boolean;
}

const parseArgs = (argv: string[]): Args => {
  const uids: string[] = [];
  let amount = DEFAULT_AMOUNT;
  let replace = false;

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];

    if (arg === '--amount' || arg === '--set') {
      const value = Number(argv[++i]);
      if (!Number.isFinite(value) || value < 0) {
        throw new Error(`${arg} needs a non-negative number`);
      }
      amount = value;
      replace = arg === '--set';
      continue;
    }

    const uid = normaliseUid(arg);
    if (!isValidUid(uid)) {
      throw new Error(
        `"${arg}" is not a 10-digit player ID. Find it on the profile screen.`
      );
    }
    uids.push(uid);
  }

  if (uids.length === 0) {
    throw new Error(
      'Give at least one player ID.\n' +
        '  npx ts-node scripts/grant-coins.ts 1234567890 9876543210'
    );
  }

  return { uids, amount, replace };
};

const main = async (): Promise<void> => {
  const { uids, amount, replace } = parseArgs(process.argv.slice(2));

  console.log(
    `${replace ? 'Setting' : 'Granting'} ${amount.toLocaleString()} coins ` +
      `${replace ? 'on' : 'to'} ${uids.length} account(s)\n`
  );

  let failures = 0;

  for (const uid of uids) {
    const user = await prisma.user.findUnique({
      where: { uid },
      select: { id: true, username: true, coins: true },
    });

    if (!user) {
      console.log(`  ${uid}  NOT FOUND`);
      failures++;
      continue;
    }

    const updated = await prisma.user.update({
      where: { id: user.id },
      data: replace ? { coins: amount } : { coins: { increment: amount } },
      select: { coins: true },
    });

    console.log(
      `  ${uid}  ${user.username.padEnd(20)} ` +
        `${user.coins.toLocaleString()} -> ${updated.coins.toLocaleString()}`
    );
  }

  // The whole point is to buy things, so say whether that is now possible.
  console.log(
    `\nThe full catalogue costs 72,600 coins ` +
      `(49 paid items, dearest 4,000).`
  );

  await prisma.$disconnect();

  if (failures > 0) {
    console.error(`\n${failures} account(s) not found.`);
    process.exit(1);
  }
};

main().catch(async (error) => {
  console.error(`\n${error.message ?? error}`);
  await prisma.$disconnect();
  process.exit(1);
});
