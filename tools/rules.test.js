// House rules against the real engine, with an in-memory state store.
//
// The default must be the official Mattel game: no stacking, no jump-in, no
// seven-zero. Each variant is then turned on individually and checked to do
// what it says - and, just as importantly, to change nothing when it is off.
require('./st.js');
require('ts-node').register({
  transpileOnly: true,
  compilerOptions: { module: 'commonjs', ignoreDeprecations: '6.0' },
});

let pass = 0, fail = 0;
const t = (n, c) => { c ? (pass++, console.log('  ok  ' + n)) : (fail++, console.log('FAIL  ' + n)); };

const SRC = '/home/user/Nuno_Backend/src/';
const engine = require(SRC + 'gameplay/game.engine').default;
const gsm = require(SRC + 'gameplay/game.state').default;
const rules = require(SRC + 'gameplay/house.rules');
const { CardColor, CardValue, CardType, GameDirection, MatchStatus } =
  require(SRC + 'gameplay/game.types');

// ── In-memory state store ────────────────────────────────────────
const store = new Map();
gsm.getState = async (id) => store.get(id) ?? null;
gsm.saveState = async (s) => { store.set(s.matchId, s); };
engine.finalizeMatch = async () => {};

let seq = 0;
const card = (color, value, type) => ({
  cardId: 'c' + ++seq,
  type: type ?? (typeof value === 'string' && /^[0-9]$/.test(value)
    ? CardType.NUMBER : CardType.ACTION),
  color,
  value,
});

const wild = (value) => card(CardColor.WILD, value, CardType.WILD);

/** Builds a match with fully controlled hands and a known top card. */
const table = (opts = {}) => {
  const players = opts.players ?? ['p1', 'p2', 'p3'];
  const top = opts.top ?? card(CardColor.RED, CardValue.FIVE);
  const state = {
    matchId: 'm' + ++seq,
    roomId: 'r1',
    players,
    currentTurn: opts.turn ?? players[0],
    direction: opts.direction ?? GameDirection.CLOCKWISE,
    currentColor: top.color,
    currentValue: top.value,
    drawPile: opts.drawPile ?? Array.from({ length: 60 },
      () => card(CardColor.BLUE, CardValue.NINE)),
    discardPile: [top],
    hands: opts.hands ?? Object.fromEntries(players.map((p) => [p, []])),
    status: MatchStatus.RUNNING,
    timerStarted: Date.now(),
    winner: null,
    totalTurns: 0,
    cardsPlayedBy: {},
    cardsDrawnBy: {},
    startedAt: Date.now(),
    unoCalledBy: opts.unoCalledBy ?? [],
    houseRules: opts.rules ?? rules.OFFICIAL_RULES,
    pendingDraw: 0,
  };
  store.set(state.matchId, state);
  return state;
};

const sizes = (s) => s.players.map((p) => s.hands[p].length);

(async () => {
  // ── The default is the official game ───────────────────────────
  {
    const r = rules.OFFICIAL_RULES;
    t('every house rule is off by default',
      rules.HOUSE_RULE_KEYS.every((k) => r[k] === false));
    t('the default set is recognised as official', rules.isOfficial(r));
    t('and describes itself as such',
      rules.describeHouseRules(r) === 'Official rules');
  }

  {
    const s = await engine.initializeMatch('mi1', 'r1', ['a', 'b'], 'CASUAL');
    t('a match with no rules argument is official',
      rules.isOfficial(s.houseRules));
  }

  // ── normaliseHouseRules is strict ──────────────────────────────
  {
    const n = rules.normaliseHouseRules({ stackDrawTwo: true, nonsense: true });
    t('a known flag is honoured', n.stackDrawTwo === true);
    t('an unknown flag is dropped', n.nonsense === undefined);
    t('unmentioned flags stay off', n.jumpIn === false);

    t('garbage degrades to the official game',
      rules.isOfficial(rules.normaliseHouseRules('nope')));
    t('null degrades to the official game',
      rules.isOfficial(rules.normaliseHouseRules(null)));
    t('a truthy non-true value does not enable a rule',
      rules.normaliseHouseRules({ jumpIn: 'yes' }).jumpIn === false);
  }

  // ── Draw Two, official: the next player draws and is skipped ───
  {
    const d2 = card(CardColor.RED, CardValue.DRAW_TWO);
    const spare = () => card(CardColor.GREEN, CardValue.EIGHT);
    const s = table({ hands: { p1: [d2, spare()], p2: [], p3: [] } });
    await engine.playCard(s.matchId, 'p1', { cardId: d2.cardId });
    const after = store.get(s.matchId);
    t('official: the next player draws two', after.hands.p2.length === 2);
    t('official: and is skipped', after.currentTurn === 'p3');
    t('official: nothing is left pending', !after.pendingDraw);
  }

  // ── Draw Two, stacking on ──────────────────────────────────────
  {
    const a = card(CardColor.RED, CardValue.DRAW_TWO);
    const b = card(CardColor.BLUE, CardValue.DRAW_TWO);
    const s = table({
      rules: { ...rules.OFFICIAL_RULES, stackDrawTwo: true },
      hands: {
        p1: [a, card(CardColor.GREEN, CardValue.EIGHT)],
        p2: [b, card(CardColor.GREEN, CardValue.EIGHT)],
        p3: [],
      },
    });

    await engine.playCard(s.matchId, 'p1', { cardId: a.cardId });
    let after = store.get(s.matchId);
    t('stacking: nobody draws yet', after.hands.p2.length === 2);
    t('stacking: two are pending', after.pendingDraw === 2);
    t('stacking: the turn passes to the victim', after.currentTurn === 'p2');

    await engine.playCard(s.matchId, 'p2', { cardId: b.cardId });
    after = store.get(s.matchId);
    t('stacking: the chain grows to four', after.pendingDraw === 4);
    t('stacking: and moves on again', after.currentTurn === 'p3');

    await engine.drawCard(after.matchId, 'p3');
    after = store.get(s.matchId);
    t('stacking: the player who cannot answer takes all four',
      after.hands.p3.length === 4);
    t('stacking: the stack is cleared', after.pendingDraw === 0);
  }

  // ── A pending stack narrows what is playable ───────────────────
  {
    const a = card(CardColor.RED, CardValue.DRAW_TWO);
    const red5 = card(CardColor.RED, CardValue.FIVE);
    const d4 = wild(CardValue.WILD_DRAW_FOUR);
    const s = table({
      rules: { ...rules.OFFICIAL_RULES, stackDrawTwo: true },
      hands: {
        p1: [a, card(CardColor.GREEN, CardValue.EIGHT)],
        p2: [red5, d4],
        p3: [],
      },
    });
    await engine.playCard(s.matchId, 'p1', { cardId: a.cardId });

    let threw = null;
    try {
      await engine.playCard(s.matchId, 'p2', { cardId: red5.cardId });
    } catch (e) { threw = e; }
    t('a matching colour cannot answer a stack', threw?.code === 'INVALID_CARD');

    threw = null;
    try {
      await engine.playCard(s.matchId, 'p2', { cardId: d4.cardId });
    } catch (e) { threw = e; }
    t('a Draw Four cannot answer a Draw Two stack',
      threw?.code === 'INVALID_CARD');
  }

  // ── Draw Four stacking is its own switch ───────────────────────
  {
    const a = wild(CardValue.WILD_DRAW_FOUR);
    const s = table({
      rules: { ...rules.OFFICIAL_RULES, stackDrawTwo: true },
      hands: { p1: [a, card(CardColor.GREEN, CardValue.EIGHT)], p2: [], p3: [] },
    });
    await engine.playCard(s.matchId, 'p1', {
      cardId: a.cardId, selectedColor: CardColor.GREEN,
    });
    const after = store.get(s.matchId);
    t('stackDrawTwo alone does not stack a Draw Four',
      after.hands.p2.length === 4 && !after.pendingDraw);
  }

  {
    const a = wild(CardValue.WILD_DRAW_FOUR);
    const b = wild(CardValue.WILD_DRAW_FOUR);
    const s = table({
      rules: { ...rules.OFFICIAL_RULES, stackDrawFour: true },
      hands: {
        p1: [a, card(CardColor.GREEN, CardValue.EIGHT)],
        p2: [b, card(CardColor.GREEN, CardValue.EIGHT)],
        p3: [],
      },
    });
    await engine.playCard(s.matchId, 'p1', {
      cardId: a.cardId, selectedColor: CardColor.GREEN,
    });
    await engine.playCard(s.matchId, 'p2', {
      cardId: b.cardId, selectedColor: CardColor.RED,
    });
    const after = store.get(s.matchId);
    t('Draw Fours chain to eight', after.pendingDraw === 8);
  }

  // ── The chain is capped ────────────────────────────────────────
  {
    const hand = Array.from({ length: 20 },
      () => card(CardColor.RED, CardValue.DRAW_TWO));
    const s = table({
      players: ['p1', 'p2'],
      rules: { ...rules.OFFICIAL_RULES, stackDrawTwo: true },
      hands: { p1: hand.slice(0, 10), p2: hand.slice(10) },
    });
    for (let i = 0; i < 10; i++) {
      const who = i % 2 === 0 ? 'p1' : 'p2';
      const c = store.get(s.matchId).hands[who][0];
      await engine.playCard(s.matchId, who, { cardId: c.cardId });
    }
    t('a stack cannot grow past the cap',
      store.get(s.matchId).pendingDraw <= rules.MAX_STACK_DRAW);
  }

  // ── Seven-Zero ─────────────────────────────────────────────────
  {
    const seven = card(CardColor.RED, CardValue.SEVEN);
    const s = table({
      hands: {
        p1: [seven, card(CardColor.BLUE, CardValue.ONE)],
        p2: Array.from({ length: 5 }, () => card(CardColor.BLUE, CardValue.TWO)),
        p3: [],
      },
    });
    await engine.playCard(s.matchId, 'p1', {
      cardId: seven.cardId, swapWith: 'p2',
    });
    const after = store.get(s.matchId);
    t('off: a seven does not swap hands',
      after.hands.p1.length === 1 && after.hands.p2.length === 5);
  }

  {
    const seven = card(CardColor.RED, CardValue.SEVEN);
    const s = table({
      rules: { ...rules.OFFICIAL_RULES, sevenZero: true },
      hands: {
        p1: [seven, card(CardColor.BLUE, CardValue.ONE)],
        p2: Array.from({ length: 5 }, () => card(CardColor.BLUE, CardValue.TWO)),
        p3: [],
      },
    });
    await engine.playCard(s.matchId, 'p1', {
      cardId: seven.cardId, swapWith: 'p2',
    });
    const after = store.get(s.matchId);
    t('on: a seven swaps hands with the chosen player',
      after.hands.p1.length === 5 && after.hands.p2.length === 1);
  }

  {
    const seven = card(CardColor.RED, CardValue.SEVEN);
    const s = table({
      rules: { ...rules.OFFICIAL_RULES, sevenZero: true },
      hands: { p1: [seven, card(CardColor.BLUE, CardValue.ONE)], p2: [], p3: [] },
    });
    await engine.playCard(s.matchId, 'p1', { cardId: seven.cardId });
    t('a seven with no target is a no-op, not an error',
      store.get(s.matchId).hands.p1.length === 1);
  }

  {
    const seven = card(CardColor.RED, CardValue.SEVEN);
    const s = table({
      rules: { ...rules.OFFICIAL_RULES, sevenZero: true },
      hands: {
        p1: [seven, card(CardColor.GREEN, CardValue.EIGHT)], p2: [], p3: [],
      },
    });
    await engine.playCard(s.matchId, 'p1', {
      cardId: seven.cardId, swapWith: 'nobody',
    });
    t('a seven aimed at a stranger is ignored',
      store.get(s.matchId).players.length === 3);
  }

  // Zero rotates every hand one seat along.
  {
    const zero = card(CardColor.RED, CardValue.ZERO);
    const s = table({
      rules: { ...rules.OFFICIAL_RULES, sevenZero: true },
      hands: {
        p1: [zero, card(CardColor.GREEN, CardValue.EIGHT)],
        p2: Array.from({ length: 2 }, () => card(CardColor.BLUE, CardValue.TWO)),
        p3: Array.from({ length: 3 }, () => card(CardColor.BLUE, CardValue.THREE)),
      },
    });
    await engine.playCard(s.matchId, 'p1', { cardId: zero.cardId });
    const after = store.get(s.matchId);
    // p1 played its only card, so it passes an empty hand on.
    // p1 played one of two cards, so it passes on a hand of one.
    t('a zero rotates the hands clockwise',
      JSON.stringify(sizes(after)) === JSON.stringify([3, 1, 2]));
    t('and no card is created or lost',
      sizes(after).reduce((a, b) => a + b, 0) === 6);
  }

  // ── Draw to match ──────────────────────────────────────────────
  {
    const s = table({
      hands: { p1: [], p2: [], p3: [] },
      // Nothing in the pile matches a red 5.
      drawPile: Array.from({ length: 20 },
        () => card(CardColor.BLUE, CardValue.NINE)),
    });
    await engine.drawCard(s.matchId, 'p1');
    t('off: drawing takes exactly one card',
      store.get(s.matchId).hands.p1.length === 1);
  }

  {
    const pile = Array.from({ length: 5 },
      () => card(CardColor.BLUE, CardValue.NINE));
    pile.push(card(CardColor.RED, CardValue.TWO));   // finally playable
    const s = table({
      rules: { ...rules.OFFICIAL_RULES, drawToMatch: true },
      hands: { p1: [], p2: [], p3: [] },
      drawPile: pile,
    });
    await engine.drawCard(s.matchId, 'p1');
    const after = store.get(s.matchId);
    t('on: drawing continues until something is playable',
      after.hands.p1.length === 6);
    t('and the turn stays with the drawer', after.currentTurn === 'p1');
  }

  {
    const s = table({
      rules: { ...rules.OFFICIAL_RULES, drawToMatch: true },
      hands: { p1: [], p2: [], p3: [] },
      drawPile: Array.from({ length: 3 },
        () => card(CardColor.BLUE, CardValue.NINE)),
    });
    await engine.drawCard(s.matchId, 'p1');
    t('an exhausted pile does not hang the draw',
      store.get(s.matchId).hands.p1.length <= 4);
  }

  // ── Jump-in ────────────────────────────────────────────────────
  {
    const top = card(CardColor.RED, CardValue.FIVE);
    const twin = card(CardColor.RED, CardValue.FIVE);
    const s = table({ top, hands: { p1: [], p2: [], p3: [twin] } });

    let threw = null;
    try {
      await engine.jumpIn(s.matchId, 'p3', { cardId: twin.cardId });
    } catch (e) { threw = e; }
    t('off: jumping in is refused', threw?.code === 'RULE_DISABLED');
  }

  {
    const top = card(CardColor.RED, CardValue.FIVE);
    const twin = card(CardColor.RED, CardValue.FIVE);
    const s = table({
      top,
      rules: { ...rules.OFFICIAL_RULES, jumpIn: true },
      hands: {
        p1: [], p2: [],
        p3: [twin, card(CardColor.GREEN, CardValue.EIGHT)],
      },
    });
    const { state } = await engine.jumpIn(s.matchId, 'p3', {
      cardId: twin.cardId,
    });
    t('on: an identical card jumps in', state.hands.p3.length === 1);
    t('and play continues from the jumper', state.currentTurn === 'p1');
  }

  {
    const top = card(CardColor.RED, CardValue.FIVE);
    const other = card(CardColor.BLUE, CardValue.FIVE);
    const s = table({
      top,
      rules: { ...rules.OFFICIAL_RULES, jumpIn: true },
      hands: { p1: [], p2: [], p3: [other] },
    });
    let threw = null;
    try {
      await engine.jumpIn(s.matchId, 'p3', { cardId: other.cardId });
    } catch (e) { threw = e; }
    t('the same number in another colour cannot jump in',
      threw?.code === 'INVALID_CARD');
  }

  {
    const top = card(CardColor.RED, CardValue.SKIP);
    const twin = card(CardColor.RED, CardValue.SKIP);
    const s = table({
      top,
      rules: { ...rules.OFFICIAL_RULES, jumpIn: true },
      hands: { p1: [], p2: [], p3: [twin] },
    });
    let threw = null;
    try {
      await engine.jumpIn(s.matchId, 'p3', { cardId: twin.cardId });
    } catch (e) { threw = e; }
    t('an action card cannot be jumped in', threw?.code === 'INVALID_CARD');
  }

  {
    const top = card(CardColor.RED, CardValue.FIVE);
    const twin = card(CardColor.RED, CardValue.FIVE);
    const s = table({
      top,
      rules: { ...rules.OFFICIAL_RULES, jumpIn: true },
      hands: { p1: [twin], p2: [], p3: [] },
    });
    let threw = null;
    try {
      await engine.jumpIn(s.matchId, 'p1', { cardId: twin.cardId });
    } catch (e) { threw = e; }
    t('the player already on turn cannot jump in',
      threw?.code === 'INVALID_CARD');
  }

  // ── Forced UNO penalty ─────────────────────────────────────────
  {
    const c1 = card(CardColor.RED, CardValue.ONE);
    const s = table({
      hands: { p1: [c1, card(CardColor.RED, CardValue.TWO)], p2: [], p3: [] },
    });
    await engine.playCard(s.matchId, 'p1', { cardId: c1.cardId });
    t('off: reaching one card is not punished',
      store.get(s.matchId).hands.p1.length === 1);
  }

  {
    const c1 = card(CardColor.RED, CardValue.ONE);
    const s = table({
      rules: { ...rules.OFFICIAL_RULES, forceUnoPenalty: true },
      hands: { p1: [c1, card(CardColor.RED, CardValue.TWO)], p2: [], p3: [] },
    });
    await engine.playCard(s.matchId, 'p1', { cardId: c1.cardId });
    t('on: reaching one card without calling costs two',
      store.get(s.matchId).hands.p1.length === 3);
  }

  {
    const c1 = card(CardColor.RED, CardValue.ONE);
    const s = table({
      rules: { ...rules.OFFICIAL_RULES, forceUnoPenalty: true },
      unoCalledBy: ['p1'],
      hands: { p1: [c1, card(CardColor.RED, CardValue.TWO)], p2: [], p3: [] },
    });
    await engine.playCard(s.matchId, 'p1', { cardId: c1.cardId });
    t('calling UNO first avoids the penalty',
      store.get(s.matchId).hands.p1.length === 1);
  }

  {
    const c1 = card(CardColor.RED, CardValue.ONE);
    const s = table({
      rules: { ...rules.OFFICIAL_RULES, forceUnoPenalty: true },
      hands: { p1: [c1], p2: [], p3: [] },
    });
    const { state } = await engine.playCard(s.matchId, 'p1', {
      cardId: c1.cardId,
    });
    t('going out is a win, not an offence', state.winner === 'p1');
  }

  // ── Official play is untouched with every rule off ─────────────
  {
    const skip = card(CardColor.RED, CardValue.SKIP);
    const s = table({
      hands: { p1: [skip, card(CardColor.GREEN, CardValue.EIGHT)], p2: [], p3: [] },
    });
    await engine.playCard(s.matchId, 'p1', { cardId: skip.cardId });
    t('skip still skips', store.get(s.matchId).currentTurn === 'p3');
  }

  {
    const rev = card(CardColor.RED, CardValue.REVERSE);
    const s = table({
      hands: { p1: [rev, card(CardColor.GREEN, CardValue.EIGHT)], p2: [], p3: [] },
    });
    await engine.playCard(s.matchId, 'p1', { cardId: rev.cardId });
    const after = store.get(s.matchId);
    t('reverse still reverses',
      after.direction === GameDirection.COUNTER_CLOCKWISE);
    t('and hands the turn backwards', after.currentTurn === 'p3');
  }

  console.log(`\n${pass} passed, ${fail} failed`);
  process.exit(fail ? 1 : 0);
})();
