import 'package:equatable/equatable.dart';

import 'enums.dart';
import 'json.dart';

/// GET /api/v1/friends
class Friend extends Equatable {
  final String friendshipId;
  final String userId;
  final String username;
  final String? avatarUrl;
  final PlayerOnlineStatus status;
  final String? roomCode;
  final DateTime? lastOnline;

  const Friend({
    required this.friendshipId,
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.status = PlayerOnlineStatus.offline,
    this.roomCode,
    this.lastOnline,
  });

  factory Friend.fromJson(Map<String, dynamic> json) => Friend(
        friendshipId: J.str(json['friendshipId']),
        userId: J.str(json['userId']),
        username: J.str(json['username']),
        avatarUrl: J.strOrNull(json['avatarUrl']),
        status: PlayerOnlineStatusX.parse(J.strOrNull(json['status'])),
        roomCode: J.strOrNull(json['roomCode']),
        lastOnline: J.date(json['lastOnline']),
      );

  Friend copyWith({PlayerOnlineStatus? status, String? roomCode}) => Friend(
        friendshipId: friendshipId,
        userId: userId,
        username: username,
        avatarUrl: avatarUrl,
        status: status ?? this.status,
        roomCode: roomCode ?? this.roomCode,
        lastOnline: lastOnline,
      );

  /// True when this friend is in a joinable lobby.
  bool get isJoinable =>
      status == PlayerOnlineStatus.inLobby && (roomCode?.isNotEmpty ?? false);

  /// Whether it makes sense to invite them to a room.
  ///
  /// An offline player will never see the invite, and one already in a match
  /// cannot accept it, so offering the action in those states just produces
  /// an invite that silently goes nowhere.
  bool get isInvitable =>
      status == PlayerOnlineStatus.online ||
      status == PlayerOnlineStatus.away ||
      status == PlayerOnlineStatus.inLobby;

  @override
  List<Object?> get props => [userId, status, roomCode];
}

/// GET /api/v1/friends/requests (Prisma FriendRequest + sender)
class FriendRequest extends Equatable {
  final String id;
  final String senderId;
  final String senderUsername;
  final String? senderAvatarUrl;
  final DateTime? createdAt;

  const FriendRequest({
    required this.id,
    required this.senderId,
    required this.senderUsername,
    this.senderAvatarUrl,
    this.createdAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    final sender = J.map(json['sender']);
    return FriendRequest(
      id: J.str(json['id']),
      senderId: J.str(sender['id'] ?? json['senderId']),
      senderUsername: J.str(sender['username'], 'Player'),
      senderAvatarUrl: J.strOrNull(sender['avatarUrl']),
      createdAt: J.date(json['createdAt']),
    );
  }

  @override
  List<Object?> get props => [id, senderId];
}

/// GET /api/v1/players/search
class PlayerSearchResult extends Equatable {
  final String id;

  /// The public player number, shown under the name so it is obvious you
  /// found the right account.
  final String uid;

  final String username;
  final String? avatarUrl;
  final int rankPoints;

  const PlayerSearchResult({
    required this.id,
    this.uid = '',
    required this.username,
    this.avatarUrl,
    this.rankPoints = 0,
  });

  factory PlayerSearchResult.fromJson(Map<String, dynamic> json) =>
      PlayerSearchResult(
        id: J.str(json['id']),
        uid: J.str(json['uid']),
        username: J.str(json['username']),
        avatarUrl: J.strOrNull(json['avatarUrl']),
        rankPoints: J.int_(json['rankPoints']),
      );

  @override
  List<Object?> get props => [id];
}

/// GET /api/v1/leaderboard/global | /friends
class LeaderboardEntry extends Equatable {
  final int rank;
  final String userId;
  final String username;
  final String? avatarUrl;
  final int rating;
  final RankTier tier;
  final String division;
  final int wins;

  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.rating = 1000,
    this.tier = RankTier.bronze,
    this.division = 'III',
    this.wins = 0,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        rank: J.int_(json['rank']),
        userId: J.str(json['userId']),
        username: J.str(json['username']),
        avatarUrl: J.strOrNull(json['avatarUrl']),
        rating: J.int_(json['rating'], 1000),
        tier: RankTierX.parse(J.strOrNull(json['tier'])),
        division: J.str(json['division'], 'III'),
        wins: J.int_(json['wins']),
      );

  @override
  List<Object?> get props => [userId, rank, rating];
}

/// A chat line from the `chat.received` socket event.
class ChatMessage extends Equatable {
  final String userId;
  final String username;
  final String message;
  final DateTime timestamp;
  final bool isSystem;

  const ChatMessage({
    required this.userId,
    required this.username,
    required this.message,
    required this.timestamp,
    this.isSystem = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        userId: J.str(json['userId']),
        username: J.str(json['username'], 'Player'),
        message: J.str(json['message']),
        timestamp: J.dateMs(json['timestamp']),
      );

  factory ChatMessage.system(String message) => ChatMessage(
        userId: 'system',
        username: 'System',
        message: message,
        timestamp: DateTime.now(),
        isSystem: true,
      );

  @override
  List<Object?> get props => [userId, message, timestamp, isSystem];
}

/// GET /api/v1/messages/:friendId  (Prisma DirectMessage)
class DirectMessage extends Equatable {
  final String id;
  final String senderId;
  final String receiverId;
  final String body;
  final DateTime? readAt;
  final DateTime? createdAt;

  const DirectMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.body,
    this.readAt,
    this.createdAt,
  });

  factory DirectMessage.fromJson(Map<String, dynamic> json) => DirectMessage(
        id: J.str(json['id']),
        senderId: J.str(json['senderId']),
        receiverId: J.str(json['receiverId']),
        body: J.str(json['body']),
        readAt: J.date(json['readAt']),
        createdAt: J.date(json['createdAt']),
      );

  /// True when [userId] wrote this message.
  bool sentBy(String? userId) => userId != null && senderId == userId;

  @override
  List<Object?> get props => [id, senderId, receiverId, body, readAt];
}
