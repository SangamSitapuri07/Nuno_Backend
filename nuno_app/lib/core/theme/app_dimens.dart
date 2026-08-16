import 'package:flutter/material.dart';

/// Spacing, radius, elevation and sizing tokens.
class AppDimens {
  AppDimens._();

  // Spacing scale (4pt base)
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;

  // Radii
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusXxl = 28;
  static const double radiusPill = 999;

  static const BorderRadius brSm = BorderRadius.all(Radius.circular(radiusSm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(radiusMd));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(radiusLg));
  static const BorderRadius brXl = BorderRadius.all(Radius.circular(radiusXl));
  static const BorderRadius brXxl =
      BorderRadius.all(Radius.circular(radiusXxl));
  static const BorderRadius brPill =
      BorderRadius.all(Radius.circular(radiusPill));

  // Screen padding (landscape keeps vertical space tight)
  static const EdgeInsets screenPadding =
      EdgeInsets.symmetric(horizontal: xl, vertical: md);

  // Component sizes
  static const double buttonHeight = 46;
  static const double inputHeight = 56;
  static const double appBarHeight = 52;
  static const double bottomNavHeight = 60;
  static const double panelHeaderHeight = 34;
  static const double avatarSm = 32;
  static const double avatarMd = 44;
  static const double avatarLg = 64;
  static const double avatarXl = 96;

  // Playing card geometry (aspect ratio 2:3)
  static const double cardAspectRatio = 0.68;

  // Landscape: the hand sits in a short strip, so cards are compact.
  //
  // A card is ~1.47x its width tall, so these dominate the vertical space on
  // a phone in landscape. Trimmed so a full hand and the table both fit
  // without the hand crowding the play area.
  static const double handCardWidth = 62;
  static const double handCardHeight = handCardWidth / cardAspectRatio;
  static const double tableCardWidth = 68;
  static const double tableCardHeight = tableCardWidth / cardAspectRatio;
  static const double opponentCardWidth = 22;
  static const double miniCardWidth = 22;
}
