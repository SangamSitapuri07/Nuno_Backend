// The matchmaking screen is a state machine, and the bug is a state that is
// never cleared. Ported faithfully from matchmaking_providers.dart so the
// sequence can be replayed without a Flutter engine.
//
// User report: play a match, finish it, go back to Play -> Quick Match, and
// the table-size picker never appears - it drops straight into a 4-player
// search.

let pass = 0, fail = 0;
const t = (n, c) => { c ? (pass++, console.log('  ok  ' + n)) : (fail++, console.log('FAIL  ' + n)); };

const IDLE = 'idle', SEARCHING = 'searching', MATCH_FOUND = 'matchFound',
      IN_GAME = 'inGame';

/** Mirror of MatchmakingController. */
class Controller {
  constructor() { this.reset(); }

  reset() {
    this.status = IDLE;
    this.tableSize = 2;
    this.elapsed = 0;
    this.match = null;
    this.error = null;
  }

  joinQueue(size) {
    this.status = SEARCHING;
    this.tableSize = size;
    this.elapsed = 0;
  }

  leaveQueue() { this.reset(); }

  // ── socket events ──
  onQueueJoined(size) { this.status = SEARCHING; this.tableSize = size; }
  onQueueLeft() { this.reset(); }
  onMatchFound(players) { this.status = MATCH_FOUND; this.match = { players }; }
  onGameStarted() { this.status = IN_GAME; }
}

/**
 * Mirror of _MatchmakingScreenState.
 *
 * `_tableSize = 4` is field state, recreated whenever the screen is pushed.
 * The picker is shown only while the controller says idle.
 */
class Screen {
  constructor(controller) {
    this.c = controller;
    this.tableSize = 4;          // the default in the Dart source
  }

  get showsPicker() { return this.c.status === IDLE; }

  /** What the player is dropped into if the picker never appears. */
  get impliedSize() { return this.tableSize; }
}

// ── A first visit works ──────────────────────────────────────────
{
  const c = new Controller();
  const s = new Screen(c);
  t('a fresh app shows the table-size picker', s.showsPicker);
}

// ── The reported bug ─────────────────────────────────────────────
{
  const c = new Controller();
  const s1 = new Screen(c);

  // Player picks 2, searches, gets matched, plays.
  s1.tableSize = 2;
  c.joinQueue(2);
  c.onQueueJoined(2);
  c.onMatchFound(['a', 'b']);
  c.onGameStarted();
  t('the controller is inGame during the match', c.status === IN_GAME);

  // Match ends. game_screen's onLobby resets the game controller AND the
  // matchmaking controller - the second of those is the fix.
  c.reset();

  // Player taps Play -> Quick Match again. A brand-new screen object, but
  // the controller is a provider and outlives it.
  const s2 = new Screen(c);
  t('the picker is shown again after a match', s2.showsPicker);
  t('and the player is not forced into a 4-player table',
    s2.showsPicker || s2.impliedSize !== 4);
}

// ── Once fixed, the same sequence must survive repeats ───────────
{
  const c = new Controller();
  for (let round = 1; round <= 3; round++) {
    const s = new Screen(c);
    t(`round ${round}: the picker is shown`, s.showsPicker);
    s.tableSize = 3;
    c.joinQueue(3);
    c.onQueueJoined(3);
    c.onMatchFound(['a', 'b', 'c']);
    c.onGameStarted();
    c.reset();                    // what the fix must arrange
  }
}

// ── A stale size must not leak into the next search ──────────────
{
  const c = new Controller();
  c.joinQueue(6);
  c.onQueueJoined(6);
  c.onGameStarted();
  c.reset();
  t('the table size returns to its default after a match',
    c.tableSize === 2);
  t('and no match payload is left behind', c.match === null);
  t('and the timer count is cleared', c.elapsed === 0);
}

// ── Cancelling still works ───────────────────────────────────────
{
  const c = new Controller();
  c.joinQueue(4);
  t('joining moves out of idle', c.status === SEARCHING);
  c.leaveQueue();
  t('leaving the queue returns to idle', c.status === IDLE);
  const s = new Screen(c);
  t('and the picker comes back', s.showsPicker);
}

// ── The server-driven queue.left event resets too ────────────────
{
  const c = new Controller();
  c.joinQueue(8);
  c.onQueueLeft();
  t('a server queue.left returns to idle', c.status === IDLE);
}

// ── The screen's own initState guard ─────────────────────────────
// game_screen resetting is one half; the screen clearing a stale status on
// entry is the other, so a status left behind by any other path still cannot
// hide the picker.
const enterScreen = (c) => {
  const s = new Screen(c);
  if (c.status !== SEARCHING && c.status !== MATCH_FOUND) c.reset();
  return s;
};

{
  const c = new Controller();
  c.onGameStarted();                        // stale inGame, nothing reset it
  const s = enterScreen(c);
  t('entering the screen clears a stale inGame status', s.showsPicker);
}

{
  const c = new Controller();
  c.joinQueue(6);
  const s = enterScreen(c);
  t('a live search is NOT thrown away on re-entry',
    !s.showsPicker && c.status === SEARCHING);
  t('and it keeps the size being searched for', c.tableSize === 6);
}

{
  const c = new Controller();
  c.joinQueue(4);
  c.onMatchFound(['a', 'b', 'c', 'd']);
  const s = enterScreen(c);
  t('a found match is not thrown away either',
    !s.showsPicker && c.status === MATCH_FOUND);
}

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
