import 'package:flutter/material.dart';

import 'tokens.dart';

/// Builds the Material 3 Expressive [ThemeData] for the app (spec 5.1, 5.4).
///
/// Windows uses Segoe UI Variable (decision 19). The font family list falls
/// back to Segoe UI, then the platform default, so nothing is fetched.
abstract final class AppTheme {
  static const List<String> _fontFallback = ['Segoe UI', 'Roboto', 'sans-serif'];
  static const String fontFamily = 'Segoe UI Variable Text';

  static ThemeData light() => _build(AppColors.light);
  static ThemeData dark() => _build(AppColors.dark);

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: scheme.brightness,
      fontFamily: fontFamily,
      fontFamilyFallback: _fontFallback,
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
    );

    final text = _typography(base.textTheme, scheme);

    return base.copyWith(
      textTheme: text,
      // ---- Navigation rail: pill indicator, filled icon when selected ----
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        indicatorShape: const StadiumBorder(),
        selectedIconTheme: IconThemeData(color: scheme.onSecondaryContainer, size: 24),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 24),
        selectedLabelTextStyle: text.labelMedium!.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: text.labelMedium!.copyWith(color: scheme.onSurfaceVariant),
        labelType: NavigationRailLabelType.all,
        groupAlignment: -1,
        useIndicator: true,
        minWidth: AppLayout.railWidth,
      ),
      // ---- FAB: primary, 16dp corners ----
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 3,
        highlightElevation: 6,
        shape: RoundedRectangleBorder(borderRadius: AppShapes.radius(AppShapes.lg)),
        extendedTextStyle: text.labelLarge!.copyWith(fontWeight: FontWeight.w600),
      ),
      // ---- Chips: 8dp corners, secondary-container when selected ----
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppShapes.radius(AppShapes.sm)),
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: Colors.transparent,
        selectedColor: scheme.secondaryContainer,
        checkmarkColor: scheme.onSecondaryContainer,
        labelStyle: text.labelLarge!.copyWith(color: scheme.onSurfaceVariant),
        secondaryLabelStyle: text.labelLarge!.copyWith(color: scheme.onSecondaryContainer),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        showCheckmark: true,
      ),
      // ---- Cards: tonal, no shadow, 20dp ----
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppShapes.radius(AppShapes.lgIncreased)),
      ),
      // ---- Search bar: 48dp pill in surface-container-high ----
      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
        elevation: const WidgetStatePropertyAll(0),
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        constraints: const BoxConstraints(minHeight: 48, maxHeight: 48),
        hintStyle: WidgetStatePropertyAll(text.bodyLarge!.copyWith(color: scheme.onSurfaceVariant)),
        textStyle: WidgetStatePropertyAll(text.bodyLarge),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
      ),
      // ---- Switch: 52x32 with check on the thumb when on ----
      switchTheme: SwitchThemeData(
        thumbIcon: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? const Icon(Icons.check_rounded, size: 16) : null,
        ),
      ),
      // ---- Text fields: filled ----
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: UnderlineInputBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppShapes.xs)),
          borderSide: BorderSide(color: scheme.onSurfaceVariant),
        ),
        enabledBorder: UnderlineInputBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppShapes.xs)),
          borderSide: BorderSide(color: scheme.onSurfaceVariant),
        ),
        focusedBorder: UnderlineInputBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppShapes.xs)),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        labelStyle: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant),
        floatingLabelStyle: text.bodySmall!.copyWith(color: scheme.primary),
      ),
      // ---- Buttons ----
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          textStyle: text.labelLarge!.copyWith(fontWeight: FontWeight.w600),
          minimumSize: const Size(0, 40),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const StadiumBorder(),
          textStyle: text.labelLarge!.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppShapes.radius(AppShapes.xs)),
        tileColor: scheme.surfaceContainerLowest,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: AppShapes.radius(AppShapes.sm),
        ),
        textStyle: text.bodySmall!.copyWith(color: scheme.onInverseSurface),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: AppShapes.radius(AppShapes.md)),
        elevation: 2,
      ),
    );
  }

  /// M3 type scale with Expressive emphasis on headlines (spec 5.1).
  static TextTheme _typography(TextTheme t, ColorScheme scheme) {
    final onSurface = scheme.onSurface;
    return t.copyWith(
      displaySmall: t.displaySmall!.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5, color: onSurface),
      headlineLarge: t.headlineLarge!.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.6, color: onSurface),
      headlineMedium: t.headlineMedium!.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.15, color: onSurface),
      headlineSmall: t.headlineSmall!.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3, color: onSurface),
      titleLarge: t.titleLarge!.copyWith(fontWeight: FontWeight.w600, color: onSurface),
      titleMedium: t.titleMedium!.copyWith(fontWeight: FontWeight.w500, color: onSurface),
      titleSmall: t.titleSmall!.copyWith(fontWeight: FontWeight.w600, color: onSurface),
      bodyLarge: t.bodyLarge!.copyWith(color: onSurface),
      bodyMedium: t.bodyMedium!.copyWith(color: onSurface),
      bodySmall: t.bodySmall!.copyWith(color: scheme.onSurfaceVariant),
      labelLarge: t.labelLarge!.copyWith(fontWeight: FontWeight.w500, color: onSurface),
      labelMedium: t.labelMedium!.copyWith(fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant),
      labelSmall: t.labelSmall!.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.8, color: scheme.onSurfaceVariant),
    );
  }
}
