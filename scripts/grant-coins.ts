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
 * Usage (from the backend directory, with DATABASE_URL set):
 *
 *   npx ts-node scripts/grant-coins.ts 1234567890 9876543210
 *   npx ts-node scripts/grant-coins.ts --amount 50000 1234567890
 *   npx ts-node scripts/grant-coins.ts --set 0 1234567890
 *
 * --amount ADDS to the current balance (the default).
 * --set    REPLACES it, which is the one to use when re-testing from zero.
 */

import prisma from '../src/config/database';
import { isValidUid, normaliseUid } from '../src/auth/uid';

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
