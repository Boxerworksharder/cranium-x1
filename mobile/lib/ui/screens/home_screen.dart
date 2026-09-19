import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../state/tracker_provider.dart';
import 'cockpit_screen.dart';
import 'tasks_screen.dart';
import 'analytics_screen.dart';
import 'checklist_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens = [
    CockpitScreen(onOpenSettings: () {
      setState(() => _currentIndex = 4);
    }),
    const AnalyticsScreen(),
    const TasksScreen(),
    const ChecklistScreen(),
    const SettingsScreen(),
  ];

  final List<String> _titles = const [
    'Cranium',
    'The receipts.',
    'Journal & Directives',
    'Standard Operating Procedures',
    'System Tools',
  ];

  @override
  Widget build(BuildContext context) {
    final tracker = context.watch<TrackerProvider>();
    final pendingTasksCount = tracker.tasks.where((t) => !t.done).length;

    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      appBar: _currentIndex == 0
          ? null // CockpitScreen renders its own full editorial app bar
          : AppBar(
              backgroundColor: AppTheme.bgBase,
              elevation: 0,
              centerTitle: false,
              title: Text(
                _titles[_currentIndex],
                style: AppTheme.editorialTitle(fontSize: 22),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    AppTheme.isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                    color: AppTheme.accentPrimary,
                    size: 20,
                  ),
                  onPressed: () {
                    AppTheme.hapticSelection();
                    tracker.toggleTheme();
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
      body: SafeArea(
        top: true,
        bottom: false,
        child: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          border: Border(
            top: BorderSide(color: AppTheme.borderSubtle, width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              _buildNavItem(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
              _buildNavItem(1, Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Stats'),
              _buildNavItem(2, Icons.edit_note_outlined, Icons.edit_note_rounded, 'Journal', badgeCount: pendingTasksCount),
              _buildNavItem(3, Icons.checklist_outlined, Icons.checklist_rounded, 'SOPs'),
              _buildNavItem(4, Icons.tune_outlined, Icons.tune_rounded, 'Tools'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData iconOutlined, IconData iconFilled, String label, {int badgeCount = 0}) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? AppTheme.accentPrimary : AppTheme.textMuted;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusCapsule),
        onTap: () {
          if (_currentIndex != index) {
            AppTheme.hapticSelection();
            setState(() => _currentIndex = index);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Badge(
                isLabelVisible: badgeCount > 0,
                label: Text(
                  '$badgeCount',
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                backgroundColor: AppTheme.accentSage,
                child: Icon(
                  isSelected ? iconFilled : iconOutlined,
                  size: 22,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: AppTheme.bodyLabel(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
