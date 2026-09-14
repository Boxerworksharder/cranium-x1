import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'state/tracker_provider.dart';
import 'ui/screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CraniumApp());
}

class CraniumApp extends StatelessWidget {
  const CraniumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TrackerProvider(),
      child: Consumer<TrackerProvider>(
        builder: (context, tracker, _) {
          return MaterialApp(
            title: 'Cranium Focus',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: tracker.themeStyle == UiThemeStyle.light ? ThemeMode.light : ThemeMode.dark,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}

/// Backward compatibility alias for legacy references
typedef TitikshaApp = CraniumApp;
