import 'package:equatable/equatable.dart';

import 'enums.dart';
import 'json.dart';

/// Mirrors `RoomPlayer` in src/rooms/room.types.ts
class RoomPlayer extends Equatable {
  final String userId;
  final String username;
  final String? avatarUrl;
  final bool isReady;
  final bool isHost;
  final bool isVoiceConnected;
  final int ping;
  final int joinedAt;

  const RoomPlayer({
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.isReady = false,
    this.isHost = false,
    this.isVoiceConnected = false,
    this.ping = 0,
    this.joinedAt = 0,
  });

  factory RoomPlayer.fromJson(Map<String, dynamic> json) => RoomPlayer(
        userId: J.str(json['userId']),
        username: J.str(json['username'], 'Player'),
        avatarUrl: J.strOrNull(json['avatarUrl']),
        isReady: J.bool_(json['isReady']),
        isHost: J.bool_(json['isHost']),
        isVoiceConnected: J.bool_(json['isVoiceConnected']),
        ping: J.int_(json['ping']),
        joinedAt: J.int_(json['joinedAt']),
      );

  @override
  List<Object?> get props => [userId, isReady, isHost, isVoiceConnected, ping];
}

/// Mirrors `Room` in src/rooms/room.types.ts
class GameRoom extends Equatable {
  final String roomId;
  final String roomCode;
  final String hostId;
  final List<RoomPlayer> players;
  final int maxPlayers;
  final int currentPlayers;
  final bool voiceEnabled;
  final bool chatEnabled;
  final GameMode gameMode;
  final RoomStatus status;
  final String? matchId;

  const GameRoom({
    required this.roomId,
    required this.roomCode,
    required this.hostId,
    this.players = const [],
    this.maxPlayers = 4,
    this.currentPlayers = 0,
    this.voiceEnabled = true,
    this.chatEnabled = true,
    this.gameMode = GameMode.private,
    this.status = RoomStatus.waiting,
    this.matchId,
  });

  factory GameRoom.fromJson(Map<String, dynamic> json) => GameRoom(
        roomId: J.str(json['roomId']),
        roomCode: J.str(json['roomCode']),
        hostId: J.str(json['hostId']),
        players: J
            .list(json['players'])
            .map((e) => RoomPlayer.fromJson(J.map(e)))
            .toList(),
        maxPlayers: J.int_(json['maxPlayers'], 4),
        currentPlayers: J.int_(json['currentPlayers']),
        voiceEnabled: J.bool_(json['voiceEnabled'], true),
        chatEnabled: J.bool_(json['chatEnabled'], true),
        gameMode: GameModeX.parse(J.strOrNull(json['gameMode'])),
        status: RoomStatusX.parse(J.strOrNull(json['status'])),
        matchId: J.strOrNull(json['matchId']),
      );

  bool isHost(String userId) => hostId == userId;

  RoomPlayer? playerById(String userId) {
    for (final p in players) {
      if (p.userId == userId) return p;
    }
    return null;
  }

  bool get isFull => players.length >= maxPlayers;
  bool get canStart =>
      players.length >= 2 && players.every((p) => p.isReady || p.isHost);
  bool get allReady => players.isNotEmpty && players.every((p) => p.isReady);

  @override
  List<Object?> get props =>
      [roomId, roomCode, hostId, players, status, maxPlayers];
}

/// Payload of the `match.found` socket event.
class MatchFoundPayload extends Equatable {
  final String matchId;
  final String roomId;
  final String roomCode;
  final GameMode mode;
  final List<MatchFoundPlayer> players;

  const MatchFoundPayload({
    required this.matchId,
    required this.roomId,
    required this.roomCode,
    required this.mode,
    this.players = const [],
  });

  factory MatchFoundPayload.fromJson(Map<String, dynamic> json) =>
      MatchFoundPayload(
        matchId: J.str(json['matchId']),
        roomId: J.str(json['roomId']),
        roomCode: J.str(json['roomCode']),
        mode: GameModeX.parse(J.strOrNull(json['mode'])),
        players: J
            .list(json['players'])
            .map((e) => MatchFoundPlayer.fromJson(J.map(e)))
            .toList(),
      );

  @override
  List<Object?> get props => [matchId, roomId, players];
}

class MatchFoundPlayer extends Equatable {
  final String userId;
  final String username;
  final int rating;

  const MatchFoundPlayer({
    required this.userId,
    required this.username,
    this.rating = 1000,
  });

  factory MatchFoundPlayer.fromJson(Map<String, dynamic> json) =>
      MatchFoundPlayer(
        userId: J.str(json['userId']),
        username: J.str(json['username'], 'Player'),
        rating: J.int_(json['rating'], 1000),
      );

  @override
  List<Object?> get props => [userId];
}
