import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

enum UiThemeStyle {
  dark,
  light;

  // Backward compatibility aliases
  static const UiThemeStyle ghostInTheShell = dark;
  static const UiThemeStyle tacticalFlame = dark;
  static const UiThemeStyle braunDieterRams = dark;
  static const UiThemeStyle stoicRoyalty = dark;
}

class AppTheme {
  // Active theme style (defaults to Dark Obsidian)
  static UiThemeStyle currentStyle = UiThemeStyle.dark;

  static bool get isDark => currentStyle == UiThemeStyle.dark;
  static bool get isLight => currentStyle == UiThemeStyle.light;

  // Backward compatibility getters
  static bool get isGhost => false;
  static bool get isTactical => false;
  static bool get isBraun => false;
  static bool get isStoic => false;

  // ==========================================
  // DUAL-THEME COLOR SYSTEM
  // ==========================================

  // 1. Structural Surfaces
  static Color get bgBase => isDark ? const Color(0xFF0D0E10) : const Color(0xFFF5F2EB);
  static Color get bgCard => isDark ? const Color(0xFF161719) : const Color(0xFFEBE7DE);
  static Color get bgPanel => isDark ? const Color(0xFF1C1E22) : const Color(0xFFE2DDD2);
  static Color get bgPanelHover => isDark ? const Color(0xFF24272D) : const Color(0xFFDAD4C7);
  static Color get surfaceVoid => bgBase;
  static Color get surfaceDeck => bgCard;
  static Color get surfaceRecessed => bgPanel;
  static Color get surfaceRaised => bgPanelHover;
  static Color get surfaceOverlay => isDark ? const Color(0xFF1E2126) : const Color(0xFFDDD7CB);

  // 2. Borders & Seams
  static Color get borderSubtle => isDark ? const Color(0x1FFFFFFF) : const Color(0x14000000);
  static Color get borderHighlight => isDark ? const Color(0x50E5B887) : const Color(0x40C68E54);
  static Color get hairlineSeam => isDark ? const Color(0x14FFFFFF) : const Color(0x0F000000);

  // 3. Text Tiers
  static Color get textPrimary => isDark ? const Color(0xFFE8E6DF) : const Color(0xFF1A1C1D);
  static Color get textSecondary => isDark ? const Color(0xFFA2A49F) : const Color(0xFF6B6D68);
  static Color get textMuted => isDark ? const Color(0xFF686966) : const Color(0xFF969892);
  static Color get textBright => textPrimary;

  // 4. Distinctive Accent Colors
  // Sand / Butterscotch Amber
  static Color get accentPrimary => isDark ? const Color(0xFFE5B887) : const Color(0xFFC68E54);
  static Color get orangeFlame => accentPrimary;
  static Color get orangeGlow => accentPrimary.withOpacity(0.18);
  static Color get amberWarm => accentPrimary;
  static Color get goldAmber => accentPrimary;
  static Color get warningGold => accentPrimary;
  static Color get amberTachikoma => accentPrimary;

  // Scandinavian Muted Sage / Deep Forest Olive
  static Color get accentSage => isDark ? const Color(0xFF6E8B7E) : const Color(0xFF3E5C4E);
  static Color get emeraldLive => accentSage;
  static Color get emeraldGreen => accentSage;

  // Telemetry Accent (harmonized with Sage & Sand)
  static Color get cyanTelemetry => isDark ? const Color(0xFF86A597) : const Color(0xFF436555);

  // Status & System Accents
  static Color get dangerCrimson => isDark ? const Color(0xFFE05353) : const Color(0xFFC93B3B);
  static Color get neuralPurple => isDark ? const Color(0xFFBD93F9) : const Color(0xFF7E57C2);

  // High contrast text/icon color for elements on top of accentPrimary
  static Color get onPrimaryAccent => isDark ? const Color(0xFF111214) : const Color(0xFFF5F2EB);

  // Backward-compatible surface alias
  static Color get bgSurface => bgPanel;

  // ==========================================
  // TYPOGRAPHY SYSTEM
  // 1. Fraunces (Display / Editorial)
  // 2. Manrope (UI / Body)
  // 3. IBM Plex Mono (Data / Technical)
  // ==========================================

  // Optional headless / test fallback to system fonts
  static bool useSystemFonts = false;

  // --- 1. DISPLAY / EDITORIAL: Fraunces ---
  static TextStyle editorialDisplayLarge({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
  }) {
    if (useSystemFonts) {
      return TextStyle(
        fontFamily: 'serif',
        color: color ?? textPrimary,
        fontSize: fontSize ?? 52,
        fontWeight: fontWeight ?? FontWeight.w400,
        fontStyle: fontStyle ?? FontStyle.normal,
        letterSpacing: letterSpacing ?? -0.5,
        height: height ?? 1.1,
      );
    }
    return GoogleFonts.fraunces(
      color: color ?? textPrimary,
      fontSize: fontSize ?? 52,
      fontWeight: fontWeight ?? FontWeight.w400,
      fontStyle: fontStyle ?? FontStyle.normal,
      letterSpacing: letterSpacing ?? -0.5,
      height: height ?? 1.1,
    );
  }

  static TextStyle editorialTitle({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
  }) {
    if (useSystemFonts) {
      return TextStyle(
        fontFamily: 'serif',
        color: color ?? textPrimary,
        fontSize: fontSize ?? 24,
        fontWeight: fontWeight ?? FontWeight.w500,
        fontStyle: fontStyle ?? FontStyle.normal,
        letterSpacing: letterSpacing ?? -0.3,
        height: height ?? 1.2,
      );
    }
    return GoogleFonts.fraunces(
      color: color ?? textPrimary,
      fontSize: fontSize ?? 24,
      fontWeight: fontWeight ?? FontWeight.w500,
      fontStyle: fontStyle ?? FontStyle.normal,
      letterSpacing: letterSpacing ?? -0.3,
      height: height ?? 1.2,
    );
  }

  static TextStyle editorialQuote({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
  }) {
    if (useSystemFonts) {
      return TextStyle(
        fontFamily: 'serif',
        color: color ?? textSecondary,
        fontSize: fontSize ?? 14.5,
        fontWeight: fontWeight ?? FontWeight.w400,
        fontStyle: FontStyle.italic,
        letterSpacing: letterSpacing ?? 0.1,
        height: height ?? 1.45,
      );
    }
    return GoogleFonts.fraunces(
      color: color ?? textSecondary,
      fontSize: fontSize ?? 14.5,
      fontWeight: fontWeight ?? FontWeight.w400,
      fontStyle: FontStyle.italic,
      letterSpacing: letterSpacing ?? 0.1,
      height: height ?? 1.45,
    );
  }

  // --- 2. UI / BODY: Manrope ---
  static TextStyle bodyText({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
  }) {
    if (useSystemFonts) {
      return TextStyle(
        fontFamily: 'sans-serif',
        color: color ?? textPrimary,
        fontSize: fontSize ?? 14,
        fontWeight: fontWeight ?? FontWeight.w400,
        letterSpacing: letterSpacing ?? 0.1,
        height: height ?? 1.5,
      );
    }
    return GoogleFonts.manrope(
      color: color ?? textPrimary,
      fontSize: fontSize ?? 14,
      fontWeight: fontWeight ?? FontWeight.w400,
      letterSpacing: letterSpacing ?? 0.1,
      height: height ?? 1.5,
    );
  }

  static TextStyle bodyLabel({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
  }) {
    if (useSystemFonts) {
      return TextStyle(
        fontFamily: 'sans-serif',
        color: color ?? textSecondary,
        fontSize: fontSize ?? 13,
        fontWeight: fontWeight ?? FontWeight.w500,
        letterSpacing: letterSpacing ?? 0.15,
        height: height ?? 1.3,
      );
    }
    return GoogleFonts.manrope(
      color: color ?? textSecondary,
      fontSize: fontSize ?? 13,
      fontWeight: fontWeight ?? FontWeight.w500,
      letterSpacing: letterSpacing ?? 0.15,
      height: height ?? 1.3,
    );
  }

  static TextStyle uiButton({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
  }) {
    if (useSystemFonts) {
      return TextStyle(
        fontFamily: 'sans-serif',
        color: color ?? onPrimaryAccent,
        fontSize: fontSize ?? 13.5,
        fontWeight: fontWeight ?? FontWeight.w600,
        letterSpacing: letterSpacing ?? 0.3,
      );
    }
    return GoogleFonts.manrope(
      color: color ?? onPrimaryAccent,
      fontSize: fontSize ?? 13.5,
      fontWeight: fontWeight ?? FontWeight.w600,
      letterSpacing: letterSpacing ?? 0.3,
    );
  }

  static TextStyle largeMetric({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
  }) {
    if (useSystemFonts) {
      return TextStyle(
        fontFamily: 'sans-serif',
        color: color ?? textPrimary,
        fontSize: fontSize ?? 28,
        fontWeight: fontWeight ?? FontWeight.w600,
        letterSpacing: letterSpacing ?? -0.5,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
    }
    return GoogleFonts.manrope(
      color: color ?? textPrimary,
      fontSize: fontSize ?? 28,
      fontWeight: fontWeight ?? FontWeight.w600,
      letterSpacing: letterSpacing ?? -0.5,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  // --- 3. DATA / TECHNICAL: IBM Plex Mono ---
  static TextStyle technicalLabel({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
  }) {
    if (useSystemFonts) {
      return TextStyle(
        fontFamily: 'monospace',
        color: color ?? textMuted,
        fontSize: fontSize ?? 10.5,
        fontWeight: fontWeight ?? FontWeight.w600,
        letterSpacing: letterSpacing ?? 1.5,
        height: height,
      );
    }
    return GoogleFonts.ibmPlexMono(
      color: color ?? textMuted,
      fontSize: fontSize ?? 10.5,
      fontWeight: fontWeight ?? FontWeight.w600,
      letterSpacing: letterSpacing ?? 1.5,
      height: height,
    );
  }

  static TextStyle dataValue({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
  }) {
    if (useSystemFonts) {
      return TextStyle(
        fontFamily: 'monospace',
        color: color ?? textPrimary,
        fontSize: fontSize ?? 12,
        fontWeight: fontWeight ?? FontWeight.w500,
        letterSpacing: letterSpacing ?? 0.5,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
    }
    return GoogleFonts.ibmPlexMono(
      color: color ?? textPrimary,
      fontSize: fontSize ?? 12,
      fontWeight: fontWeight ?? FontWeight.w500,
      letterSpacing: letterSpacing ?? 0.5,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  // Legacy compatibility getters mapped to the new typography scale
  static TextStyle get displayTimer => editorialDisplayLarge(fontSize: 54, fontWeight: FontWeight.w400);
  static TextStyle get displayMetric => largeMetric(fontSize: 24);
  static TextStyle get headlineInstrument => editorialTitle(fontSize: 15, fontWeight: FontWeight.w500);
  static TextStyle get bodyPrecision => bodyText(fontSize: 13);
  static TextStyle get microCopy => technicalLabel(fontSize: 9.5);

  // Shape Radii Tokens
  static const double radiusMicro = 4.0;
  static const double radiusControl = 8.0;
  static const double radiusDeck = 12.0;
  static const double radiusCapsule = 24.0;
  static double get cardBorderRadius => 8.0;

  // Editorial Quotes List
  static const List<String> editorialQuotes = [
    "\"A focused mind builds a different life.\"",
    "\"Progress isn't linear, but it always compounds.\"",
    "\"Consistency turns intention into reality.\"",
    "\"Distraction is expensive. Attention is a superpower.\"",
    "\"Small steps. A clearer mind.\"",
    "\"Find your rhythm. Protect your time.\"",
    "\"A quiet record of where your attention went.\"",
  ];

  static String get randomQuote {
    final idx = DateTime.now().minute % editorialQuotes.length;
    return editorialQuotes[idx];
  }

  // Contextual Micro-copy
  static String get brandBadge => 'CRANIUM';
  static String get brandTitle => 'CRANIUM';
  static String get brandSubtitle => 'A CALMER YOU';

  static String get navCockpitLabel => 'Home';
  static String get navTasksLabel => 'Journal';
  static String get navAnalyticsLabel => 'Stats';
  static String get navSettingsLabel => 'Tools';

  static String get statusLiveText => 'CONNECTED';
  static String get statusOfflineText => 'OFFLINE ARCHIVE';

  static String get startBtnText => 'Start Focus';
  static String get pauseBtnText => 'Pause';
  static String get resumeBtnText => 'Resume';
  static String get stopBtnText => 'End Session';

  static String get directivesTitle => 'Tasks & Directives';
  static String get notesTitle => 'Daily Reminders';
  static String get todayFocusTitle => 'Focus Today';
  static String get todayFocusSubtitle => 'Deep Work';

  static String getFocusDepthLabel(int minutes) {
    if (minutes < 15) return 'WARMUP';
    if (minutes < 45) return 'SHALLOW FOCUS';
    if (minutes < 90) return 'DEEP WORK';
    return 'SOVEREIGN FLOW';
  }

  static String focusDepthLabel(int minutes, bool isIdle) {
    if (isIdle || minutes < 15) return 'WARMUP';
    if (minutes < 45) return 'SHALLOW FOCUS';
    if (minutes < 90) return 'DEEP WORK';
    return 'SOVEREIGN FLOW';
  }

  // Tactile Haptics
  static void hapticSelection() => HapticFeedback.selectionClick();
  static void hapticAction() => HapticFeedback.mediumImpact();
  static void hapticLight() => HapticFeedback.lightImpact();

  // ==========================================
  // THEMEDATA BUILDERS
  // ==========================================

  static ThemeData get darkTheme {
    return _buildTheme(
      brightness: Brightness.dark,
      bg: const Color(0xFF0D0E10),
      card: const Color(0xFF161719),
      panel: const Color(0xFF1C1E22),
      border: const Color(0x1FFFFFFF),
      text: const Color(0xFFE8E6DF),
      textSec: const Color(0xFFA2A49F),
      accent: const Color(0xFFE5B887),
      secondary: const Color(0xFF6E8B7E),
    );
  }

  static ThemeData get lightTheme {
    return _buildTheme(
      brightness: Brightness.light,
      bg: const Color(0xFFF5F2EB),
      card: const Color(0xFFEBE7DE),
      panel: const Color(0xFFE2DDD2),
      border: const Color(0x14000000),
      text: const Color(0xFF1A1C1D),
      textSec: const Color(0xFF6B6D68),
      accent: const Color(0xFFC68E54),
      secondary: const Color(0xFF3E5C4E),
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color bg,
    required Color card,
    required Color panel,
    required Color border,
    required Color text,
    required Color textSec,
    required Color accent,
    required Color secondary,
  }) {
    final standardTextTheme = brightness == Brightness.dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;
    final baseTextTheme = useSystemFonts
        ? standardTextTheme.apply(fontFamily: 'sans-serif')
        : GoogleFonts.manropeTextTheme(standardTextTheme);

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      primaryColor: accent,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: accent,
        onPrimary: brightness == Brightness.dark ? const Color(0xFF111214) : const Color(0xFFF5F2EB),
        secondary: secondary,
        onSecondary: Colors.white,
        surface: card,
        onSurface: text,
        error: const Color(0xFFE05353),
        onError: Colors.white,
      ),
      textTheme: useSystemFonts
          ? baseTextTheme.copyWith(
              displayLarge: TextStyle(color: text, fontWeight: FontWeight.w400, fontFamily: 'serif'),
              displayMedium: TextStyle(color: text, fontWeight: FontWeight.w500, fontFamily: 'serif'),
              headlineLarge: TextStyle(color: text, fontWeight: FontWeight.w500, fontFamily: 'serif'),
              headlineMedium: TextStyle(color: text, fontWeight: FontWeight.w500, fontFamily: 'serif'),
              titleLarge: TextStyle(color: text, fontWeight: FontWeight.w600, fontFamily: 'serif'),
              bodyLarge: TextStyle(color: text, fontWeight: FontWeight.w400, fontFamily: 'sans-serif'),
              bodyMedium: TextStyle(color: textSec, fontWeight: FontWeight.w400, fontFamily: 'sans-serif'),
              labelLarge: TextStyle(color: text, fontWeight: FontWeight.w600, fontFamily: 'sans-serif'),
              labelSmall: TextStyle(color: textSec, fontWeight: FontWeight.w500, letterSpacing: 1.2, fontFamily: 'monospace'),
            )
          : baseTextTheme.copyWith(
              displayLarge: GoogleFonts.fraunces(color: text, fontWeight: FontWeight.w400),
              displayMedium: GoogleFonts.fraunces(color: text, fontWeight: FontWeight.w500),
              headlineLarge: GoogleFonts.fraunces(color: text, fontWeight: FontWeight.w500),
              headlineMedium: GoogleFonts.fraunces(color: text, fontWeight: FontWeight.w500),
              titleLarge: GoogleFonts.fraunces(color: text, fontWeight: FontWeight.w600),
              bodyLarge: GoogleFonts.manrope(color: text, fontWeight: FontWeight.w400),
              bodyMedium: GoogleFonts.manrope(color: textSec, fontWeight: FontWeight.w400),
              labelLarge: GoogleFonts.manrope(color: text, fontWeight: FontWeight.w600),
              labelSmall: GoogleFonts.ibmPlexMono(color: textSec, fontWeight: FontWeight.w500, letterSpacing: 1.2),
            ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: text),
        titleTextStyle: useSystemFonts
            ? TextStyle(color: text, fontSize: 20, fontWeight: FontWeight.w500, fontFamily: 'serif')
            : GoogleFonts.fraunces(
                color: text,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
      ),
      cardTheme: CardTheme(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardBorderRadius),
          side: BorderSide(color: border, width: 1),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bg,
        selectedItemColor: accent,
        unselectedItemColor: textSec.withOpacity(0.6),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: useSystemFonts
            ? const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)
            : GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
        unselectedLabelStyle: useSystemFonts
            ? const TextStyle(fontSize: 11, fontWeight: FontWeight.w400)
            : GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
      ),
    );
  }
}
