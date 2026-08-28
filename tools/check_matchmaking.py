#!/usr/bin/env python3
"""Guards the matchmaking reset.

The bug: MatchmakingController is a provider, so it outlives the screen.
Finishing a match left its status on `inGame` and nothing ever cleared it.
The table-size picker is drawn only while the status is `idle`, so the second
visit to Quick Match skipped the picker and searched for a size the player
never chose.
"""
import os
import re
import sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else 'nuno_app/lib'
fails = []


def read(p):
    with open(os.path.join(ROOT, p), encoding='utf8') as f:
        return f.read()


def want(cond, msg):
    if not cond:
        fails.append(msg)


# ── The controller still offers a reset ──────────────────────────
prov = read('features/matchmaking/matchmaking_providers.dart')
want('void reset()' in prov, 'matchmaking_providers: reset() is gone')

# ── The end of a match clears it ─────────────────────────────────
game = read('features/game/game_screen.dart')
i = game.find('onLobby:')
want(i != -1, 'game_screen: no onLobby callback')
if i != -1:
    block = game[i:i + 1200]
    want('matchmakingControllerProvider' in block
         and 'reset()' in block,
         'game_screen: onLobby does not reset the matchmaking controller - '
         'the next Quick Match will skip the table-size picker')
want("import '../matchmaking/matchmaking_providers.dart';" in game,
     'game_screen: matchmaking_providers is not imported')

# ── The screen clears a stale status on entry ────────────────────
scr = read('features/matchmaking/matchmaking_screen.dart')
want('void initState()' in scr,
     'matchmaking_screen: no initState, so a stale status is never cleared')

j = scr.find('void initState()')
if j != -1:
    body = scr[j:scr.find('void _startSearch', j)]
    want('reset()' in body,
         'matchmaking_screen: initState does not reset the controller')
    want('addPostFrameCallback' in body,
         'matchmaking_screen: provider state must not be written during '
         'initState - defer it with addPostFrameCallback')
    # A genuine search must survive re-entry.
    want('QueueStatus.searching' in body,
         'matchmaking_screen: initState resets unconditionally, which throws '
         'away a live search when the screen is re-entered')
    want('QueueStatus.matchFound' in body,
         'matchmaking_screen: initState would throw away a found match')

# ── The picker is still gated on idle ────────────────────────────
want('QueueStatus.idle' in scr,
     'matchmaking_screen: the picker is no longer gated on idle')

# ── The default table size is not silently applied ───────────────
m = re.search(r'int _tableSize = (\d+);', scr)
want(m is not None, 'matchmaking_screen: _tableSize field is gone')

for f in fails:
    print('FAIL ', f)
print(f'FAILURES: {len(fails)}')
sys.exit(1 if fails else 0)
