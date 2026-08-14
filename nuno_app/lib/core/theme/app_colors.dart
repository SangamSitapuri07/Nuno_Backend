import 'package:flutter/material.dart';

/// Colour tokens sampled from the landscape UI reference sheet.
///
/// Everything visual references these values, so re-skinning is a matter of
/// editing this one file.
class AppColors {
  AppColors._();

  // ── Surfaces ────────────────────────────────────────────────
  static const Color background = Color(0xFF0D0722);
  static const Color backgroundAlt = Color(0xFF150C33);
  static const Color surface = Color(0xFF1E1147);
  static const Color surfaceHigh = Color(0xFF2A1A5E);
  static const Color surfaceStroke = Color(0xFF422A7A);
  static const Color panelHeader = Color(0xFF190E3B);

  // ── Brand ───────────────────────────────────────────────────
  /// UNO red — logo, PLAY button, destructive actions.
  static const Color primary = Color(0xFFE01B24);
  static const Color primaryDark = Color(0xFF8B0F16);

  /// Gold — primary confirm CTAs (CREATE ROOM, START GAME, CLAIM).
  static const Color gold = Color(0xFFFFC93C);
  static const Color goldDark = Color(0xFFF7931E);

  static const Color blue = Color(0xFF3B82F6);
  static const Color green = Color(0xFF22C55E);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color cyan = Color(0xFF2DD4BF);

  /// Legacy alias kept so older widgets keep compiling.
  static const Color accent = green;

  // ── Text ────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFFDF7FF);
  static const Color textSecondary = Color(0xFFB4A5E0);
  static const Color textMuted = Color(0xFF7D6BAE);

  // ── Status ──────────────────────────────────────────────────
  static const Color success = Color(0xFF4CAF50);
  static const Color danger = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFA726);
  static const Color info = Color(0xFF2196F3);

  // ── Currency ────────────────────────────────────────────────
  static const Color coin = Color(0xFFFFC107);
  static const Color gem = Color(0xFF22D3EE);

  // ── Playing cards ───────────────────────────────────────────
  static const Color cardRed = Color(0xFFED1C24);
  static const Color cardBlue = Color(0xFF0072BC);
  static const Color cardGreen = Color(0xFF00A651);
  static const Color cardYellow = Color(0xFFFFDE00);
  static const Color cardWild = Color(0xFF1A1A2E);

  // ── Table glow (screens 7 & 8) ──────────────────────────────
  /// Opponent's turn — red ambience.
  static const Color tableGlowRed = Color(0xFF7F1418);

  /// Your turn — green ambience.
  static const Color tableGlowGreen = Color(0xFF12673A);

  static const Color tableBase = Color(0xFF11132C);

  // ── Category accents (reference legend) ─────────────────────
  static const Color catLobby = Color(0xFF3B82F6);
  static const Color catGameplay = Color(0xFF22C55E);
  static const Color catSocial = Color(0xFFE040FB);
  static const Color catProfile = Color(0xFFFF9800);
  static const Color catStore = Color(0xFFFFC107);
  static const Color catSystem = Color(0xFF9E9E9E);

  // ── Rarity ──────────────────────────────────────────────────
  static const Color rarityCommon = Color(0xFF9E9E9E);
  static const Color rarityRare = Color(0xFF2196F3);
  static const Color rarityEpic = Color(0xFFAB47BC);
  static const Color rarityLegendary = Color(0xFFFFA000);
  static const Color rarityMythic = Color(0xFFFF3D71);

  // ── Rank tiers ──────────────────────────────────────────────
  static const Color tierBronze = Color(0xFFCD7F32);
  static const Color tierSilver = Color(0xFFC0C0C0);
  static const Color tierGold = Color(0xFFFFD700);
  static const Color tierPlatinum = Color(0xFF7FFFD4);
  static const Color tierDiamond = Color(0xFF54D5FF);
  static const Color tierMaster = Color(0xFFB14BFF);
  static const Color tierGrandmaster = Color(0xFFFF4D6D);

  // ── Presence ────────────────────────────────────────────────
  static const Color statusOnline = green;
  static const Color statusInMatch = warning;
  static const Color statusInLobby = blue;
  static const Color statusAway = Color(0xFFB0A98F);
  static const Color statusOffline = Color(0xFF5A5578);
  static const Color statusDnd = danger;

  // ── Gradients ───────────────────────────────────────────────

  /// PLAY button — bright red into deep red.
  static const LinearGradient playGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF3B41), Color(0xFF9E1016)],
  );

  static const LinearGradient primaryGradient = playGradient;

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFE082), Color(0xFFFFC93C), Color(0xFFF7931E)],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient blueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
  );

  static const LinearGradient greenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF66BB6A), Color(0xFF2E7D32)],
  );

  static const LinearGradient violetGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFA78BFA), Color(0xFF6D28D9)],
  );

  static const LinearGradient dangerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF5A5F), Color(0xFFC62828)],
  );

  /// Legacy alias.
  static const LinearGradient accentGradient = greenGradient;

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF241155), Color(0xFF120730), Color(0xFF08040F)],
    stops: [0.0, 0.55, 1.0],
  );

  /// Radial ambience behind the game table; tinted by whose turn it is.
  static RadialGradient tableGradient(Color glow) => RadialGradient(
        center: Alignment.center,
        radius: 0.95,
        colors: [
          Color.lerp(glow, Colors.white, 0.06)!,
          glow,
          tableBase,
        ],
        stops: const [0.0, 0.45, 1.0],
      );

  /// Legacy alias used by the old game screen.
  static const RadialGradient feltGradient = RadialGradient(
    center: Alignment.center,
    radius: 0.9,
    colors: [Color(0xFF7F1418), Color(0xFF11132C)],
  );

  // ── Helpers ─────────────────────────────────────────────────

  static Color forCardColor(String color) => switch (color.toUpperCase()) {
        'RED' => cardRed,
        'BLUE' => cardBlue,
        'GREEN' => cardGreen,
        'YELLOW' => cardYellow,
        _ => cardWild,
      };

  static Color forRarity(String rarity) => switch (rarity.toUpperCase()) {
        'RARE' => rarityRare,
        'EPIC' => rarityEpic,
        'LEGENDARY' => rarityLegendary,
        'MYTHIC' => rarityMythic,
        _ => rarityCommon,
      };

  static Color forTier(String tier) => switch (tier.toUpperCase()) {
        'SILVER' => tierSilver,
        'GOLD' => tierGold,
        'PLATINUM' => tierPlatinum,
        'DIAMOND' => tierDiamond,
        'MASTER' => tierMaster,
        'GRANDMASTER' => tierGrandmaster,
        _ => tierBronze,
      };

  static Color forStatus(String status) => switch (status.toUpperCase()) {
        'ONLINE' => statusOnline,
        'IN_MATCH' => statusInMatch,
        'IN_LOBBY' => statusInLobby,
        'AWAY' => statusAway,
        'DO_NOT_DISTURB' => statusDnd,
        _ => statusOffline,
      };
}
