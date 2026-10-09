import 'package:flutter/material.dart';

/// Colours from the UI contract (spec 5.4). Add to the spec before adding here.
abstract final class HudyatColors {
  static const ground = Color(0xFFF2F1EC);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1B1B19);
  static const muted = Color(0xFF55534D);
  static const rule = Color(0xFFCFCCC2);
  static const disabledFill = Color(0xFFCFCCC2);
  static const disabledText = Color(0xFF3F3D39);

  /// Call buttons and the emergency link only.
  static const call = Color(0xFFB93A0B);

  /// "Mukhang scam", and the icon for medical help.
  static const danger = Color(0xFFA31621);

  /// "Mag-ingat". "Walang nakitang problema" has no colour of its own: it
  /// stays muted and is never green, which would read as "safe".
  static const caution = Color(0xFF8A5200);

  /// Icon colours that tell the kinds of help apart. Icons only; labels and
  /// borders stay ink.
  static const water = Color(0xFF1F5FA8);
  static const fire = Color(0xFFB85300);
  static const police = Color(0xFF1E2F6B);
  static const care = Color(0xFF0F6B63);
  static const shelter = Color(0xFF5B3A8C);
}

abstract final class HudyatText {
  static const family = 'AtkinsonHyperlegible';
  static const mono = 'IBMPlexMono';

  static const title = TextStyle(
    fontSize: 28,
    fontWeight: .w700,
    height: 1.15,
    color: HudyatColors.ink,
  );
  static const section = TextStyle(
    fontSize: 20,
    fontWeight: .w700,
    height: 1.2,
    color: HudyatColors.ink,
  );
  static const body = TextStyle(
    fontSize: 16,
    height: 1.4,
    color: HudyatColors.ink,
  );
  static const bodyBold = TextStyle(
    fontSize: 16,
    fontWeight: .w700,
    height: 1.3,
    color: HudyatColors.ink,
  );
  static const secondary = TextStyle(
    fontSize: 15,
    height: 1.4,
    color: HudyatColors.muted,
  );

  /// The Filipino line under an English heading or action.
  static const gloss = TextStyle(
    fontSize: 14,
    fontWeight: .w400,
    height: 1.3,
    color: HudyatColors.muted,
  );

  /// Numbers, addresses, badges and footers. 13 is the minimum size.
  static const data = TextStyle(
    fontFamily: mono,
    fontSize: 13,
    height: 1.5,
    color: HudyatColors.muted,
  );
  static const button = TextStyle(
    fontFamily: family,
    fontSize: 17,
    fontWeight: .w700,
  );
}

abstract final class HudyatShape {
  static const radius = BorderRadius.all(Radius.circular(6));
  static const badgeRadius = BorderRadius.all(Radius.circular(3));
  static const primaryBorder = BorderSide(color: HudyatColors.ink, width: 2);
  static const secondaryBorder = BorderSide(
    color: HudyatColors.ink,
    width: 1.5,
  );
  static const ruleBorder = BorderSide(color: HudyatColors.rule, width: 1.5);

  /// Page gutter.
  static const gutter = 20.0;
}

ThemeData hudyatTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: HudyatColors.ink,
    surface: HudyatColors.ground,
    onSurface: HudyatColors.ink,
    primary: HudyatColors.ink,
    onPrimary: HudyatColors.surface,
  );
  return ThemeData(
    colorScheme: scheme,
    fontFamily: HudyatText.family,
    scaffoldBackgroundColor: HudyatColors.ground,
    textTheme: const TextTheme(
      bodyMedium: HudyatText.body,
      bodyLarge: HudyatText.body,
      titleLarge: HudyatText.title,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: HudyatColors.surface,
      foregroundColor: HudyatColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 0,
      shape: Border(bottom: HudyatShape.primaryBorder),
      titleTextStyle: TextStyle(
        fontFamily: HudyatText.family,
        fontSize: 18,
        fontWeight: .w700,
        color: HudyatColors.ink,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: HudyatColors.surface,
      contentPadding: EdgeInsets.all(12),
      hintStyle: TextStyle(color: HudyatColors.muted, fontSize: 16),
      border: OutlineInputBorder(
        borderRadius: HudyatShape.radius,
        borderSide: HudyatShape.primaryBorder,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: HudyatShape.radius,
        borderSide: HudyatShape.primaryBorder,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: HudyatShape.radius,
        borderSide: BorderSide(color: HudyatColors.ink, width: 3),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: HudyatColors.ink,
    ),
  );
}
