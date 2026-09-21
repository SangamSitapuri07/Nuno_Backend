"""Document body, shared by the PDF and Word builders.

Kept in one place so the two outputs cannot drift apart.
Callers must define: h1 h2 h3 p small code gap bullets qa table story W
"""


def build(api):
    h1, h2, h3 = api["h1"], api["h2"], api["h3"]
    p, small, code, gap = api["p"], api["small"], api["code"], api["gap"]
    bullets, qa, table = api["bullets"], api["qa"], api["table"]
    story, W, mm = api["story"], api["W"], api["mm"]
    Paragraph, SMALL, PageBreak = api["Paragraph"], api["SMALL"], api["PageBreak"]

    # ══ TITLE ════════════════════════════════════════════════════════
    h1('Nuno — Real-Time Multiplayer Card Game')
    # Raw markup, deliberately not passed through rich(): that escapes tags,
    # which is correct everywhere except here.
    story.append(Paragraph(
        'A technical walkthrough: architecture, stack, and how each feature '
        'was built.<br/>'
        'Backend: Node.js &#183; TypeScript &#183; Socket.IO &#183; Prisma &#183; '
        'PostgreSQL<br/>'
        'Client: Flutter &#183; Riverpod &#160;&#8212;&#160; '
        'Hosting: Render &#183; Neon Postgres',
        SMALL))

    gap(6)
    story.append(table([
        ['Metric', 'Value'],
        ['Backend code', '10,884 lines of TypeScript across 72 files'],
        ['Client code', '21,637 lines of Dart across 92 files'],
        ['Database', '12 Prisma models, 5 migrations, PostgreSQL'],
        ['Real-time API', '60 Socket.IO events'],
        ['REST API', '~35 endpoints across 9 route modules'],
        ['Commits', '100'],
    ], [48 * mm, W - 48 * mm]))

    gap(8)
    p('This document explains what the project is, why each technical choice '
      'was made, and how the harder features actually work. It is written to be '
      'read before an interview: every claim maps to code you can open.')

    # ══ 1. WHAT IT IS ════════════════════════════════════════════════
    h2('1. What the project is')

    p('Nuno is a real-time multiplayer card game — UNO-style rules — playable '
      'on Android. Players sign in with Google, then either join a matchmaking '
      'queue to be paired with strangers, or create a private room and invite '
      'friends with a share code. A match runs live over WebSockets with a '
      '20-second turn timer, voice chat, emotes and text chat.')

    p('Around the game sits the progression layer: XP and levels, an Elo-style '
      'rating with rank tiers, a global and friends leaderboard, a coin economy, '
      'and a cosmetics shop of 61 items (avatars, card backs, table themes, '
      'avatar frames, badges, titles, emotes).')

    h3('The one design decision everything else follows from')

    p('**The server is authoritative.** The client never decides anything that '
      'matters. It does not know other players\' cards, it does not decide whose '
      'turn it is, and it cannot declare itself the winner. It sends intent '
      '("play this card id") and renders whatever state the server sends back.')

    p('This matters because the alternative — trusting the client — is how '
      'multiplayer games get cheated. The rule engine, the deck, the turn order '
      'and the win check all live on the server. A modified client can send '
      'anything it likes; the server rejects what is not legal.')

    code("""// The client sends only an id. It does not send the card, its
    // colour, or what it thinks should happen.
    socket.emit('card.play', { cardId: 'a3f9...' });

    // The server resolves the card from the player's own hand, checks
    // ownership, checks it is their turn, checks the play is legal,
    // then applies the effect and broadcasts new state to everyone.""")

    # ══ 2. STACK ═════════════════════════════════════════════════════
    h2('2. Technology stack, and why')

    story.append(table([
        ['Layer', 'Choice', 'Why this one'],
        ['Language (server)', 'TypeScript',
         'Compile-time safety on a domain full of enums — card colours, values, '
         'match states. A typo in a state name becomes a build error, not a '
         'runtime bug.'],
        ['HTTP', 'Express 5',
         'Only used for auth, profile, shop and leaderboard. Gameplay is not '
         'REST — it is push-based, so it belongs on a socket.'],
        ['Real-time', 'Socket.IO 4',
         'Rooms, automatic reconnection and a fallback transport out of the box. '
         'Raw WebSockets would have meant writing all three.'],
        ['Database', 'PostgreSQL via Prisma 5',
         'Relational data — users, friends, matches, cosmetics — with real '
         'foreign keys. Prisma gives typed queries and versioned migrations.'],
        ['Auth', 'Google OAuth + JWT',
         'No password to store, reset or leak. Short-lived access token plus a '
         'long-lived refresh token.'],
        ['Validation', 'Zod',
         'Request bodies are parsed into known shapes at the boundary, so no '
         'handler has to guess what it received.'],
        ['Client', 'Flutter + Riverpod',
         'One codebase, native performance. Riverpod because game state has to '
         'be shared across many widgets and survive navigation.'],
        ['Voice', 'WebRTC (flutter_webrtc)',
         'Peer-to-peer audio. The server only relays signalling, so voice does '
         'not consume server bandwidth.'],
        ['Hosting', 'Render + Neon',
         'Free tier, managed Postgres, deploy on git push.'],
    ], [30 * mm, 30 * mm, W - 60 * mm]))

    # ══ 3. ARCHITECTURE ══════════════════════════════════════════════
    story.append(PageBreak())
    h2('3. Architecture')

    h3('The three layers')

    code("""+---------------------------------------------------+
    |  FLUTTER CLIENT                                   |
    |  Widgets  ->  Riverpod providers  ->  Repositories|
    |       |                              |            |
    |   Socket.IO (gameplay)          Dio (REST)        |
    +-------|------------------------------|------------+
            |                              |
    +-------v------------------------------v------------+
    |  NODE SERVER                                      |
    |                                                   |
    |   socket.handler.ts            Express routes     |
    |        |                            |             |
    |   +----v----------------------------v----+        |
    |   |  Feature modules                     |        |
    |   |  gameplay / rooms / matchmaking      |        |
    |   |  auth / friends / economy / ...      |        |
    |   +----+----------------------+----------+        |
    |        |                      |                   |
    |    KV store               Prisma ORM              |
    |    (live state)           (durable data)          |
    +--------|----------------------|-------------------+
             |                      |
       Redis / Postgres       PostgreSQL (Neon)
       / in-memory""")

    h3('Why the server splits storage in two')

    p('Live match state and durable records have completely different needs, '
      'so they go to different places.')

    story.append(table([
        ['', 'Live state (KV store)', 'Durable data (Postgres)'],
        ['Holds',
         'Current match, hands, whose turn, room membership, matchmaking queue',
         'Users, friendships, finished matches, cosmetics owned, ratings'],
        ['Lifetime', 'Minutes — deleted when the match ends',
         'Forever'],
        ['Access pattern', 'Read and write on every single card play',
         'Written once when a match finishes'],
        ['If lost', 'One match is disrupted', 'Unacceptable'],
    ], [26 * mm, (W - 26 * mm) / 2, (W - 26 * mm) / 2]))

    gap(4)
    p('Putting live match state in Postgres would mean a database write on every '
      'card. Putting user accounts in a KV store would mean losing them.')

    h3('The KV store is an interface, not a product')

    p('`src/config/redis.ts` defines a `Store` interface and three '
      'implementations that satisfy it:')

    bullets([
        '`RedisStore` — used when `REDIS_URL` is set.',
        '`PgStore` — a key-value table inside Postgres. The production default, '
        'because the project runs on one instance and Redis free tiers have '
        'command quotas that a game blows through.',
        '`InMemoryStore` — a plain Map, for local development with no '
        'infrastructure at all.',
    ])

    p('Nothing else in the codebase knows which one is active. This was a '
      'deliberate design choice, and it paid off: switching from Redis to '
      'Postgres in production was a config change, not a rewrite.')

    # ══ 4. GAMEPLAY ══════════════════════════════════════════════════
    story.append(PageBreak())
    h2('4. The gameplay engine — the core of the project')

    p('`src/gameplay/` is the largest module at 2,256 lines. It is split so each '
      'file has one job:')

    story.append(table([
        ['File', 'Responsibility'],
        ['`deck.engine.ts`',
         'Builds the 108-card deck, shuffles it, deals hands, and rebuilds the '
         'draw pile from the discard pile when it runs out.'],
        ['`rule.engine.ts`',
         'Pure functions: is this play legal, whose turn is next, does this card '
         'match. No state is written here.'],
        ['`game.engine.ts`',
         'Applies a play: removes the card, resolves its effect, advances the '
         'turn, checks for a win, persists the new state.'],
        ['`game.state.ts`',
         'Reads and writes match state, and builds the per-player view.'],
        ['`game.handler.ts`',
         'Socket event handlers plus the turn timer.'],
        ['`house.rules.ts`',
         'The optional rule variants and their defaults.'],
    ], [34 * mm, W - 34 * mm]))

    h3('4.1 Deck integrity')

    p('A real UNO deck is 108 cards and the distribution is not uniform — one '
      'zero per colour, two of every other number, two of each action card, '
      'four Wilds and four Wild Draw Fours. Getting this wrong is invisible until '
      'someone notices the odds feel off.')

    code("""4 colours x  1 zero                =   4
    4 colours x  9 numbers x 2         =  72
    4 colours x  3 actions x 2         =  24
    Wild                               =   4
    Wild Draw Four                     =   4
                                         ---
                                         108""")

    p('Every card gets a UUID at deal time. That is what makes "play this card" '
      'safe to express as an id: two red sevens are different objects, and the '
      'server can verify the specific card is in that player\'s hand.')

    h3('4.2 The per-player view — how hands stay secret')

    p('The server holds one complete match state containing every hand. It never '
      'sends that object to anyone. `getPlayerState()` builds a different view '
      'per player:')

    code("""myHand:            [full card objects]   // only yours
    playerCardCounts:  { p2: 5, p3: 3 }      // others: a number only
    topCard, currentColor, currentTurn, ...  // shared, public""")

    p('Opponent hands leave the server as counts. There is nothing to intercept, '
      'because the information was never transmitted.')

    h3('4.3 The turn timer, and the performance problem it caused')

    p('Each match has a 20-second turn limit, plus an auto-draw at 3 seconds if '
      'the player has nothing playable. The first implementation checked this '
      'once a second:')

    code("""setInterval(async () => {
      const state = await store.get(`game:${matchId}`);  // every second
      ...
    }, 1000);""")

    p('That is one store read per match per second, **whether or not anything is '
      'happening**. The cost scales with the number of open tables, not with '
      'player activity. 500 idle matches cost 500 reads/second.')

    p('The fix: a turn is only actionable at two known moments. After each check '
      'the timer computes when it next needs to look and skips every tick until '
      'then. A skipped tick is an integer comparison in process memory — no '
      'network call.')

    story.append(table([
        ['', 'Before', 'After'],
        ['Reads per 20-second turn', '20', '2'],
        ['500 concurrent matches', '500 reads/sec', '50 reads/sec'],
    ], [56 * mm, (W - 56 * mm) / 2, (W - 56 * mm) / 2]))

    gap(4)
    small('A related fix: broadcasting table state resolved usernames with a '
          'database query per player, per broadcast. A 5-minute TTL cache took a '
          '4-player broadcast from 4 queries to 1, then 0.')

    # ══ 5. HOUSE RULES ═══════════════════════════════════════════════
    story.append(PageBreak())
    h2('5. House rules — configurable gameplay')

    p('Real UNO players almost never play the printed rules. The most common '
      'variant, stacking a +2 on a +2, is not official — Mattel has said so '
      'explicitly — but roughly half of all players use it.')

    p('So the game ships with the **official Mattel ruleset as the default**, '
      'and six opt-in variants the room host can tick in any combination:')

    story.append(table([
        ['Variant', 'Effect'],
        ['Stack +2', 'Answer a +2 with your own +2; the penalty accumulates.'],
        ['Stack +4', 'The same for +4. Cannot be mixed with +2 chains.'],
        ['Jump-in',
         'Play an identical card (same colour and number) out of turn. Numbers '
         'only — action cards would make turn order unresolvable.'],
        ['Seven-Zero',
         'A 7 swaps hands with a chosen player; a 0 rotates every hand one seat.'],
        ['Draw to match', 'Keep drawing until a playable card appears.'],
        ['Forced UNO', 'Miss the UNO call and draw two automatically.'],
    ], [30 * mm, W - 30 * mm]))

    h3('Three decisions worth defending')

    p('**Default is official.** A rule set where variants are opt-in means a new '
      'player gets the game they expect. Every flag defaults to `false`, and a '
      'malformed request degrades to the official game rather than being '
      'rejected.')

    p('**Variants only exist in private rooms.** Quick Match pairs strangers by '
      'rating who have agreed to nothing, so a queue whose rules varied would be '
      'unplayable. The matchmaking path passes `OFFICIAL_RULES` explicitly rather '
      'than relying on the parameter default, so the guarantee is visible in the '
      'code and not an accident.')

    p('**Stacking is same-type only.** Research into how people actually play '
      'showed that groups who allow stacking still reject mixing +2 and +4 '
      'chains. The pending stack records its own card type and rejects the other.')

    code("""// A stack is pending: the only legal answer is the same draw card.
    if (state.pendingDraw && state.pendingDraw > 0) {
      return card.value === state.pendingDrawType;
    }""")

    p('The chain is also capped, so a long stack cannot empty the draw pile and '
      'deadlock the match.')

    # ══ 6. MATCHMAKING ═══════════════════════════════════════════════
    h2('6. Two ways into a game')

    h3('6.1 Quick Match — the rating queue')

    p('The player picks a table size (2, 3, 4, 6 or 8) and joins a queue. The '
      'queue key is per mode **and** per size:')

    code("queue:{mode}:{tableSize}      e.g. queue:CASUAL:4")

    p('Splitting the key this way means a player who asked for a 2-player game '
      'can never be pulled into a 6-player table. When a queue reaches its '
      'required size, the server creates a room, deals a match and pushes '
      '`game.started` to everyone.')

    p('There is no background sweeper — the queue is processed on join. That is '
      'cheap and correct, but it created a bug worth describing (section 9.3).')

    h3('6.2 Private rooms')

    p('A room gets a short share code. Players join by typing the code or by '
      'accepting a socket invite from a friend. The host controls the table size, '
      'the house rules, kicking, and the start; guests mark themselves ready. '
      'Starting runs a countdown that cancels if someone leaves or un-readies.')

    # ══ 7. PROGRESSION ═══════════════════════════════════════════════
    story.append(PageBreak())
    h2('7. Progression, economy and social')

    h3('7.1 XP and levels')

    p('The level curve is **generated, not hand-written**, so it cannot drift out '
      'of order:')

    code("""step = 200 + (level - 1) * 50
    XP_FOR_LEVEL[level] = XP_FOR_LEVEL[level - 1] + step""")

    p('50 levels, quadratic — early levels arrive fast, later ones take real '
      'play. The same table is used when a match ends and when a profile is read, '
      'so the server and the progress bar can never disagree. Levelling up pays '
      'coins, with larger milestones at every 5th, 10th and 25th level.')

    h3('7.2 Rating and tiers')

    p('Winning a match is +25 rating, losing is −15. Rating maps to seven tiers '
      '(Bronze through Grandmaster), each split into three divisions.')

    p('The tier is **derived from the rating on every read** rather than trusted '
      'from the stored column. That choice fixed a real bug: the original code '
      'incremented `rating` but never recomputed `tier`, so a 1020-rated player '
      'was still labelled "Bronze III" when Gold starts at 1000. Deriving on read '
      'meant every existing row became correct the moment the code shipped — no '
      'backfill migration needed.')

    h3('7.3 Economy and cosmetics')

    p('61 catalogue items across seven cosmetic types. Coins come from playing '
      'matches, levelling up, and a 7-day daily reward streak. Purchases are '
      'server-priced (section 9.1). Equipping is exclusive per type, done in a '
      'transaction so a player can never end up with two card backs or none.')

    small('The daily reward uses an IST day boundary and an atomic increment as a '
          'claim guard, because the naive version could be claimed twice by '
          'tapping quickly.')

    h3('7.4 Friends and presence')

    p('Friends are added by a public 10-digit player ID — the same idea as Free '
      'Fire or BGMI. The internal primary key is a UUID and is never shown; '
      'nobody is going to read 36 hex characters out to a friend.')

    p('Presence is resolved in strict priority order so the answer is never '
      'ambiguous:')

    code("OFFLINE  >  IN_MATCH  >  IN_LOBBY  >  ONLINE")

    p('Direct messages persist for 24 hours with an hourly sweep, so a message '
      'sent to an offline friend is still there when they log in.')

    # ══ 8. CLIENT ════════════════════════════════════════════════════
    h2('8. The Flutter client')

    p('21,637 lines of Dart, organised by feature rather than by type — '
      '`features/game/`, `features/lobby/`, `features/store/` — so everything '
      'belonging to one screen sits together.')

    h3('State management')

    p('Riverpod, because game state has to be shared across many widgets, '
      'survive navigation, and update from socket events arriving outside any '
      'widget\'s lifecycle.')

    story.append(table([
        ['Provider type', 'Used for'],
        ['`Provider`', 'Dependency injection — repositories, the socket service'],
        ['`StateNotifierProvider`',
         'Complex mutable state — the game controller, auth, matchmaking'],
        ['`FutureProvider`',
         'Server-backed reads — inventory, leaderboard, rank'],
        ['`StateProvider`', 'Simple flags — panel visibility, revision counters'],
    ], [42 * mm, W - 42 * mm]))

    h3('Keeping the socket and the REST session in sync')

    p('The two halves need each other: a refreshed access token has to reach the '
      'socket, and a handshake the server rejects has to trigger a refresh. '
      'Wiring that inside either provider would make them mutually dependent, and '
      'Riverpod cannot infer a type through a cycle. The callbacks live in a '
      'third provider so both stay standalone — a small piece of design that '
      'avoided a real architectural problem.')

    # ══ 9. BUGS ══════════════════════════════════════════════════════
    story.append(PageBreak())
    h2('9. Bugs worth talking about')

    small('These are the most likely interview questions. Each one has a commit.')

    h3('9.1 The shop could be robbed')

    p('`purchaseItem` trusted the price in the request body:')

    code("""// The client said what the item cost.
    data: { coins: { decrement: input.price } }""")

    p('Two exploits followed:')

    bullets([
        '`price: 0` bought any item free — including the 4,000-coin ones.',
        '`price: -100000` ran `decrement: -100000`. **Decrementing by a negative '
        'number adds.** The wallet went from 100 to 100,100.',
    ])

    p('The second is the more interesting one, because it is not obvious from '
      'reading the line. The fix: the request now carries only an item id, and '
      'price, type and availability are all resolved from the server-side '
      'catalogue.')

    h3('9.2 One rejected promise could kill the server')

    p('Two calls in the post-authenticate block were floating promises — started, '
      'never awaited, no `.catch`. Node terminates the process on an unhandled '
      'rejection, so **one storage blip during one player\'s login would '
      'disconnect everyone in every match.**')

    p('Both are now caught. The server also gained process-level handlers: '
      '`unhandledRejection` logs and keeps serving, `uncaughtException` logs, '
      'closes the HTTP server and exits cleanly.')

    h3('9.3 Ghost players in the matchmaking queue')

    p('Disconnecting released the player\'s room but not their queue entry, which '
      'had a one-hour TTL. Because the queue is only processed on join, the next '
      'player to arrive was paired with a socket that no longer existed — and '
      'waited in a match that would never start.')

    p('Fixed by releasing the queue entry in the disconnect path, alongside the '
      'room.')

    h3('9.4 A sanitiser that quietly corrupted every array')

    p('An input-sanitising middleware rebuilt objects with a plain `{}` literal. '
      'In JavaScript an array **is** an object, so:')

    code("""{ "uids": ["123", "456"] }      // what was sent
    { "uids": { "0": "123", "1": "456" } }   // what the route saw""")

    p('Every `Array.isArray()` check downstream failed, turning valid requests '
      'into 400s. This ran on every request body in the application, so it was '
      'never really a bug in one endpoint.')

    p('**The lesson was in the test, not the fix.** The endpoint\'s tests passed '
      'because they mounted the router alone, without the middleware stack the '
      'real server runs. A test that does not reproduce the real request path '
      'will happily pass against broken code.')

    h3('9.5 A circular dependency in the client')

    p('Currency and rank were read by five screens through four independent '
      'caches, none of which expired, and the tabs are an `IndexedStack` so all '
      'five stay mounted. Whichever loaded first kept its value — the home header '
      'said 750 coins while the shop said 540.')

    p('The first fix made it worse. A central helper invalidated every cache '
      'from the auth controller, which created a cycle:')

    code("""authController  --invalidate-->  inventoryProvider
    inventoryProvider  --watch-->     currentUserId
    currentUserId      --watch-->     authController""")

    p('`ref.invalidate` looks like a one-way command, but Riverpod records it as '
      'a dependency edge. The result was a `CircularDependencyError` on every '
      'button that refreshed the profile — buying, claiming, finishing a match.')

    p('The working fix inverts the arrows: a revision counter that depends on '
      'nothing, which each cache watches for itself. Bumping it re-runs them all, '
      'and the graph stays acyclic.')

    h3('9.6 Cosmetics that equipped correctly and looked broken')

    p('Four avatar frames rendered as solid white squares over the player\'s '
      'portrait. The server was correct, the database was correct, the UI was '
      'correct — the PNGs had **no alpha channel**. They had been exported with '
      'the transparency checkerboard baked into the pixels.')

    p('Worth remembering as an example of a bug that is not in the code at all. '
      'The fix was a flood fill from the border and the hollow centre, plus a '
      'check that now fails the build if any overlay asset ships without '
      'transparency.')

    # ══ 10. SECURITY ═════════════════════════════════════════════════
    story.append(PageBreak())
    h2('10. Security')

    story.append(table([
        ['Concern', 'How it is handled'],
        ['Authentication',
         'Google OAuth — the ID token is verified server-side against Google\'s '
         'public keys. No password is ever stored.'],
        ['Sessions',
         'Short-lived JWT access token, long-lived refresh token. The client '
         're-handshakes the socket when the token is renewed.'],
        ['Socket authorisation',
         'Every handler checks `socket.userId`. An unauthenticated socket can '
         'reach nothing.'],
        ['Server-authoritative play',
         'Card legality, turn order, ownership and win conditions are all decided '
         'server-side.'],
        ['Economy',
         'Prices come from the catalogue, never the request.'],
        ['Input',
         'Zod schemas at the boundary, plus XSS stripping and prototype-pollution '
         'key filtering.'],
        ['Rate limiting', '`express-rate-limit`, with a tighter limit on auth.'],
        ['Headers', 'Helmet, and a CORS allowlist.'],
        ['Admin endpoints',
         'Disabled entirely unless `ADMIN_TOKEN` is set, refuse a token shorter '
         'than 24 characters, and compare in constant time.'],
    ], [34 * mm, W - 34 * mm]))

    # ══ 11. WHAT I'D DO DIFFERENTLY ══════════════════════════════════
    h2('11. Limitations, and what I would change')

    p('Being able to answer this honestly is worth more than pretending the '
      'project is finished.')

    bullets([
        '**Single instance.** Socket.IO only attaches its Redis adapter when '
        '`REDIS_URL` is set. Scaling to a second instance needs Redis, and I '
        'measured what that would cost before deciding to defer it — a complete '
        '4-player game is roughly 268 store commands, which puts ~50 games/day '
        'at 80% of a typical free tier. That measurement is why the project runs '
        'on Postgres instead.',
        '**No automated CI.** Tests and checks are run manually. They should run '
        'on every push.',
        '**Rating is not true Elo.** Flat +25/−15 ignores opponent strength. Real '
        'Elo would be a better model.',
        '**Some UI is ahead of the backend.** Achievements and a season pass are '
        'designed but not wired to real data.',
        '**Reconnection is partial.** Match state is restored, but a player who '
        'disconnects mid-turn loses that turn to the timer.',
    ])

    # ══ 12. INTERVIEW Q&A ════════════════════════════════════════════
    story.append(PageBreak())
    h2('12. Likely interview questions')

    qa('Why Socket.IO instead of plain WebSockets?',
       'Three things I would otherwise have written myself: rooms (broadcasting '
       'to four players without tracking sockets manually), automatic '
       'reconnection with backoff, and a polling fallback for restrictive '
       'networks. On mobile, connections drop constantly — reconnection alone '
       'justified it.')

    qa('How do you stop a modified client from cheating?',
       'The client is never trusted with anything that matters. It does not '
       'receive other players\' cards, so it cannot leak them. It sends a card '
       'id, and the server verifies the card is in that player\'s hand, that it '
       'is their turn, and that the play is legal. Prices come from the '
       'catalogue, not the request — that one was a real exploit I found and '
       'fixed.')

    qa('Why Postgres for live match state instead of Redis?',
       'I measured it first. One live 4-player table is about 13.7 KB, so memory '
       'was never the constraint — command volume was. A full game is roughly 268 '
       'store commands, and the free tiers I looked at cap commands, not memory. '
       'Since the app runs on a single instance, Postgres handles the load '
       'comfortably. The store is behind an interface, so moving to Redis is a '
       'config change when a second instance is needed.')

    qa('What was the hardest bug?',
       'A circular dependency I introduced while fixing something else. Currency '
       'was stale across screens, so I added a central invalidator — which made '
       'the auth controller depend on the providers that already depended on it. '
       '`ref.invalidate` reads like a command but Riverpod treats it as a '
       'dependency edge, so every button that refreshed the profile threw. The '
       'fix was to invert the direction: a revision counter that depends on '
       'nothing and that each cache watches for itself.')

    qa('How did you find the performance problem?',
       'I counted store operations across a full match rather than guessing. That '
       'showed the turn timer was reading state once per second per match — cost '
       'scaling with open tables rather than with player activity. Since a turn '
       'is only actionable at two moments, the timer now computes when it next '
       'needs to look and skips every tick until then. 20 reads per turn became '
       '2.')

    qa('Why are house rules only available in private rooms?',
       'Consent. In a private room everyone can see the rules before the game '
       'starts. In Quick Match you are paired with a stranger by rating and have '
       'agreed to nothing, so varying the rules there would be unplayable. The '
       'matchmaking path passes the official rule set explicitly rather than '
       'relying on a default, so the guarantee is visible in the code.')

    qa('What would you do differently?',
       'Set up CI from day one — every test I wrote is run by hand, which is a '
       'discipline that does not survive a deadline. I would also design the '
       'shared-state layer for multiple instances from the start rather than '
       'retrofitting the adapter.')

    gap(10)
    small('Every claim in this document maps to code in the repository. The '
          'strongest answer to "can you prove it" is to open the commit.')


