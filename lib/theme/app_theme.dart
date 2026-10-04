import 'package:flutter/material.dart';

/// Zentrale Farbpalette der App. Ruhig, hochwertig und mit einer dezenten
/// theologischen Anmutung (tiefes Blau als Hauptfarbe, gedecktes Gold als
/// Akzent).
///
/// Die Palette ist eine [ThemeExtension]: Jedes Theme bringt seine eigene
/// Ausprägung mit, Widgets lesen sie über `context.colors` und reagieren
/// damit automatisch auf einen Theme-Wechsel. Widgets fragen deshalb nie ab,
/// ob gerade ein dunkles Theme aktiv ist, sondern verwenden die semantische
/// Farbe (z. B. `context.colors.success`).
///
/// Ein weiteres Theme (z. B. Sepia oder hoher Kontrast) entsteht, indem hier
/// eine weitere Palette definiert und in [AppTheme] daraus per
/// [AppTheme.fromColors] ein `ThemeData` gebaut wird.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color primary;
  final Color primaryLight;
  final Color onPrimary;

  final Color accent;
  final Color onAccent;

  final Color background;
  final Color surface;
  final Color surfaceMuted;

  final Color textPrimary;
  final Color textSecondary;

  final Color divider;

  /// „Richtig“ bzw. Erfolg: [success] für Text, Icons und gefüllte Flächen,
  /// [onSuccess] für Inhalte auf einer [success]-Fläche und
  /// [successBackground] als dezente Hinterlegung.
  final Color success;
  final Color onSuccess;
  final Color successBackground;

  /// „Falsch“ bzw. Fehler, aufgebaut wie die Erfolgsfarben.
  final Color error;
  final Color onError;
  final Color errorBackground;

  /// Gesperrte gefüllte Buttons.
  final Color disabled;
  final Color onDisabled;

  /// Fläche mit umgekehrtem Kontrast, z. B. für Snackbars.
  final Color inverseSurface;
  final Color onInverseSurface;

  const AppColors({
    required this.primary,
    required this.primaryLight,
    required this.onPrimary,
    required this.accent,
    required this.onAccent,
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.success,
    required this.onSuccess,
    required this.successBackground,
    required this.error,
    required this.onError,
    required this.errorBackground,
    required this.disabled,
    required this.onDisabled,
    required this.inverseSurface,
    required this.onInverseSurface,
  });

  static const AppColors light = AppColors(
    primary: Color(0xFF3B4C6B),
    primaryLight: Color(0xFF5A6E92),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFFAE8A4E),
    onAccent: Color(0xFFFFFFFF),
    background: Color(0xFFFAF7F1),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF1ECE2),
    textPrimary: Color(0xFF2B2B2E),
    textSecondary: Color(0xFF6B6A6E),
    divider: Color(0xFFE3DDD0),
    success: Color(0xFF3F7D58),
    onSuccess: Color(0xFFFFFFFF),
    successBackground: Color(0xFFE7F1EA),
    error: Color(0xFFB3402E),
    onError: Color(0xFFFFFFFF),
    errorBackground: Color(0xFFFBEAE6),
    disabled: Color(0x593B4C6B),
    onDisabled: Color(0xCCFFFFFF),
    inverseSurface: Color(0xFF2A3A54),
    onInverseSurface: Color(0xFFFFFFFF),
  );

  static const AppColors dark = AppColors(
    primary: Color(0xFFA9BBDD),
    primaryLight: Color(0xFF7F93BA),
    onPrimary: Color(0xFF16233A),
    accent: Color(0xFFD6B67E),
    onAccent: Color(0xFF2E2210),
    background: Color(0xFF15181D),
    surface: Color(0xFF1E2229),
    surfaceMuted: Color(0xFF2A2F38),
    textPrimary: Color(0xFFECE8E1),
    textSecondary: Color(0xFFABABB2),
    divider: Color(0xFF454C58),
    success: Color(0xFF82C99C),
    onSuccess: Color(0xFF0F2A1A),
    successBackground: Color(0xFF1D3527),
    error: Color(0xFFF2998A),
    onError: Color(0xFF40120B),
    errorBackground: Color(0xFF45231D),
    disabled: Color(0xFF343A45),
    onDisabled: Color(0xFF9A9BA3),
    inverseSurface: Color(0xFFE8E4DC),
    onInverseSurface: Color(0xFF2B2B2E),
  );

  /// Die Palette des aktiven Themes.
  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? light;

  @override
  AppColors copyWith({
    Color? primary,
    Color? primaryLight,
    Color? onPrimary,
    Color? accent,
    Color? onAccent,
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? textPrimary,
    Color? textSecondary,
    Color? divider,
    Color? success,
    Color? onSuccess,
    Color? successBackground,
    Color? error,
    Color? onError,
    Color? errorBackground,
    Color? disabled,
    Color? onDisabled,
    Color? inverseSurface,
    Color? onInverseSurface,
  }) {
    return AppColors(
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      onPrimary: onPrimary ?? this.onPrimary,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      divider: divider ?? this.divider,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successBackground: successBackground ?? this.successBackground,
      error: error ?? this.error,
      onError: onError ?? this.onError,
      errorBackground: errorBackground ?? this.errorBackground,
      disabled: disabled ?? this.disabled,
      onDisabled: onDisabled ?? this.onDisabled,
      inverseSurface: inverseSurface ?? this.inverseSurface,
      onInverseSurface: onInverseSurface ?? this.onInverseSurface,
    );
  }

  /// Blendet beim animierten Theme-Wechsel zwischen zwei Paletten über.
  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;

    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;

    return AppColors(
      primary: mix(primary, other.primary),
      primaryLight: mix(primaryLight, other.primaryLight),
      onPrimary: mix(onPrimary, other.onPrimary),
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      surfaceMuted: mix(surfaceMuted, other.surfaceMuted),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      divider: mix(divider, other.divider),
      success: mix(success, other.success),
      onSuccess: mix(onSuccess, other.onSuccess),
      successBackground: mix(successBackground, other.successBackground),
      error: mix(error, other.error),
      onError: mix(onError, other.onError),
      errorBackground: mix(errorBackground, other.errorBackground),
      disabled: mix(disabled, other.disabled),
      onDisabled: mix(onDisabled, other.onDisabled),
      inverseSurface: mix(inverseSurface, other.inverseSurface),
      onInverseSurface: mix(onInverseSurface, other.onInverseSurface),
    );
  }
}

/// Kurzform für den Zugriff auf die Palette des aktiven Themes.
extension AppColorsContext on BuildContext {
  AppColors get colors => AppColors.of(this);
}

/// Zentrales App-Theme. Alle Screens beziehen Farben, Formen und Textstile
/// von hier, damit spätere Design-Anpassungen an einer Stelle erfolgen
/// können statt über viele Dateien verteilt zu sein.
///
/// Welches Theme aktiv ist, legt `ThemeSettings` fest (Auswahl in den
/// allgemeinen Einstellungen); `MyApp` reicht [light] und [dark] an die
/// `MaterialApp` weiter.
class AppTheme {
  AppTheme._();

  static const double radius = 16;
  static const double radiusSmall = 10;

  static final ThemeData light = fromColors(AppColors.light, Brightness.light);

  static final ThemeData dark = fromColors(AppColors.dark, Brightness.dark);

  /// Baut aus einer Palette das vollständige Theme. Sämtliche
  /// Komponenten-Themes leiten ihre Farben aus [colors] ab, sodass eine
  /// neue Palette genügt, um ein weiteres Theme zu erhalten.
  static ThemeData fromColors(AppColors colors, Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: colors.primary,
      brightness: brightness,
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      secondary: colors.accent,
      onSecondary: colors.onAccent,
      error: colors.error,
      onError: colors.onError,
      surface: colors.surface,
      onSurface: colors.textPrimary,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: colorScheme);

    final textTheme = base.textTheme
        .copyWith(
          headlineSmall: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
          titleLarge: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
          titleMedium: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
          titleSmall: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
          bodyLarge: const TextStyle(fontSize: 16, height: 1.5),
          bodyMedium: const TextStyle(fontSize: 14.5, height: 1.5),
          labelLarge: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        )
        .apply(bodyColor: colors.textPrimary, displayColor: colors.textPrimary);

    final outlineBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusSmall),
      borderSide: BorderSide(color: colors.divider),
    );

    return base.copyWith(
      extensions: [colors],
      scaffoldBackgroundColor: colors.background,
      textTheme: textTheme,
      dividerColor: colors.divider,
      splashFactory: InkRipple.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
        ),
        iconTheme: IconThemeData(color: colors.primary),
      ),

      iconTheme: IconThemeData(color: colors.primary, size: 22),

      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: colors.divider),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      dividerTheme: DividerThemeData(
        color: colors.divider,
        thickness: 1,
        space: 32,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          disabledBackgroundColor: colors.disabled,
          disabledForegroundColor: colors.onDisabled,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          textStyle: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          side: BorderSide(color: colors.primary, width: 1.3),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: colors.primary),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: outlineBorder,
        enabledBorder: outlineBorder,
        disabledBorder: outlineBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide(color: colors.error, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide(color: colors.error, width: 2),
        ),
        labelStyle: TextStyle(color: colors.textSecondary),
        hintStyle: TextStyle(color: colors.textSecondary),
      ),

      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.divider;
          }
          if (states.contains(WidgetState.selected)) {
            return colors.primary;
          }
          return Colors.transparent;
        }),
        side: BorderSide(color: colors.textSecondary, width: 1.4),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? colors.primary : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.primary.withValues(alpha: 0.4)
              : null,
        ),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: colors.primary,
        inactiveTrackColor: colors.divider,
        thumbColor: colors.primary,
        overlayColor: colors.primary.withValues(alpha: 0.12),
        valueIndicatorColor: colors.inverseSurface,
        valueIndicatorTextStyle: TextStyle(color: colors.onInverseSurface),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
        ),
        contentTextStyle: TextStyle(
          fontSize: 14.5,
          color: colors.textPrimary,
          height: 1.4,
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: colors.primary,
        textColor: colors.textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
      ),

      expansionTileTheme: ExpansionTileThemeData(
        iconColor: colors.primary,
        collapsedIconColor: colors.textSecondary,
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.inverseSurface,
        contentTextStyle: TextStyle(color: colors.onInverseSurface),
        actionTextColor: colors.onInverseSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.primary),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }
}
