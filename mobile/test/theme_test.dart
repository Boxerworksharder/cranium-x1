import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titiksha_mobile/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Editorial Dual-Theme Engine Tests', () {
    test('Dark Obsidian theme tokens and typography scale', () {
      AppTheme.currentStyle = UiThemeStyle.dark;

      expect(AppTheme.isDark, isTrue);
      expect(AppTheme.isLight, isFalse);

      expect(AppTheme.bgBase, const Color(0xFF0D0E10));
      expect(AppTheme.bgCard, const Color(0xFF161719));
      expect(AppTheme.textPrimary, const Color(0xFFE8E6DF));
      expect(AppTheme.accentPrimary, const Color(0xFFE5B887));
      expect(AppTheme.accentSage, const Color(0xFF6E8B7E));

      expect(AppTheme.focusDepthLabel(50, false), 'DEEP WORK');
      expect(AppTheme.brandBadge, 'CRANIUM');
      expect(AppTheme.brandSubtitle, 'A CALMER YOU');
      expect(AppTheme.startBtnText, 'Start Focus');
    });

    test('Light Parchment theme tokens and typography scale', () {
      AppTheme.currentStyle = UiThemeStyle.light;

      expect(AppTheme.isDark, isFalse);
      expect(AppTheme.isLight, isTrue);

      expect(AppTheme.bgBase, const Color(0xFFF5F2EB));
      expect(AppTheme.bgCard, const Color(0xFFEBE7DE));
      expect(AppTheme.textPrimary, const Color(0xFF1A1C1D));
      expect(AppTheme.accentPrimary, const Color(0xFFC68E54));
      expect(AppTheme.accentSage, const Color(0xFF3E5C4E));

      expect(AppTheme.focusDepthLabel(10, false), 'WARMUP');
      expect(AppTheme.focusDepthLabel(25, false), 'SHALLOW FOCUS');
      expect(AppTheme.focusDepthLabel(100, false), 'SOVEREIGN FLOW');
    });

    test('ThemeData generation for Light and Dark', () {
      final darkTheme = AppTheme.darkTheme;
      expect(darkTheme.brightness, Brightness.dark);
      expect(darkTheme.scaffoldBackgroundColor, const Color(0xFF0D0E10));

      final lightTheme = AppTheme.lightTheme;
      expect(lightTheme.brightness, Brightness.light);
      expect(lightTheme.scaffoldBackgroundColor, const Color(0xFFF5F2EB));
    });
  });
}
