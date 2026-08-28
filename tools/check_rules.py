#!/usr/bin/env python3
"""Guards the house-rules feature.

Two things must stay true:

  * The official Mattel game is the default. Every variant is opt-in, and a
    match started without an explicit rule set is the official one.
  * House rules exist only in a private room. Quick Match pairs strangers by
    rating who have agreed to nothing, so its rules must never vary.
"""
import os
import re
import sys

BACK = 'src'
LIB = sys.argv[1] if len(sys.argv) > 1 else 'nuno_app/lib'
fails = []


def read(p):
    with open(p, encoding='utf8') as f:
        return f.read()


def want(cond, msg):
    if not cond:
        fails.append(msg)


def strip_comments(src):
    out = []
    for line in src.splitlines():
        if line.lstrip().startswith(('//', '///', '*', '/*')):
            continue
        out.append(line)
    return '\n'.join(out)


# ── 1. Off by default ────────────────────────────────────────────
hr = read(os.path.join(BACK, 'gameplay/house.rules.ts'))
want('OFFICIAL_RULES' in hr, 'house.rules: no OFFICIAL_RULES')

block = hr[hr.index('export const OFFICIAL_RULES'):]
block = block[:block.index('};')]
want('true' not in block,
     'house.rules: OFFICIAL_RULES has a rule switched on - the default must '
     'be the official Mattel game')

keys = re.findall(r"^\s*'(\w+)',", hr[hr.index('HOUSE_RULE_KEYS'):], re.M)
want(len(keys) >= 5, 'house.rules: HOUSE_RULE_KEYS looks empty')
for k in keys:
    want(f'{k}: false' in block,
         f'house.rules: {k} is not defaulted to false in OFFICIAL_RULES')

# The interface and the key list must agree, or a rule silently becomes
# unsettable from the lobby.
iface = hr[hr.index('export interface HouseRules'):]
iface = iface[:iface.index('}')]
declared = set(re.findall(r'^\s*(\w+):\s*boolean;', iface, re.M))
want(declared == set(keys),
     f'house.rules: HOUSE_RULE_KEYS {sorted(set(keys))} does not match the '
     f'interface {sorted(declared)}')

# ── 2. normaliseHouseRules must not trust the client ─────────────
norm = hr[hr.index('export const normaliseHouseRules'):]
norm = norm[:norm.index('\n};')]
want('=== true' in norm,
     'house.rules: normaliseHouseRules accepts any truthy value - only a '
     'real true should enable a rule')
want('OFFICIAL_RULES' in norm,
     'house.rules: normaliseHouseRules does not start from the official set')

# ── 3. Quick Match is always official ────────────────────────────
mm = strip_comments(read(os.path.join(BACK, 'matchmaking/matchmaking.handler.ts')))
call = mm[mm.index('initializeMatch('):]
call = call[:call.index(');') + 2]
want('OFFICIAL_RULES' in call,
     'matchmaking: Quick Match does not pass OFFICIAL_RULES explicitly')
want('houseRules' not in call,
     'matchmaking: Quick Match must not take rules from a room')

# Nothing in matchmaking may set a rule.
want('normaliseHouseRules' not in mm,
     'matchmaking: house rules are being parsed in the queue path')

# ── 4. The room path does pass its rules ─────────────────────────
rh = strip_comments(read(os.path.join(BACK, 'rooms/room.handler.ts')))
rcall = rh[rh.index('initializeMatch('):]
rcall = rcall[:rcall.index(');') + 2]
want('houseRules' in rcall,
     'rooms: the lobby does not pass its house rules into the match')

want('ROOM_SET_RULES' in rh, 'rooms: no room.setRules handler')

# ── 5. Only the host, and only before the game starts ────────────
rs = read(os.path.join(BACK, 'rooms/room.service.ts'))
setter = rs[rs.index('async setHouseRules'):]
setter = setter[:setter.index('\n  }')]
want('NOT_HOST' in setter,
     'room.service: setHouseRules does not refuse a non-host')
want('hostId !== userId' in setter,
     'room.service: setHouseRules does not compare against the host')
want('RoomStatus.WAITING' in setter,
     'room.service: the rules can be changed after the game has started')
want('normaliseHouseRules' in setter,
     'room.service: setHouseRules stores the raw request')

# ── 6. Jump-in is gated on the rule ──────────────────────────────
re_src = read(os.path.join(BACK, 'gameplay/rule.engine.ts'))
jump = re_src[re_src.index('canJumpIn('):]
jump = jump[:jump.index('\n  }')]
want('houseRules?.jumpIn' in jump,
     'rule.engine: canJumpIn does not check the rule is enabled')
want('currentTurn === userId' in jump,
     'rule.engine: canJumpIn lets the player on turn jump in')
want('CardType.NUMBER' in jump,
     'rule.engine: canJumpIn allows action cards')
want('pendingDraw' in jump,
     'rule.engine: canJumpIn ignores a pending draw stack')

eng = read(os.path.join(BACK, 'gameplay/game.engine.ts'))
ejump = eng[eng.index('async jumpIn('):]
ejump = ejump[:ejump.index('\n  async ')]
want('RULE_DISABLED' in ejump,
     'game.engine: jumpIn does not refuse when the rule is off')

# ── 7. Stacking is same-type only, and capped ────────────────────
valid = re_src[re_src.index('isValidPlay('):]
valid = valid[:valid.index('\n  }')]
want('pendingDrawType' in valid,
     'rule.engine: a pending stack can be answered with the wrong card type')
want('MAX_STACK_DRAW' in eng,
     'game.engine: a stacked penalty is uncapped')

# ── 8. The client mirrors the default ────────────────────────────
dart = read(os.path.join(LIB, 'data/models/house_rules.dart'))
ctor = dart[dart.index('const HouseRules({'):]
ctor = ctor[:ctor.index('});')]
want('true' not in ctor,
     'house_rules.dart: a rule defaults to on')
want('static const official = HouseRules();' in dart,
     'house_rules.dart: no official constant')

for k in keys:
    want(k in dart, f'house_rules.dart: {k} is missing from the client model')
    want(f"'{k}'" in dart,
         f'house_rules.dart: {k} is not serialised, so it can never be sent')

# Count the entries in the list literal, not the type argument: the
# declaration reads `<HouseRuleSpec>[` with no trailing paren, so it is not
# counted by 'HouseRuleSpec(' at all - an earlier `- 1` here was wrong and
# reported a complete list as short.
specs = dart[dart.index('const houseRuleSpecs'):]
specs = specs[:specs.index('\n];')]
want(specs.count('HouseRuleSpec(') == len(keys),
     f'house_rules.dart: the lobby offers {specs.count("HouseRuleSpec(")} of '
     f'{len(keys)} rules')

# ── 9. The picker is in the lobby, not in matchmaking ────────────
want(os.path.exists(os.path.join(LIB, 'features/lobby/widgets/house_rules_sheet.dart')),
     'the house-rules sheet is missing')

mmscr = read(os.path.join(LIB, 'features/matchmaking/matchmaking_screen.dart'))
want('HouseRules' not in mmscr and 'houseRules' not in mmscr,
     'matchmaking_screen references house rules - Quick Match must not offer '
     'them')

lobby = read(os.path.join(LIB, 'features/lobby/lobby_screen.dart'))
want('HouseRulesSheet' in lobby, 'lobby_screen does not open the rules sheet')
want('editable: isHost' in lobby,
     'lobby_screen lets a guest edit the rules')

# ── 10. The hand allows a jump-in tap ────────────────────────────
hand = read(os.path.join(LIB, 'features/game/widgets/player_hand.dart'))
want('canJumpIn' in hand,
     'player_hand blocks every out-of-turn tap, so a jump-in can never be '
     'made')

for f in fails:
    print('FAIL ', f)
print(f'FAILURES: {len(fails)}')
sys.exit(1 if fails else 0)
