import 'package:flutter/material.dart';

/// Central colour tokens for the whole app.
///
/// Everything visual references these values, so re-skinning the app to match
/// a design reference is a matter of editing this one file.
class AppColors {
  AppColors._();

  // ── Surfaces ────────────────────────────────────────────────
  static const Color background = Color(0xFF0B0A1F);
  static const Color backgroundAlt = Color(0xFF12102B);
  static const Color surface = Color(0xFF1A1836);
  static const Color surfaceHigh = Color(0xFF232048);
  static const Color surfaceStroke = Color(0xFF2E2A57);

  // ── Brand ───────────────────────────────────────────────────
  static const Color primary = Color(0xFF7C4DFF);
  static const Color primaryDark = Color(0xFF5B32D6);
  static const Color accent = Color(0xFF00E5C0);
  static const Color gold = Color(0xFFFFC542);

  // ── Text ────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF5F4FF);
  static const Color textSecondary = Color(0xFFA9A4CC);
  static const Color textMuted = Color(0xFF6F6A94);

  // ── Status ──────────────────────────────────────────────────
  static const Color success = Color(0xFF2ED573);
  static const Color danger = Color(0xFFFF4757);
  static const Color warning = Color(0xFFFFA502);
  static const Color info = Color(0xFF2E9BFF);

  // ── Card colours (match backend CardColor enum) ─────────────
  static const Color cardRed = Color(0xFFED2939);
  static const Color cardBlue = Color(0xFF1E7BE0);
  static const Color cardGreen = Color(0xFF34C759);
  static const Color cardYellow = Color(0xFFFFC300);
  static const Color cardWild = Color(0xFF2B2B3D);

  // ── Rarity (match backend ItemRarity enum) ──────────────────
  static const Color rarityCommon = Color(0xFF9E9E9E);
  static const Color rarityRare = Color(0xFF2E9BFF);
  static const Color rarityEpic = Color(0xFFAB47BC);
  static const Color rarityLegendary = Color(0xFFFFA000);
  static const Color rarityMythic = Color(0xFFFF3D71);

  // ── Rank tiers (match backend RankTier enum) ────────────────
  static const Color tierBronze = Color(0xFFCD7F32);
  static const Color tierSilver = Color(0xFFC0C0C0);
  static const Color tierGold = Color(0xFFFFD700);
  static const Color tierPlatinum = Color(0xFF7FFFD4);
  static const Color tierDiamond = Color(0xFF54D5FF);
  static const Color tierMaster = Color(0xFFB14BFF);
  static const Color tierGrandmaster = Color(0xFFFF4D6D);

  // ── Presence (match backend PlayerOnlineStatus enum) ────────
  static const Color statusOnline = success;
  static const Color statusInMatch = warning;
  static const Color statusInLobby = info;
  static const Color statusAway = Color(0xFFB0A98F);
  static const Color statusOffline = Color(0xFF5A5578);
  static const Color statusDnd = danger;

  // ── Gradients ───────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8C5CFF), Color(0xFF5B32D6)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00E5C0), Color(0xFF00A9B5)],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFD979), Color(0xFFFFA800)],
  );

  static const LinearGradient dangerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF6B7A), Color(0xFFE01E37)],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF16123A), Color(0xFF0B0A1F)],
  );

  /// Radial felt used behind the game table.
  static const RadialGradient feltGradient = RadialGradient(
    center: Alignment.center,
    radius: 0.9,
    colors: [Color(0xFF255F4C), Color(0xFF0D2A22)],
  );

  // ── Helpers ─────────────────────────────────────────────────

  static Color forCardColor(String color) {
    switch (color.toUpperCase()) {
      case 'RED':
        return cardRed;
      case 'BLUE':
        return cardBlue;
      case 'GREEN':
        return cardGreen;
      case 'YELLOW':
        return cardYellow;
      default:
        return cardWild;
    }
  }

  static Color forRarity(String rarity) {
    switch (rarity.toUpperCase()) {
      case 'RARE':
        return rarityRare;
      case 'EPIC':
        return rarityEpic;
      case 'LEGENDARY':
        return rarityLegendary;
      case 'MYTHIC':
        return rarityMythic;
      default:
        return rarityCommon;
    }
  }

  static Color forTier(String tier) {
    switch (tier.toUpperCase()) {
      case 'SILVER':
        return tierSilver;
      case 'GOLD':
        return tierGold;
      case 'PLATINUM':
        return tierPlatinum;
      case 'DIAMOND':
        return tierDiamond;
      case 'MASTER':
        return tierMaster;
      case 'GRANDMASTER':
        return tierGrandmaster;
      default:
        return tierBronze;
    }
  }

  static Color forStatus(String status) {
    switch (status.toUpperCase()) {
      case 'ONLINE':
        return statusOnline;
      case 'IN_MATCH':
        return statusInMatch;
      case 'IN_LOBBY':
        return statusInLobby;
      case 'AWAY':
        return statusAway;
      case 'DO_NOT_DISTURB':
        return statusDnd;
      default:
        return statusOffline;
    }
  }
}
