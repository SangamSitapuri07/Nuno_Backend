/**
 * Level progression.
 *
 * Levels were previously never awarded: the column existed and every account
 * sat at 1 forever, because nothing recalculated it when xp changed. This is
 * the single definition of the curve, used both when a match ends and when a
 * profile is read, so the two can never disagree.
 */

export const MAX_LEVEL = 50;

/**
 * Total xp required to *reach* each level.
 *
 * Index 0 is unused so the array can be read by level number directly:
 * XP_FOR_LEVEL[5] is the xp needed to be level 5. The curve is quadratic -
 * early levels arrive quickly, later ones take real play - and is generated
 * rather than hand-written so it cannot drift out of order.
 */
export const XP_FOR_LEVEL: number[] = (() => {
  const table = [0, 0];
  for (let level = 2; level <= MAX_LEVEL; level++) {
    // 250 xp for level 2, widening steadily to a few thousand near 50.
    const step = 200 + (level - 1) * 50;
    table[level] = table[level - 1] + step;
  }
  return table;
})();

/** The level a given xp total corresponds to, capped at [MAX_LEVEL]. */
export const levelForXp = (xp: number): number => {
  let level = 1;
  for (let candidate = 2; candidate <= MAX_LEVEL; candidate++) {
    if (xp >= XP_FOR_LEVEL[candidate]) level = candidate;
    else break;
  }
  return level;
};

/** Coins granted for reaching [level]. Bigger milestones pay more. */
export const levelUpReward = (level: number): number => {
  if (level % 25 === 0) return 2000;
  if (level % 10 === 0) return 1000;
  if (level % 5 === 0) return 400;
  return 150;
};

/** Total coins for every level gained between [from] and [to]. */
export const rewardBetween = (from: number, to: number): number => {
  let coins = 0;
  for (let level = from + 1; level <= to; level++) {
    coins += levelUpReward(level);
  }
  return coins;
};
