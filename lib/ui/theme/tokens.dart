import 'package:flutter/material.dart';

/// Material 3 Expressive design tokens.
///
/// Values are lifted verbatim from `email-client-visual-mockups.html` so the
/// app and the mockups agree. Color roles follow M3 naming; the seed is indigo.
abstract final class AppColors {
  static const ColorScheme light = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF4653D0),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFDFE0FF),
    onPrimaryContainer: Color(0xFF0B1A7A),
    secondary: Color(0xFF5B5D72),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE0E1F9),
    onSecondaryContainer: Color(0xFF181A2C),
    tertiary: Color(0xFF77536D),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFFFD7F1),
    onTertiaryContainer: Color(0xFF2D1228),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: Color(0xFFFBF8FF),
    onSurface: Color(0xFF1B1B21),
    surfaceDim: Color(0xFFDBD9E0),
    surfaceBright: Color(0xFFFBF8FF),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF5F2FA),
    surfaceContainer: Color(0xFFEFEDF4),
    surfaceContainerHigh: Color(0xFFE9E7EF),
    surfaceContainerHighest: Color(0xFFE3E1E9),
    onSurfaceVariant: Color(0xFF46464F),
    outline: Color(0xFF777680),
    outlineVariant: Color(0xFFC7C5D0),
    inverseSurface: Color(0xFF303036),
    onInverseSurface: Color(0xFFF2EFF7),
    inversePrimary: Color(0xFFBDC2FF),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  static const ColorScheme dark = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFBDC2FF),
    onPrimary: Color(0xFF0B1E9A),
    primaryContainer: Color(0xFF2C3AB6),
    onPrimaryContainer: Color(0xFFDFE0FF),
    secondary: Color(0xFFC4C5DD),
    onSecondary: Color(0xFF2D2F42),
    secondaryContainer: Color(0xFF43455A),
    onSecondaryContainer: Color(0xFFE0E1F9),
    tertiary: Color(0xFFE6BAD7),
    onTertiary: Color(0xFF44263D),
    tertiaryContainer: Color(0xFF5C3B54),
    onTertiaryContainer: Color(0xFFFFD7F1),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF131318),
    onSurface: Color(0xFFE4E1E9),
    surfaceDim: Color(0xFF131318),
    surfaceBright: Color(0xFF39393F),
    surfaceContainerLowest: Color(0xFF0E0E13),
    surfaceContainerLow: Color(0xFF1B1B21),
    surfaceContainer: Color(0xFF1F1F25),
    surfaceContainerHigh: Color(0xFF2A292F),
    surfaceContainerHighest: Color(0xFF35343A),
    onSurfaceVariant: Color(0xFFC7C5D0),
    outline: Color(0xFF918F9A),
    outlineVariant: Color(0xFF46464F),
    inverseSurface: Color(0xFFE4E1E9),
    onInverseSurface: Color(0xFF303036),
    inversePrimary: Color(0xFF4653D0),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );
}

/// A background/foreground pair for a tonal avatar.
class AvatarTone {
  const AvatarTone(this.background, this.foreground);
  final Color background;
  final Color foreground;
}

/// Eight deterministic tonal pairs for contact avatars (spec 5.1).
abstract final class AvatarTones {
  static const List<AvatarTone> light = [
    AvatarTone(Color(0xFFDFE0FF), Color(0xFF0B1A7A)),
    AvatarTone(Color(0xFFBFEFD0), Color(0xFF003920)),
    AvatarTone(Color(0xFFF0DBFF), Color(0xFF3A0A5C)),
    AvatarTone(Color(0xFFFFDBD1), Color(0xFF5A1600)),
    AvatarTone(Color(0xFFBEEFF4), Color(0xFF00373B)),
    AvatarTone(Color(0xFFFFE59A), Color(0xFF3F2E00)),
    AvatarTone(Color(0xFFFFD8E6), Color(0xFF5C0F33)),
    AvatarTone(Color(0xFFE3E1E9), Color(0xFF1B1B21)),
  ];

  static const List<AvatarTone> dark = [
    AvatarTone(Color(0xFF2C3AB6), Color(0xFFDFE0FF)),
    AvatarTone(Color(0xFF0F5132), Color(0xFFBFEFD0)),
    AvatarTone(Color(0xFF5A2C7A), Color(0xFFF0DBFF)),
    AvatarTone(Color(0xFF7A2E14), Color(0xFFFFDBD1)),
    AvatarTone(Color(0xFF0F4F55), Color(0xFFBEEFF4)),
    AvatarTone(Color(0xFF5E4A00), Color(0xFFFFE59A)),
    AvatarTone(Color(0xFF7A2A4E), Color(0xFFFFD8E6)),
    AvatarTone(Color(0xFF46464F), Color(0xFFE4E1E9)),
  ];

  /// Stable index for a contact key (email address or contact id).
  /// FNV-1a over the lower-cased key so the same contact always gets the
  /// same tone across sessions and devices.
  static int indexFor(String key) {
    var hash = 0x811C9DC5;
    for (final unit in key.toLowerCase().codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash % light.length;
  }

  static AvatarTone forKey(String key, Brightness brightness) {
    final tones = brightness == Brightness.dark ? dark : light;
    return tones[indexFor(key)];
  }
}

/// M3 Expressive shape scale (spec 5.1).
abstract final class AppShapes {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double lgIncreased = 20;
  static const double xl = 28;
  static const double xlIncreased = 32;
  static const double xxl = 48;
  static const double full = 9999;

  static BorderRadius radius(double r) => BorderRadius.circular(r);
}

/// Spacing scale in logical pixels (dp).
abstract final class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Layout constants for the desktop shell (spec 5.3).
abstract final class AppLayout {
  static const double railWidth = 88;
  static const double middlePaneMin = 300;
  static const double middlePaneDefault = 340;
  static const double middlePaneMax = 480;
  static const double rightPaneMin = 420;
  static const Size minWindowSize = Size(960, 640);
  static const double collapseRailBelow = 1100;
}
