/// Exact mirror of SOCKET_EVENTS in src/utils/constants.ts plus the ad-hoc
/// event names registered directly in src/websocket/socket.handler.ts.
class SocketEvents {
  SocketEvents._();

  // Connection
  static const connect = 'connect';
  static const disconnect = 'disconnect';
  static const authenticate = 'socket:authenticate';
  static const authenticated = 'socket:authenticated';

  // Matchmaking
  static const queueJoin = 'queue.join';
  static const queueLeave = 'queue.leave';
  static const queueJoined = 'queue.joined';
  static const queueLeft = 'queue.left';
  static const matchFound = 'match.found';

  // Room
  static const roomCreate = 'room.create';
  static const roomJoin = 'room.join';
  static const roomCreated = 'room.created';
  static const roomJoined = 'room.joined';
  static const roomLeave = 'room.leave';
  static const roomLeft = 'room.left';
  static const roomUpdated = 'room.updated';
  static const roomHostChanged = 'room.hostChanged';
  static const roomCountdown = 'room.countdown';
  static const roomCountdownCancelled = 'room.countdownCancelled';
  static const roomStart = 'room.start';
  static const roomSetRules = 'room.setRules';
  static const roomReady = 'room.ready';
  static const roomKick = 'room.kick';
  static const roomKicked = 'room.kicked';

  // Game
  static const gameStarted = 'game.started';
  static const gameInitialState = 'game.initialState';
  static const gameFinished = 'game.finished';
  static const gameSyncRequest = 'game.syncRequest';
  static const gameSyncState = 'game.syncState';

  // Gameplay
  static const cardPlay = 'card.play';
  static const cardJumpIn = 'card.jumpIn';
  static const cardDraw = 'card.draw';
  static const cardAccepted = 'card.accepted';
  static const turnChanged = 'turn.changed';
  static const playerPlayedCard = 'player.playedCard';
  static const playerDrewCard = 'player.drewCard';
  static const directionChanged = 'direction.changed';

  // UNO call
  static const unoCall = 'uno.call';
  static const unoCalled = 'uno.called';

  // Surrender
  static const surrender = 'game.surrender';

  // Rematch
  static const rematchRequest = 'rematch.request';
  static const rematchAccept = 'rematch.accept';
  static const rematchDecline = 'rematch.decline';
  static const rematchStarted = 'rematch.started';

  // Chat
  static const chatSend = 'chat.send';
  static const chatReceived = 'chat.received';
  static const quickChat = 'chat.quick';
  static const emoteSend = 'emote.send';
  static const emoteReceived = 'emote.received';

  // Direct messages
  static const dmSend = 'dm.send';
  static const dmReceived = 'dm.received';
  static const dmSent = 'dm.sent';

  /// The server rejected a message - not a friend, too long, empty. Without
  /// this the text simply vanished and the app looked broken.
  static const dmFailed = 'dm.failed';

  // Invites
  static const inviteSend = 'invite.send';
  static const inviteReceived = 'invite.received';
  static const inviteSent = 'invite.sent';
  static const inviteAccept = 'invite.accept';

  // Voice
  static const voiceJoin = 'voice.join';
  static const voiceLeave = 'voice.leave';
  static const voiceOffer = 'voice.offer';
  static const voiceAnswer = 'voice.answer';
  static const voiceIceCandidate = 'voice.iceCandidate';
  static const voiceJoined = 'voice.joined';
  static const voiceLeft = 'voice.left';
  static const voiceUserJoined = 'voice.userJoined';
  static const voiceMute = 'voice.mute';

  // Friends
  static const friendStatusUpdated = 'friend.statusUpdated';
  static const friendRequestReceived = 'friend.requestReceived';
  static const friendRequestAccepted = 'friend.requestAccepted';

  // Party
  static const partyUpdated = 'party.updated';
  static const partyInvite = 'party.invite';

  // Moderation
  static const mutePlayer = 'player.mute';
  static const unmutePlayer = 'player.unmute';
  static const blockPlayer = 'player.block';
  static const reportPlayer = 'player.report';

  // Spectator
  static const spectateJoin = 'spectate.join';
  static const spectateLeave = 'spectate.leave';
  static const spectateState = 'spectate.state';

  // System
  static const error = 'error';
  static const updateRequired = 'update.required';

  /// Client-side only: emitted by SocketService, never sent by the backend.
  /// Payload `{ reachable: bool, attempts: int, detail: String }`, so screens
  /// can distinguish "the host is unreachable" from "the server is slow".
  static const reachability = 'client.reachability';
}

/// Quick-chat presets sent via `chat.quick`.
class QuickChat {
  QuickChat._();

  static const Map<String, String> presets = {
    'NICE_MOVE': 'Nice move!',
    'GOOD_GAME': 'Good game!',
    'HURRY_UP': 'Hurry up!',
    'OOPS': 'Oops...',
    'WELL_PLAYED': 'Well played!',
    'THANKS': 'Thanks!',
    'SORRY': 'Sorry!',
    'LETS_GO': "Let's go!",
  };

  static String label(String key) => presets[key] ?? key;
}

/// Emote keys sent via `emote.send`.
class Emotes {
  Emotes._();

  static const Map<String, String> glyphs = {
    'laugh': '😂',
    'angry': '😠',
    'cool': '😎',
    'cry': '😭',
    'love': '😍',
    'shock': '😱',
    'think': '🤔',
    'clap': '👏',
    'fire': '🔥',
    'skull': '💀',
    'crown': '👑',
    'dab': '🕺',
  };

  static String glyph(String key) => glyphs[key] ?? '🙂';
}
