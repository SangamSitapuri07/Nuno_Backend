export const SOCKET_EVENTS = {
  // Connection
  CONNECT: 'connect',
  DISCONNECT: 'disconnect',
  AUTHENTICATE: 'socket:authenticate',
  AUTHENTICATED: 'socket:authenticated',

  // Matchmaking
  QUEUE_JOIN: 'queue.join',
  QUEUE_LEAVE: 'queue.leave',
  MATCH_FOUND: 'match.found',

  // Room
  ROOM_CREATE: 'room.create',
  ROOM_JOIN: 'room.join',
  ROOM_CREATED: 'room.created',
  ROOM_JOINED: 'room.joined',
  ROOM_LEAVE: 'room.leave',
  ROOM_UPDATED: 'room.updated',
  ROOM_HOST_CHANGED: 'room.hostChanged',
  ROOM_COUNTDOWN: 'room.countdown',
  ROOM_COUNTDOWN_CANCELLED: 'room.countdownCancelled',

  // Game
  GAME_STARTED: 'game.started',
  GAME_INITIAL_STATE: 'game.initialState',
  GAME_FINISHED: 'game.finished',
  GAME_SYNC_REQUEST: 'game.syncRequest',
  GAME_SYNC_STATE: 'game.syncState',

  // Gameplay
  CARD_PLAY: 'card.play',
  CARD_DRAW: 'card.draw',
  CARD_ACCEPTED: 'card.accepted',
  TURN_CHANGED: 'turn.changed',
  PLAYER_PLAYED_CARD: 'player.playedCard',
  PLAYER_DREW_CARD: 'player.drewCard',
  DIRECTION_CHANGED: 'direction.changed',

  // Chat
  CHAT_SEND: 'chat.send',
  CHAT_RECEIVED: 'chat.received',

  // Voice
  VOICE_JOIN: 'voice.join',
  VOICE_LEAVE: 'voice.leave',
  VOICE_OFFER: 'voice.offer',
  VOICE_ANSWER: 'voice.answer',
  VOICE_ICE_CANDIDATE: 'voice.iceCandidate',
  VOICE_JOINED: 'voice.joined',
  VOICE_LEFT: 'voice.left',

  // Friends
  FRIEND_STATUS_UPDATED: 'friend.statusUpdated',

  // Party
  PARTY_UPDATED: 'party.updated',
  PARTY_INVITE: 'party.invite',

  // System
  ERROR: 'error',
  UPDATE_REQUIRED: 'update.required',
    // Mute/Block
  MUTE_PLAYER: 'player.mute',
  UNMUTE_PLAYER: 'player.unmute',
  BLOCK_PLAYER: 'player.block',

  // Reports
  REPORT_PLAYER: 'player.report',

  // Surrender
  SURRENDER: 'game.surrender',

  // Rematch
  REMATCH_REQUEST: 'rematch.request',
  REMATCH_ACCEPT: 'rematch.accept',
  REMATCH_DECLINE: 'rematch.decline',
  REMATCH_STARTED: 'rematch.started',

  // Quick Chat & Emotes
  QUICK_CHAT: 'chat.quick',
  EMOTE_SEND: 'emote.send',
  EMOTE_RECEIVED: 'emote.received',

  // Spectator
  SPECTATE_JOIN: 'spectate.join',
  SPECTATE_LEAVE: 'spectate.leave',
  SPECTATE_STATE: 'spectate.state',
};

export const GAME_CONSTANTS = {
  MIN_PLAYERS: 2,
  MAX_PLAYERS: 10,
  INITIAL_HAND_SIZE: 7,
  TURN_TIMER_SECONDS: 20,
  MAX_CHAT_LENGTH: 200,
  CHAT_RATE_LIMIT: 5,
  CHAT_RATE_WINDOW: 10000,
  RECONNECT_WINDOW_SECONDS: 60,
  HEARTBEAT_INTERVAL: 25000,
  HEARTBEAT_TIMEOUT: 10000,
};

export const HTTP_STATUS = {
  OK: 200,
  CREATED: 201,
  NO_CONTENT: 204,
  BAD_REQUEST: 400,
  UNAUTHORIZED: 401,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
  CONFLICT: 409,
  UNPROCESSABLE: 422,
  TOO_MANY_REQUESTS: 429,
  INTERNAL_ERROR: 500,
  SERVICE_UNAVAILABLE: 503,
};

export const ERROR_CODES = {
  AUTH_FAILED: 'AUTH_FAILED',
  INVALID_EVENT: 'INVALID_EVENT',
  INVALID_PAYLOAD: 'INVALID_PAYLOAD',
  INVALID_ROOM: 'INVALID_ROOM',
  INVALID_MATCH: 'INVALID_MATCH',
  INVALID_TURN: 'INVALID_TURN',
  INVALID_CARD: 'INVALID_CARD',
  RATE_LIMIT: 'RATE_LIMIT',
  SERVER_ERROR: 'SERVER_ERROR',
  SYNC_REQUIRED: 'SYNC_REQUIRED',
  VALIDATION_ERROR: 'VALIDATION_ERROR',
  QUEUE_FULL: 'QUEUE_FULL',
  ALREADY_IN_QUEUE: 'ALREADY_IN_QUEUE',
  INVALID_MODE: 'INVALID_MODE',
  ROOM_NOT_FOUND: 'ROOM_NOT_FOUND',
  ROOM_FULL: 'ROOM_FULL',
  ROOM_LOCKED: 'ROOM_LOCKED',
  PLAYER_ALREADY_IN_ROOM: 'PLAYER_ALREADY_IN_ROOM',
  HOST_ONLY_ACTION: 'HOST_ONLY_ACTION',
  PLAYER_NOT_READY: 'PLAYER_NOT_READY',
};