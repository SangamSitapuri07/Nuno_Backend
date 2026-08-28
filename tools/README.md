# Checks

Run from the repository root.

```
python3 tools/check_dart.py nuno_app/lib          # brace balance, imports resolve
python3 tools/check_matchmaking.py nuno_app/lib   # the Quick Match reset
node    tools/mmstate.test.js                     # matchmaking state machine
```

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
