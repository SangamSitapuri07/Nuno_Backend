/// Enums mirroring the backend TypeScript enums.
/// Parsing is tolerant: unknown values fall back to a sane default.
library;

// ── src/gameplay/game.types.ts ──────────────────────────────

enum CardColor { red, blue, green, yellow, wild }

extension CardColorX on CardColor {
  String get wire => switch (this) {
        CardColor.red => 'RED',
        CardColor.blue => 'BLUE',
        CardColor.green => 'GREEN',
        CardColor.yellow => 'YELLOW',
        CardColor.wild => 'WILD',
      };

  String get label => switch (this) {
        CardColor.red => 'Red',
        CardColor.blue => 'Blue',
        CardColor.green => 'Green',
        CardColor.yellow => 'Yellow',
        CardColor.wild => 'Wild',
      };

  bool get isWild => this == CardColor.wild;

  static CardColor parse(String? v) => switch (v?.toUpperCase()) {
        'RED' => CardColor.red,
        'BLUE' => CardColor.blue,
        'GREEN' => CardColor.green,
        'YELLOW' => CardColor.yellow,
        _ => CardColor.wild,
      };

  /// The four colours a player may choose when playing a wild card.
  static const List<CardColor> pickable = [
    CardColor.red,
    CardColor.blue,
    CardColor.green,
    CardColor.yellow,
  ];
}

enum CardValue {
  zero, one, two, three, four, five, six, seven, eight, nine,
  skip, reverse, drawTwo, wild, wildDrawFour,
}

extension CardValueX on CardValue {
  String get wire => switch (this) {
        CardValue.zero => '0',
        CardValue.one => '1',
        CardValue.two => '2',
        CardValue.three => '3',
        CardValue.four => '4',
        CardValue.five => '5',
        CardValue.six => '6',
        CardValue.seven => '7',
        CardValue.eight => '8',
        CardValue.nine => '9',
        CardValue.skip => 'SKIP',
        CardValue.reverse => 'REVERSE',
        CardValue.drawTwo => 'DRAW_TWO',
        CardValue.wild => 'WILD',
        CardValue.wildDrawFour => 'WILD_DRAW_FOUR',
      };

  /// Short glyph rendered on the card face.
  String get glyph => switch (this) {
        CardValue.skip => '\u2298',        // ⊘
        CardValue.reverse => '\u21C4',     // ⇄
        CardValue.drawTwo => '+2',
        CardValue.wild => '\u2726',        // ✦
        CardValue.wildDrawFour => '+4',
        _ => wire,
      };

  String get label => switch (this) {
        CardValue.skip => 'Skip',
        CardValue.reverse => 'Reverse',
        CardValue.drawTwo => 'Draw Two',
        CardValue.wild => 'Wild',
        CardValue.wildDrawFour => 'Wild Draw Four',
        _ => wire,
      };

  bool get isNumber => index <= CardValue.nine.index;
  bool get isAction =>
      this == CardValue.skip ||
      this == CardValue.reverse ||
      this == CardValue.drawTwo;
  bool get isWild =>
      this == CardValue.wild || this == CardValue.wildDrawFour;

  static CardValue parse(String? v) => switch (v?.toUpperCase()) {
        '0' => CardValue.zero,
        '1' => CardValue.one,
        '2' => CardValue.two,
        '3' => CardValue.three,
        '4' => CardValue.four,
        '5' => CardValue.five,
        '6' => CardValue.six,
        '7' => CardValue.seven,
        '8' => CardValue.eight,
        '9' => CardValue.nine,
        'SKIP' => CardValue.skip,
        'REVERSE' => CardValue.reverse,
        'DRAW_TWO' => CardValue.drawTwo,
        'WILD_DRAW_FOUR' => CardValue.wildDrawFour,
        _ => CardValue.wild,
      };
}

enum GameDirection { clockwise, counterClockwise }

extension GameDirectionX on GameDirection {
  String get wire => this == GameDirection.clockwise
      ? 'CLOCKWISE'
      : 'COUNTER_CLOCKWISE';

  static GameDirection parse(String? v) =>
      v?.toUpperCase() == 'COUNTER_CLOCKWISE'
          ? GameDirection.counterClockwise
          : GameDirection.clockwise;
}

enum MatchStatus {
  initializing, waitingFirstTurn, running, paused, finished, destroyed,
}

extension MatchStatusX on MatchStatus {
  static MatchStatus parse(String? v) => switch (v?.toUpperCase()) {
        'WAITING_FIRST_TURN' => MatchStatus.waitingFirstTurn,
        'RUNNING' => MatchStatus.running,
        'PAUSED' => MatchStatus.paused,
        'FINISHED' => MatchStatus.finished,
        'DESTROYED' => MatchStatus.destroyed,
        _ => MatchStatus.initializing,
      };

  bool get isOver =>
      this == MatchStatus.finished || this == MatchStatus.destroyed;
}

// ── src/rooms/room.types.ts ─────────────────────────────────

enum RoomStatus {
  created, waiting, ready, countdown, inGame, finished, destroyed,
}

extension RoomStatusX on RoomStatus {
  static RoomStatus parse(String? v) => switch (v?.toUpperCase()) {
        'WAITING' => RoomStatus.waiting,
        'READY' => RoomStatus.ready,
        'COUNTDOWN' => RoomStatus.countdown,
        'IN_GAME' => RoomStatus.inGame,
        'FINISHED' => RoomStatus.finished,
        'DESTROYED' => RoomStatus.destroyed,
        _ => RoomStatus.created,
      };

  String get label => switch (this) {
        RoomStatus.countdown => 'Starting',
        RoomStatus.inGame => 'In game',
        RoomStatus.ready => 'Ready',
        RoomStatus.finished => 'Finished',
        _ => 'Waiting',
      };
}

// ── src/matchmaking/matchmaking.types.ts ────────────────────

enum GameMode { casual, ranked, private, custom }

extension GameModeX on GameMode {
  String get wire => switch (this) {
        GameMode.casual => 'CASUAL',
        GameMode.ranked => 'RANKED',
        GameMode.private => 'PRIVATE',
        GameMode.custom => 'CUSTOM',
      };

  String get label => switch (this) {
        GameMode.casual => 'Casual',
        GameMode.ranked => 'Ranked',
        GameMode.private => 'Private',
        GameMode.custom => 'Custom',
      };

  static GameMode parse(String? v) => switch (v?.toUpperCase()) {
        'RANKED' => GameMode.ranked,
        'PRIVATE' => GameMode.private,
        'CUSTOM' => GameMode.custom,
        _ => GameMode.casual,
      };
}

enum QueueStatus { idle, searching, matchFound, confirming, lobby, inGame }

// ── src/friends/friends.types.ts ────────────────────────────

enum PlayerOnlineStatus { online, inMatch, inLobby, away, offline, doNotDisturb }

extension PlayerOnlineStatusX on PlayerOnlineStatus {
  String get wire => switch (this) {
        PlayerOnlineStatus.online => 'ONLINE',
        PlayerOnlineStatus.inMatch => 'IN_MATCH',
        PlayerOnlineStatus.inLobby => 'IN_LOBBY',
        PlayerOnlineStatus.away => 'AWAY',
        PlayerOnlineStatus.offline => 'OFFLINE',
        PlayerOnlineStatus.doNotDisturb => 'DO_NOT_DISTURB',
      };

  String get label => switch (this) {
        PlayerOnlineStatus.online => 'Online',
        PlayerOnlineStatus.inMatch => 'In match',
        PlayerOnlineStatus.inLobby => 'In lobby',
        PlayerOnlineStatus.away => 'Away',
        PlayerOnlineStatus.offline => 'Offline',
        PlayerOnlineStatus.doNotDisturb => 'Do not disturb',
      };

  bool get isOnline => this != PlayerOnlineStatus.offline;

  static PlayerOnlineStatus parse(String? v) => switch (v?.toUpperCase()) {
        'ONLINE' => PlayerOnlineStatus.online,
        'IN_MATCH' => PlayerOnlineStatus.inMatch,
        'IN_LOBBY' => PlayerOnlineStatus.inLobby,
        'AWAY' => PlayerOnlineStatus.away,
        'DO_NOT_DISTURB' => PlayerOnlineStatus.doNotDisturb,
        _ => PlayerOnlineStatus.offline,
      };
}

// ── src/economy/economy.types.ts ────────────────────────────

enum CosmeticType {
  avatar, cardBack, cardTheme, cardAnimation, tableTheme,
  profileBanner, badge, title, emote, voicePack,
}

extension CosmeticTypeX on CosmeticType {
  String get wire => switch (this) {
        CosmeticType.avatar => 'AVATAR',
        CosmeticType.cardBack => 'CARD_BACK',
        CosmeticType.cardTheme => 'CARD_THEME',
        CosmeticType.cardAnimation => 'CARD_ANIMATION',
        CosmeticType.tableTheme => 'TABLE_THEME',
        CosmeticType.profileBanner => 'PROFILE_BANNER',
        CosmeticType.badge => 'BADGE',
        CosmeticType.title => 'TITLE',
        CosmeticType.emote => 'EMOTE',
        CosmeticType.voicePack => 'VOICE_PACK',
      };

  String get label => switch (this) {
        CosmeticType.avatar => 'Avatars',
        CosmeticType.cardBack => 'Card Backs',
        CosmeticType.cardTheme => 'Card Themes',
        CosmeticType.cardAnimation => 'Animations',
        CosmeticType.tableTheme => 'Tables',
        CosmeticType.profileBanner => 'Banners',
        CosmeticType.badge => 'Badges',
        CosmeticType.title => 'Titles',
        CosmeticType.emote => 'Emotes',
        CosmeticType.voicePack => 'Voices',
      };

  static CosmeticType parse(String? v) => switch (v?.toUpperCase()) {
        'CARD_BACK' => CosmeticType.cardBack,
        'CARD_THEME' => CosmeticType.cardTheme,
        'CARD_ANIMATION' => CosmeticType.cardAnimation,
        'TABLE_THEME' => CosmeticType.tableTheme,
        'PROFILE_BANNER' => CosmeticType.profileBanner,
        'BADGE' => CosmeticType.badge,
        'TITLE' => CosmeticType.title,
        'EMOTE' => CosmeticType.emote,
        'VOICE_PACK' => CosmeticType.voicePack,
        _ => CosmeticType.avatar,
      };
}

enum ItemRarity { common, rare, epic, legendary, mythic }

extension ItemRarityX on ItemRarity {
  String get wire => name.toUpperCase();

  String get label => switch (this) {
        ItemRarity.common => 'Common',
        ItemRarity.rare => 'Rare',
        ItemRarity.epic => 'Epic',
        ItemRarity.legendary => 'Legendary',
        ItemRarity.mythic => 'Mythic',
      };

  static ItemRarity parse(String? v) => switch (v?.toUpperCase()) {
        'RARE' => ItemRarity.rare,
        'EPIC' => ItemRarity.epic,
        'LEGENDARY' => ItemRarity.legendary,
        'MYTHIC' => ItemRarity.mythic,
        _ => ItemRarity.common,
      };
}

enum CurrencyType { coins, gems, eventTokens }

extension CurrencyTypeX on CurrencyType {
  String get wire => switch (this) {
        CurrencyType.coins => 'COINS',
        CurrencyType.gems => 'GEMS',
        CurrencyType.eventTokens => 'EVENT_TOKENS',
      };

  static CurrencyType parse(String? v) => switch (v?.toUpperCase()) {
        'GEMS' => CurrencyType.gems,
        'EVENT_TOKENS' => CurrencyType.eventTokens,
        _ => CurrencyType.coins,
      };
}

// ── src/leaderboard/leaderboard.types.ts ────────────────────

enum RankTier { bronze, silver, gold, platinum, diamond, master, grandmaster }

extension RankTierX on RankTier {
  String get wire => name.toUpperCase();

  String get label => switch (this) {
        RankTier.bronze => 'Bronze',
        RankTier.silver => 'Silver',
        RankTier.gold => 'Gold',
        RankTier.platinum => 'Platinum',
        RankTier.diamond => 'Diamond',
        RankTier.master => 'Master',
        RankTier.grandmaster => 'Grandmaster',
      };

  static RankTier parse(String? v) => switch (v?.toUpperCase()) {
        'SILVER' => RankTier.silver,
        'GOLD' => RankTier.gold,
        'PLATINUM' => RankTier.platinum,
        'DIAMOND' => RankTier.diamond,
        'MASTER' => RankTier.master,
        'GRANDMASTER' => RankTier.grandmaster,
        _ => RankTier.bronze,
      };
}

/// Highest level a player can reach. Mirrors MAX_LEVEL in
/// src/users/leveling.ts.
const int kMaxLevel = 50;

/// Total xp required to reach each level, indexed by level number.
///
/// Generated by the same rule as XP_FOR_LEVEL in src/users/leveling.ts
/// (step = 200 + (level - 1) * 50), so the bar the player sees always agrees
/// with the level the server awards. Index 0 is unused.
final List<int> kLevelThresholds = () {
  final table = <int>[0, 0];
  for (var level = 2; level <= kMaxLevel; level++) {
    table.add(table[level - 1] + 200 + (level - 1) * 50);
  }
  return List<int>.unmodifiable(table);
}();
