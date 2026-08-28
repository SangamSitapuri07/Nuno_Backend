/**
 * House rules.
 *
 * Everything here is OFF by default, and the default is the official Mattel
 * ruleset. Mattel has stated plainly that stacking is not part of UNO ("there
 * is no stacking in UNO"), and jump-in, seven-zero and draw-to-match are
 * likewise variants rather than rules. So the game a player gets without
 * touching anything is the one printed on the box.
 *
 * These are only selectable in a private room, where everybody at the table
 * can see the choice before the game starts. Quick Match always uses the
 * official rules: strangers matched by rating have not agreed to anything,
 * and a queue that silently varied its rules would be unplayable.
 */

export interface HouseRules {
  /**
   * A Draw Two may be answered with another Draw Two, passing the growing
   * penalty along. The most popular house rule by a distance.
   *
   * Same-type only: a Draw Two cannot be answered with a Wild Draw Four.
   * Nearly every group that plays stacking plays it this way, and mixing the
   * two is rejected even in most casual play.
   */
  stackDrawTwo: boolean;

  /** The same, for Wild Draw Four onto Wild Draw Four. */
  stackDrawFour: boolean;

  /**
   * Play an identical card (same colour AND same value) out of turn. Play
   * then continues from whoever jumped in.
   *
   * Numbers only. Allowing it on action cards makes the turn order
   * essentially unresolvable.
   */
  jumpIn: boolean;

  /**
   * Playing a 7 lets you swap hands with a player of your choice; playing a
   * 0 rotates every hand in the current direction of play.
   */
  sevenZero: boolean;

  /**
   * Keep drawing until a playable card turns up, instead of drawing one and
   * passing.
   */
  drawToMatch: boolean;

  /**
   * A player who does not call UNO on their second-to-last card is caught
   * automatically and draws two, rather than needing another player to
   * notice.
   */
  forceUnoPenalty: boolean;
}

/** The official Mattel game. Every variant off. */
export const OFFICIAL_RULES: HouseRules = {
  stackDrawTwo: false,
  stackDrawFour: false,
  jumpIn: false,
  sevenZero: false,
  drawToMatch: false,
  forceUnoPenalty: false,
};

/** Cap on a stacked penalty, so a chain cannot empty the draw pile. */
export const MAX_STACK_DRAW = 24;

export type HouseRuleKey = keyof HouseRules;

export const HOUSE_RULE_KEYS: HouseRuleKey[] = [
  'stackDrawTwo',
  'stackDrawFour',
  'jumpIn',
  'sevenZero',
  'drawToMatch',
  'forceUnoPenalty',
];

/**
 * Coerces whatever a client sent into a complete, valid rule set.
 *
 * Unknown keys are dropped and missing ones default to off, so an older or
 * newer client cannot enable something by accident, and a malformed payload
 * degrades to the official game rather than being rejected.
 */
export const normaliseHouseRules = (input: unknown): HouseRules => {
  const out: HouseRules = { ...OFFICIAL_RULES };
  if (!input || typeof input !== 'object') return out;

  for (const key of HOUSE_RULE_KEYS) {
    if ((input as any)[key] === true) out[key] = true;
  }

  return out;
};

/** True when every rule is off, i.e. this is the official game. */
export const isOfficial = (rules: HouseRules | undefined): boolean =>
  !rules || HOUSE_RULE_KEYS.every((k) => rules[k] === false);

/** Short human-readable summary, for logs and the lobby header. */
export const describeHouseRules = (rules: HouseRules | undefined): string => {
  if (isOfficial(rules)) return 'Official rules';
  const on = HOUSE_RULE_KEYS.filter((k) => rules![k]);
  return `${on.length} house rule${on.length === 1 ? '' : 's'}: ${on.join(', ')}`;
};
