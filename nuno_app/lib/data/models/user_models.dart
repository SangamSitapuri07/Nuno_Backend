import 'package:equatable/equatable.dart';

import 'enums.dart';
import 'json.dart';

/// GET /api/v1/profile  (src/users/user.service.ts → getProfile)
class PlayerProfile extends Equatable {
  final String id;
  final String username;
  final String email;
  final String? avatarUrl;
  final int level;
  final int xp;
  final int coins;
  final int rankPoints;
  final String accountStatus;
  final DateTime? createdAt;
  final DateTime? lastLogin;
  final PlayerStats? statistics;
  final PlayerRank? leaderboard;

  const PlayerProfile({
    required this.id,
    required this.username,
    required this.email,
    this.avatarUrl,
    this.level = 1,
    this.xp = 0,
    this.coins = 0,
    this.rankPoints = 0,
    this.accountStatus = 'ACTIVE',
    this.createdAt,
    this.lastLogin,
    this.statistics,
    this.leaderboard,
  });

  factory PlayerProfile.fromJson(Map<String, dynamic> json) => PlayerProfile(
        id: J.str(json['id']),
        username: J.str(json['username']),
        email: J.str(json['email']),
        avatarUrl: J.strOrNull(json['avatarUrl']),
        level: J.int_(json['level'], 1),
        xp: J.int_(json['xp']),
        coins: J.int_(json['coins']),
        rankPoints: J.int_(json['rankPoints']),
        accountStatus: J.str(json['accountStatus'], 'ACTIVE'),
        createdAt: J.date(json['createdAt']),
        lastLogin: J.date(json['lastLogin']),
        statistics: json['statistics'] == null
            ? null
            : PlayerStats.fromJson(J.map(json['statistics'])),
        leaderboard: json['leaderboard'] == null
            ? null
            : PlayerRank.fromJson(J.map(json['leaderboard'])),
      );

  PlayerProfile copyWith({
    String? username,
    String? avatarUrl,
    int? coins,
    int? xp,
    int? level,
  }) =>
      PlayerProfile(
        id: id,
        username: username ?? this.username,
        email: email,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        level: level ?? this.level,
        xp: xp ?? this.xp,
        coins: coins ?? this.coins,
        rankPoints: rankPoints,
        accountStatus: accountStatus,
        createdAt: createdAt,
        lastLogin: lastLogin,
        statistics: statistics,
        leaderboard: leaderboard,
      );

  /// XP floor of the current level.
  ///
  /// Derived from the next target so the two always bracket the current xp,
  /// even when the server reports a level and xp that disagree.
  int get levelFloorXp {
    final target = nextLevelXp;

    // Highest threshold strictly below the target...
    int floor = 0;
    for (final t in kLevelThresholds) {
      if (t < target) floor = t;
    }

    // ...but past the table the bands are 1000 wide.
    if (target > kLevelThresholds.last) floor = target - 1000;

    // Never let the floor sit above the player's xp, or the bar goes empty.
    return floor > xp ? (target - 1000).clamp(0, xp) : floor;
  }

  /// XP needed to reach the next level.
  ///
  /// The server may report xp beyond the level it also reports (levels are
  /// awarded on match end, xp can run ahead), so the result is always kept
  /// above the current xp rather than trusting the table blindly.
  int get nextLevelXp {
    int target;
    if (level >= kLevelThresholds.length) {
      target =
          kLevelThresholds.last + 1000 * (level - kLevelThresholds.length + 1);
    } else {
      target = kLevelThresholds[level.clamp(0, kLevelThresholds.length - 1)];
    }

    // Never show a target the player has already passed.
    if (target <= xp) {
      for (final t in kLevelThresholds) {
        if (t > xp) return t;
      }
      // Past the table: round up to the next 1000 above the floor.
      final over = xp - kLevelThresholds.last;
      return kLevelThresholds.last + ((over ~/ 1000) + 1) * 1000;
    }
    return target;
  }

  /// 0..1 progress through the current level.
  double get levelProgress {
    final span = nextLevelXp - levelFloorXp;
    if (span <= 0) return 1;
    return ((xp - levelFloorXp) / span).clamp(0.0, 1.0);
  }

  String get initials {
    if (username.isEmpty) return '?';
    return username.substring(0, 1).toUpperCase();
  }

  @override
  List<Object?> get props => [id, username, avatarUrl, level, xp, coins, rankPoints];
}

/// GET /api/v1/statistics
class PlayerStats extends Equatable {
  final int gamesPlayed;
  final int gamesWon;
  final int gamesLost;
  final double winRate;
  final int longestWinStreak;
  final int currentWinStreak;
  final int cardsPlayed;
  final int cardsDrawn;

  const PlayerStats({
    this.gamesPlayed = 0,
    this.gamesWon = 0,
    this.gamesLost = 0,
    this.winRate = 0,
    this.longestWinStreak = 0,
    this.currentWinStreak = 0,
    this.cardsPlayed = 0,
    this.cardsDrawn = 0,
  });

  factory PlayerStats.fromJson(Map<String, dynamic> json) => PlayerStats(
        gamesPlayed: J.int_(json['gamesPlayed']),
        gamesWon: J.int_(json['gamesWon']),
        gamesLost: J.int_(json['gamesLost']),
        winRate: J.dbl(json['winRate']),
        longestWinStreak: J.int_(json['longestWinStreak']),
        currentWinStreak: J.int_(json['currentWinStreak']),
        cardsPlayed: J.int_(json['cardsPlayed']),
        cardsDrawn: J.int_(json['cardsDrawn']),
      );

  /// Backend stores winRate as a 0-100 percentage.
  String get winRateLabel => '${winRate.toStringAsFixed(0)}%';

  @override
  List<Object?> get props =>
      [gamesPlayed, gamesWon, gamesLost, winRate, longestWinStreak, currentWinStreak];
}

/// Embedded `leaderboard` on the profile.
class PlayerRank extends Equatable {
  final int rating;
  final RankTier tier;
  final String division;
  final int season;
  final int? globalRank;

  const PlayerRank({
    this.rating = 1000,
    this.tier = RankTier.bronze,
    this.division = 'III',
    this.season = 1,
    this.globalRank,
  });

  /// Handles both the embedded shape and GET /leaderboard/rank
  /// (which adds `globalRank`).
  factory PlayerRank.fromJson(Map<String, dynamic> json) => PlayerRank(
        rating: J.int_(json['rating'], 1000),
        tier: RankTierX.parse(J.strOrNull(json['tier'])),
        division: J.str(json['division'], 'III'),
        season: J.int_(json['season'], 1),
        globalRank: json['globalRank'] == null ? null : J.int_(json['globalRank']),
      );

  String get label => '${tier.label} $division';

  @override
  List<Object?> get props => [rating, tier, division, season, globalRank];
}

/// GET /api/v1/settings  (Prisma PlayerSettings)
class PlayerSettings extends Equatable {
  final String language;
  final int musicVolume;
  final int soundVolume;
  final int voiceVolume;
  final bool pushToTalk;
  final bool notifications;
  final bool darkMode;

  const PlayerSettings({
    this.language = 'en',
    this.musicVolume = 80,
    this.soundVolume = 80,
    this.voiceVolume = 80,
    this.pushToTalk = false,
    this.notifications = true,
    this.darkMode = true,
  });

  factory PlayerSettings.fromJson(Map<String, dynamic> json) => PlayerSettings(
        language: J.str(json['language'], 'en'),
        musicVolume: J.int_(json['musicVolume'], 80),
        soundVolume: J.int_(json['soundVolume'], 80),
        voiceVolume: J.int_(json['voiceVolume'], 80),
        pushToTalk: J.bool_(json['pushToTalk']),
        notifications: J.bool_(json['notifications'], true),
        darkMode: J.bool_(json['darkMode'], true),
      );

  Map<String, dynamic> toJson() => {
        'language': language,
        'musicVolume': musicVolume,
        'soundVolume': soundVolume,
        'voiceVolume': voiceVolume,
        'pushToTalk': pushToTalk,
        'notifications': notifications,
        'darkMode': darkMode,
      };

  PlayerSettings copyWith({
    String? language,
    int? musicVolume,
    int? soundVolume,
    int? voiceVolume,
    bool? pushToTalk,
    bool? notifications,
    bool? darkMode,
  }) =>
      PlayerSettings(
        language: language ?? this.language,
        musicVolume: musicVolume ?? this.musicVolume,
        soundVolume: soundVolume ?? this.soundVolume,
        voiceVolume: voiceVolume ?? this.voiceVolume,
        pushToTalk: pushToTalk ?? this.pushToTalk,
        notifications: notifications ?? this.notifications,
        darkMode: darkMode ?? this.darkMode,
      );

  @override
  List<Object?> get props => [
        language, musicVolume, soundVolume, voiceVolume,
        pushToTalk, notifications, darkMode,
      ];
}

/// GET /api/v1/history entry
class MatchHistoryEntry extends Equatable {
  final String matchId;
  final GameMode gameMode;
  final int duration;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final bool isWinner;
  final int finalPosition;
  final int ratingChange;
  final int xpEarned;

  const MatchHistoryEntry({
    required this.matchId,
    required this.gameMode,
    this.duration = 0,
    this.startedAt,
    this.endedAt,
    this.isWinner = false,
    this.finalPosition = 0,
    this.ratingChange = 0,
    this.xpEarned = 0,
  });

  factory MatchHistoryEntry.fromJson(Map<String, dynamic> json) =>
      MatchHistoryEntry(
        matchId: J.str(json['matchId']),
        gameMode: GameModeX.parse(J.strOrNull(json['gameMode'])),
        duration: J.int_(json['duration']),
        startedAt: J.date(json['startedAt']),
        endedAt: J.date(json['endedAt']),
        isWinner: J.bool_(json['isWinner']),
        finalPosition: J.int_(json['finalPosition']),
        ratingChange: J.int_(json['ratingChange']),
        xpEarned: J.int_(json['xpEarned']),
      );

  String get durationLabel {
    final m = duration ~/ 60;
    final s = duration % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  @override
  List<Object?> get props => [matchId, isWinner, finalPosition, ratingChange];
}

/// GET /api/v1/notifications (Prisma Notification)
class AppNotification extends Equatable {
  final String id;
  final String title;
  final String message;
  final bool read;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    this.read = false,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: J.str(json['id']),
        title: J.str(json['title']),
        message: J.str(json['message']),
        read: J.bool_(json['read']),
        createdAt: J.date(json['createdAt']),
      );

  @override
  List<Object?> get props => [id, read];
}
