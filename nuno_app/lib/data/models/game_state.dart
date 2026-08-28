import 'package:equatable/equatable.dart';

import 'enums.dart';
import 'game_card.dart';
import 'house_rules.dart';
import 'json.dart';

/// A player as described by `playerNames` in the game state payload.
class GamePlayerInfo extends Equatable {
  final String userId;
  final String username;
  final int level;
  final int cardCount;

  const GamePlayerInfo({
    required this.userId,
    required this.username,
    this.level = 1,
    this.cardCount = 0,
  });

  String get initials =>
      username.isEmpty ? '?' : username.substring(0, 1).toUpperCase();

  @override
  List<Object?> get props => [userId, username, level, cardCount];
}

/// Mirrors the payload of `game.initialState` / `game.syncState`
/// (src/gameplay/game.state.ts → getPlayerStateWithNames).
class GameState extends Equatable {
  final String matchId;
  final String roomId;
  final String currentTurn;
  final GameDirection direction;
  final CardColor currentColor;
  final CardValue currentValue;
  final MatchStatus status;
  final GameCard? topCard;
  final int drawPileCount;
  final List<GameCard> myHand;
  final Map<String, int> playerCardCounts;
  final List<String> players;
  final Map<String, GamePlayerInfo> playerNames;
  final String? winner;
  final int totalTurns;

  /// Variants in force for this match. Official game unless the host chose
  /// otherwise in the lobby.
  final HouseRules houseRules;

  /// Cards owed by whoever is to move, from a stack of draw cards. Zero when
  /// nothing is pending.
  final int pendingDraw;

  const GameState({
    required this.matchId,
    required this.roomId,
    required this.currentTurn,
    this.direction = GameDirection.clockwise,
    this.currentColor = CardColor.wild,
    this.currentValue = CardValue.wild,
    this.status = MatchStatus.initializing,
    this.topCard,
    this.drawPileCount = 0,
    this.myHand = const [],
    this.playerCardCounts = const {},
    this.players = const [],
    this.playerNames = const {},
    this.winner,
    this.totalTurns = 0,
    this.houseRules = HouseRules.official,
    this.pendingDraw = 0,
  });

  factory GameState.fromJson(Map<String, dynamic> json) {
    final counts = <String, int>{};
    J.map(json['playerCardCounts']).forEach((k, v) => counts[k] = J.int_(v));

    final players =
        J.list(json['players']).map((e) => e.toString()).toList();

    final names = <String, GamePlayerInfo>{};
    J.map(json['playerNames']).forEach((k, v) {
      final m = J.map(v);
      names[k] = GamePlayerInfo(
        userId: k,
        username: J.str(m['username'], 'Player'),
        level: J.int_(m['level'], 1),
        cardCount: counts[k] ?? 0,
      );
    });

    // Guarantee an entry for every player, even if names were unavailable.
    for (final id in players) {
      names.putIfAbsent(
        id,
        () => GamePlayerInfo(
          userId: id,
          username: 'Player',
          cardCount: counts[id] ?? 0,
        ),
      );
    }

    return GameState(
      matchId: J.str(json['matchId']),
      roomId: J.str(json['roomId']),
      currentTurn: J.str(json['currentTurn']),
      direction: GameDirectionX.parse(J.strOrNull(json['direction'])),
      currentColor: CardColorX.parse(J.strOrNull(json['currentColor'])),
      currentValue: CardValueX.parse(J.strOrNull(json['currentValue'])),
      status: MatchStatusX.parse(J.strOrNull(json['status'])),
      topCard: json['topCard'] == null
          ? null
          : GameCard.fromJson(J.map(json['topCard'])),
      drawPileCount: J.int_(json['drawPileCount']),
      myHand: J
          .list(json['myHand'])
          .map((e) => GameCard.fromJson(J.map(e)))
          .toList(),
      playerCardCounts: counts,
      players: players,
      playerNames: names,
      winner: J.strOrNull(json['winner']),
      totalTurns: J.int_(json['totalTurns']),
      houseRules: json['houseRules'] == null
          ? HouseRules.official
          : HouseRules.fromJson(J.map(json['houseRules'])),
      pendingDraw: J.int_(json['pendingDraw']),
    );
  }

  // ── Derived helpers ─────────────────────────────────────────

  bool isMyTurn(String myUserId) => currentTurn == myUserId;

  GamePlayerInfo playerInfo(String userId) =>
      playerNames[userId] ??
      GamePlayerInfo(
        userId: userId,
        username: 'Player',
        cardCount: playerCardCounts[userId] ?? 0,
      );

  int cardCountOf(String userId) => playerCardCounts[userId] ?? 0;

  /// Opponents ordered starting from the seat after me, following turn order,
  /// so seats around the table stay stable and intuitive.
  List<GamePlayerInfo> opponentsFrom(String myUserId) {
    if (players.isEmpty) return const [];
    final myIndex = players.indexOf(myUserId);
    if (myIndex < 0) {
      return players.map(playerInfo).toList();
    }
    final ordered = <GamePlayerInfo>[];
    for (var i = 1; i < players.length; i++) {
      ordered.add(playerInfo(players[(myIndex + i) % players.length]));
    }
    return ordered;
  }

  /// Cards in my hand that are legally playable right now.
  List<GameCard> playableCards() => myHand
      .where((c) => c.isPlayableOn(
            currentColor: currentColor,
            currentValue: currentValue,
          ))
      .toList();

  bool isCardPlayable(GameCard card) => card.isPlayableOn(
        currentColor: currentColor,
        currentValue: currentValue,
      );

  bool get hasAnyPlayable => playableCards().isNotEmpty;

  /// True when I hold exactly one card and should call UNO.
  bool get shouldCallUno => myHand.length == 1;

  bool get isFinished => status.isOver || winner != null;

  GameState copyWith({
    List<GameCard>? myHand,
    MatchStatus? status,
    String? winner,
  }) =>
      GameState(
        matchId: matchId,
        roomId: roomId,
        currentTurn: currentTurn,
        direction: direction,
        currentColor: currentColor,
        currentValue: currentValue,
        status: status ?? this.status,
        topCard: topCard,
        drawPileCount: drawPileCount,
        myHand: myHand ?? this.myHand,
        playerCardCounts: playerCardCounts,
        players: players,
        playerNames: playerNames,
        winner: winner ?? this.winner,
        totalTurns: totalTurns,
      );

  @override
  List<Object?> get props => [
        matchId, currentTurn, direction, currentColor, currentValue,
        status, topCard, drawPileCount, myHand, playerCardCounts, winner,
      ];
}

/// Payload of the `game.finished` socket event.
class GameResultPayload extends Equatable {
  final String matchId;
  final String? winner;
  final int duration;
  final int totalTurns;
  final String? surrenderedBy;

  const GameResultPayload({
    required this.matchId,
    this.winner,
    this.duration = 0,
    this.totalTurns = 0,
    this.surrenderedBy,
  });

  factory GameResultPayload.fromJson(Map<String, dynamic> json) =>
      GameResultPayload(
        matchId: J.str(json['matchId']),
        winner: J.strOrNull(json['winner']),
        duration: J.int_(json['duration']),
        totalTurns: J.int_(json['totalTurns']),
        surrenderedBy: J.strOrNull(json['surrenderedBy']),
      );

  String get durationLabel {
    final m = duration ~/ 60;
    final s = duration % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  List<Object?> get props => [matchId, winner, duration, totalTurns];
}
