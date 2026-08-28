# Checks

Run from the repository root.

```
python3 tools/check_dart.py nuno_app/lib          # brace balance, imports resolve
python3 tools/check_matchmaking.py nuno_app/lib   # the Quick Match reset
python3 tools/check_rules.py nuno_app/lib         # official default, room-only rules
node    tools/mmstate.test.js                     # matchmaking state machine
node    tools/rules.test.js                       # house rules against the engine
```

`rules.test.js` needs the backend's node_modules on its path; run it from a
directory where `require('ts-node')` resolves.

These live in the repository rather than a scratch directory because the
previous copies were kept outside it and were lost, taking the regression
coverage with them.

## What check_matchmaking.py guards

`MatchmakingController` is a Riverpod provider, so it outlives the screen.
Finishing a match left its status on `inGame` and nothing cleared it. The
table-size picker is drawn only while the status is `idle`, so the second
visit to Quick Match skipped the picker entirely and searched for a size the
player never chose.

Two things have to stay true:

  * `game_screen`'s `onLobby` resets the matchmaking controller.
  * `matchmaking_screen.initState` clears a stale status, but leaves a live
    `searching` or `matchFound` alone so re-entering the screen mid-search
    does not throw the search away. It must defer the write with
    `addPostFrameCallback`, since writing provider state during `initState`
    throws.

## What check_rules.py guards

The default is the official Mattel game. Mattel has said plainly that
stacking is not part of UNO, and jump-in, seven-zero and draw-to-match are
variants too, so a player who touches nothing gets the game on the box.

Two invariants:

  * `OFFICIAL_RULES` has every flag `false`, on both the server and the
    client, and a match started without an explicit set uses it.
  * House rules exist only in a private lobby. Quick Match passes
    `OFFICIAL_RULES` explicitly and the matchmaking screen never mentions
    them - strangers paired by rating have agreed to nothing.

Plus the things that are easy to get subtly wrong: only the host may change
the rules and only before the game starts, a stack can only be answered with
the same card type, and the hand widget must allow an out-of-turn tap or a
jump-in can never actually be played.
