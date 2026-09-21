// Real Socket.IO server, real voice handler, real clients.
//
// The question being answered: can one room's voice signalling reach a
// player in a different room? If it can, two tables end up hearing each
// other, which is the worst class of bug in a voice feature.
require('./voiceshim.js');
require('ts-node').register({
  transpileOnly: true,
  compilerOptions: { module: 'commonjs', ignoreDeprecations: '6.0' },
});

const http = require('http');
const { Server } = require('socket.io');
const ioc = require('socket.io-client');

let pass = 0, fail = 0;
const t = (n, c) => { c ? (pass++, console.log('  ok  ' + n)) : (fail++, console.log('FAIL  ' + n)); };

const SRC = '/home/user/Nuno_Backend/src/';
const { initializeVoiceHandlers } = require(SRC + 'voice/voice.handler');

const wait = (ms) => new Promise((r) => setTimeout(r, ms));

(async () => {
  const srv = http.createServer();
  const io = new Server(srv);

  // Mirror what socket.handler.ts does after authenticate: put the socket in
  // its personal room, then wire the feature handlers.
  io.on('connection', (socket) => {
    socket.on('auth', ({ userId }) => {
      socket.userId = userId;
      socket.username = 'u_' + userId;
      socket.join(`user:${userId}`);
      initializeVoiceHandlers(io, socket);
      socket.emit('authed');
    });
  });

  await new Promise((r) => srv.listen(0, r));
  const url = `http://127.0.0.1:${srv.address().port}`;

  const connect = async (userId) => {
    const c = ioc(url, { transports: ['websocket'], forceNew: true });
    await new Promise((r) => c.on('connect', r));
    const authed = new Promise((r) => c.once('authed', r));
    c.emit('auth', { userId });
    await authed;
    c.userId = userId;
    c.inbox = [];
    for (const ev of ['voice.joined', 'voice.userJoined', 'voice.offer',
                      'voice.answer', 'voice.iceCandidate', 'voice.left',
                      'voice.muteChanged']) {
      c.on(ev, (p) => c.inbox.push({ ev, p }));
    }
    return c;
  };

  const got = (c, ev) => c.inbox.filter((m) => m.ev === ev);

  // ── Two separate rooms, two players each ───────────────────────
  const a1 = await connect('a1');
  const a2 = await connect('a2');
  const b1 = await connect('b1');
  const b2 = await connect('b2');

  a1.emit('voice.join', { roomId: 'ROOM_A' });
  await wait(80);
  a2.emit('voice.join', { roomId: 'ROOM_A' });
  await wait(80);
  b1.emit('voice.join', { roomId: 'ROOM_B' });
  await wait(80);
  b2.emit('voice.join', { roomId: 'ROOM_B' });
  await wait(150);

  // ── Joining tells you who is already there ─────────────────────
  {
    const joined = got(a2, 'voice.joined')[0];
    t('a joiner is told who is already in the channel',
      !!joined && Array.isArray(joined.p.existingParticipants));
    t('and that list is only its own room',
      joined.p.existingParticipants.length === 1 &&
      joined.p.existingParticipants[0].userId === 'a1');
  }

  {
    const joined = got(b2, 'voice.joined')[0];
    t('room B sees only room B',
      joined.p.existingParticipants.length === 1 &&
      joined.p.existingParticipants[0].userId === 'b1');
  }

  // ── userJoined must not leak across rooms ──────────────────────
  {
    const leaked = got(a1, 'voice.userJoined')
      .filter((m) => m.p.userId.startsWith('b'));
    t('room A is not told about room B joining', leaked.length === 0);
  }

  // ── Signalling is addressed, not broadcast ─────────────────────
  a1.inbox = []; a2.inbox = []; b1.inbox = []; b2.inbox = [];
  a1.emit('voice.offer', {
    targetUserId: 'a2', offer: { sdp: 'SDP_A1', type: 'offer' },
  });
  await wait(120);

  t('an offer reaches its target', got(a2, 'voice.offer').length === 1);
  t('an offer reaches its target exactly once',
    got(a2, 'voice.offer').length === 1);
  t('nobody in the other room receives it',
    got(b1, 'voice.offer').length === 0 &&
    got(b2, 'voice.offer').length === 0);
  t('the sender does not receive its own offer',
    got(a1, 'voice.offer').length === 0);
  t('the offer carries the sender id',
    got(a2, 'voice.offer')[0].p.fromUserId === 'a1');

  // ── A forged target in another room ────────────────────────────
  //
  // Signalling is relayed by user id. Nothing checks the two are in the
  // same room, so a modified client can address anyone. This is the
  // interesting case.
  b1.inbox = [];
  a1.emit('voice.offer', {
    targetUserId: 'b1', offer: { sdp: 'CROSS', type: 'offer' },
  });
  await wait(120);
  const crossed = got(b1, 'voice.offer').length;
  t('a cross-room offer is refused by the server', crossed === 0);

  // ── Leaving ────────────────────────────────────────────────────
  a2.inbox = [];
  a1.emit('voice.leave');
  await wait(120);
  t('leaving notifies the room', got(a2, 'voice.left').length === 1);

  // After leaving, a later join announcement must not reach the leaver.
  a1.inbox = [];
  const a3 = await connect('a3');
  a3.emit('voice.join', { roomId: 'ROOM_A' });
  await wait(150);
  t('a player who left stops receiving that room\'s announcements',
    got(a1, 'voice.userJoined').length === 0);

  // ── Moving rooms ───────────────────────────────────────────────
  // The real scenario: finish a match, join a different table.
  b1.inbox = [];
  a2.emit('voice.leave');
  await wait(80);
  a2.emit('voice.join', { roomId: 'ROOM_B' });
  await wait(150);

  a2.inbox = [];
  const a4 = await connect('a4');
  a4.emit('voice.join', { roomId: 'ROOM_A' });
  await wait(150);
  t('after moving rooms, the old room no longer reaches you',
    got(a2, 'voice.userJoined').filter((m) => m.p.userId === 'a4').length === 0);

  // ── Switching rooms WITHOUT calling leave first ────────────────
  //
  // The client does call leave, but the server cannot rely on that: a
  // dropped connection, a fast reconnect, or a modified client can all skip
  // it. Joining a second channel must drop the first by itself.
  const c1 = await connect('c1');
  const d1 = await connect('d1');
  c1.emit('voice.join', { roomId: 'ROOM_C' });
  d1.emit('voice.join', { roomId: 'ROOM_D' });
  await wait(150);

  // c1 moves to D without leaving C.
  c1.emit('voice.join', { roomId: 'ROOM_D' });
  await wait(150);

  c1.inbox = [];
  const c2 = await connect('c2');
  c2.emit('voice.join', { roomId: 'ROOM_C' });
  await wait(150);
  t('switching channels without leaving drops the old one',
    got(c1, 'voice.userJoined').filter((m) => m.p.userId === 'c2').length === 0);

  // And the old channel's roster must no longer list them.
  c2.inbox = [];
  const c3 = await connect('c3');
  c3.emit('voice.join', { roomId: 'ROOM_C' });
  await wait(150);
  {
    const joined = got(c3, 'voice.joined')[0];
    const ids = joined.p.existingParticipants.map((e) => e.userId).sort();
    t('the old channel roster no longer contains the mover',
      !ids.includes('c1'));
  }

  for (const c of [a1, a2, a3, a4, b1, b2, c1, c2, c3, d1]) c.close();
  io.close();
  srv.close();

  console.log(`\n${pass} passed, ${fail} failed`);
  process.exit(fail ? 1 : 0);
})();
