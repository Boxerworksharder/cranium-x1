import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/task_item.dart';
import '../../data/models/reminder_item.dart';
import '../../state/tracker_provider.dart';
import '../widgets/task_tile.dart';
import '../widgets/reminder_tile.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  int _activeTab = 0; // 0: Priority Tasks, 1: Daily Notes & Reminders
  int _filterIndex = 0; // 0: All, 1: Pending, 2: Done

  void _showAddTaskSheet(BuildContext context) {
    final tracker = context.read<TrackerProvider>();
    if (tracker.tasks.length >= 16) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task list is full (maximum 16 tasks for device sync)')),
      );
      return;
    }
    final textCtrl = TextEditingController();
    int selectedStars = 3; // Default to 3 stars (top priority)

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceOverlay,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 12,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.hairlineSeam,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'NEW PRIORITY TASK',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppTheme.orangeFlame,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.orangeFlame.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMicro),
                          border: Border.all(color: AppTheme.orangeFlame.withOpacity(0.35)),
                        ),
                        child: Text(
                          'CLICK GPIO 20',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: AppTheme.orangeFlame,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: textCtrl,
                    autofocus: true,
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'What is your immediate focus objective?',
                      hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      filled: true,
                      fillColor: AppTheme.surfaceRecessed,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                        borderSide: BorderSide(color: AppTheme.hairlineSeam),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                        borderSide: BorderSide(color: AppTheme.hairlineSeam),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                        borderSide: BorderSide(color: AppTheme.orangeFlame, width: 1.2),
                      ),
                    ),
                    onSubmitted: (_) {
                      if (textCtrl.text.trim().isNotEmpty) {
                        AppTheme.hapticAction();
                        context.read<TrackerProvider>().addTask(textCtrl.text.trim(), selectedStars);
                        Navigator.pop(ctx);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'PRIORITY RANK',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textMuted,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ...List.generate(3, (idx) {
                        final starCount = idx + 1;
                        final isSel = selectedStars == starCount;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () {
                              AppTheme.hapticSelection();
                              setSheetState(() => selectedStars = starCount);
                            },
                            borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSel ? AppTheme.orangeFlame.withOpacity(0.18) : AppTheme.surfaceRecessed,
                                borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                                border: Border.all(
                                  color: isSel ? AppTheme.orangeFlame : AppTheme.hairlineSeam,
                                ),
                              ),
                              child: Text(
                                '★' * starCount,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSel ? AppTheme.orangeFlame : AppTheme.textMuted,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.orangeFlame,
                        foregroundColor: AppTheme.onPrimaryAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        if (textCtrl.text.trim().isNotEmpty) {
                          AppTheme.hapticAction();
                          context.read<TrackerProvider>().addTask(textCtrl.text.trim(), selectedStars);
                          Navigator.pop(ctx);
                        }
                      },
                      child: const Text(
                        'DISPATCH TO DESK',
                        style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddReminderSheet(BuildContext context) {
    final tracker = context.read<TrackerProvider>();
    if (tracker.reminders.length >= 16) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminders full (maximum 16 notes for device sync)')),
      );
      return;
    }
    final textCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceOverlay,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 12,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.hairlineSeam,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'NEW DAILY NOTE / REMINDER',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppTheme.cyanTelemetry,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.cyanTelemetry.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMicro),
                          border: Border.all(color: AppTheme.cyanTelemetry.withOpacity(0.35)),
                        ),
                        child: Text(
                          'HOLD GPIO 20',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: AppTheme.cyanTelemetry,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Stored on desk tracker without tick boxes for persistent awareness.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: textCtrl,
                    autofocus: true,
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'e.g., Hydrate 3L, Read 30m, Posture check...',
                      hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      filled: true,
                      fillColor: AppTheme.surfaceRecessed,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                        borderSide: BorderSide(color: AppTheme.hairlineSeam),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                        borderSide: BorderSide(color: AppTheme.hairlineSeam),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                        borderSide: BorderSide(color: AppTheme.cyanTelemetry, width: 1.2),
                      ),
                    ),
                    onSubmitted: (_) {
                      if (textCtrl.text.trim().isNotEmpty) {
                        AppTheme.hapticAction();
                        context.read<TrackerProvider>().addReminder(textCtrl.text.trim());
                        Navigator.pop(ctx);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.cyanTelemetry,
                        foregroundColor: AppTheme.surfaceVoid,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        if (textCtrl.text.trim().isNotEmpty) {
                          AppTheme.hapticAction();
                          context.read<TrackerProvider>().addReminder(textCtrl.text.trim());
                          Navigator.pop(ctx);
                        }
                      },
                      child: const Text(
                        'SAVE NOTE TO DESK',
                        style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showEditTaskSheet(BuildContext context, TaskItem task) {
    final textCtrl = TextEditingController(text: task.text);
    textCtrl.selection = TextSelection.fromPosition(TextPosition(offset: task.text.length));
    int selectedStars = task.stars;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceOverlay,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 12,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.hairlineSeam,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'EDIT PRIORITY TASK',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppTheme.orangeFlame,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.orangeFlame.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMicro),
                          border: Border.all(color: AppTheme.orangeFlame.withOpacity(0.35)),
                        ),
                        child: Text(
                          'ID #${task.id}',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: AppTheme.orangeFlame,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: textCtrl,
                    autofocus: true,
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Edit focus objective...',
                      hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      filled: true,
                      fillColor: AppTheme.surfaceRecessed,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                        borderSide: BorderSide(color: AppTheme.hairlineSeam),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                        borderSide: BorderSide(color: AppTheme.hairlineSeam),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                        borderSide: BorderSide(color: AppTheme.orangeFlame, width: 1.2),
                      ),
                    ),
                    onSubmitted: (_) {
                      if (textCtrl.text.trim().isNotEmpty) {
                        AppTheme.hapticAction();
                        context.read<TrackerProvider>().updateTask(
                              task.id,
                              text: textCtrl.text.trim(),
                              stars: selectedStars,
                            );
                        Navigator.pop(ctx);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'PRIORITY RANK',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textMuted,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ...List.generate(3, (idx) {
                        final starCount = idx + 1;
                        final isSel = selectedStars == starCount;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () {
                              AppTheme.hapticSelection();
                              setSheetState(() => selectedStars = starCount);
                            },
                            borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSel ? AppTheme.orangeFlame.withOpacity(0.18) : AppTheme.surfaceRecessed,
                                borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                                border: Border.all(
                                  color: isSel ? AppTheme.orangeFlame : AppTheme.hairlineSeam,
                                ),
                              ),
                              child: Text(
                                '★' * starCount,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSel ? AppTheme.orangeFlame : AppTheme.textMuted,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.orangeFlame,
                        foregroundColor: AppTheme.onPrimaryAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        if (textCtrl.text.trim().isNotEmpty) {
                          AppTheme.hapticAction();
                          context.read<TrackerProvider>().updateTask(
                                task.id,
                                text: textCtrl.text.trim(),
                                stars: selectedStars,
                              );
                          Navigator.pop(ctx);
                        }
                      },
                      child: const Text(
                        'SAVE CHANGES',
                        style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showEditReminderSheet(BuildContext context, ReminderItem reminder) {
    final textCtrl = TextEditingController(text: reminder.text);
    textCtrl.selection = TextSelection.fromPosition(TextPosition(offset: reminder.text.length));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceOverlay,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 12,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.hairlineSeam,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'EDIT DAILY NOTE / REMINDER',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppTheme.cyanTelemetry,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.cyanTelemetry.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMicro),
                          border: Border.all(color: AppTheme.cyanTelemetry.withOpacity(0.35)),
                        ),
                        child: Text(
                          'ID #${reminder.id}',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: AppTheme.cyanTelemetry,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: textCtrl,
                    autofocus: true,
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Edit daily note or habit reminder...',
                      hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      filled: true,
                      fillColor: AppTheme.surfaceRecessed,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                        borderSide: BorderSide(color: AppTheme.hairlineSeam),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                        borderSide: BorderSide(color: AppTheme.hairlineSeam),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                        borderSide: BorderSide(color: AppTheme.cyanTelemetry, width: 1.2),
                      ),
                    ),
                    onSubmitted: (_) {
                      if (textCtrl.text.trim().isNotEmpty) {
                        AppTheme.hapticAction();
                        context.read<TrackerProvider>().updateReminder(
                              reminder.id,
                              textCtrl.text.trim(),
                            );
                        Navigator.pop(ctx);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.cyanTelemetry,
                        foregroundColor: AppTheme.surfaceVoid,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        if (textCtrl.text.trim().isNotEmpty) {
                          AppTheme.hapticAction();
                          context.read<TrackerProvider>().updateReminder(
                                reminder.id,
                                textCtrl.text.trim(),
                              );
                          Navigator.pop(ctx);
                        }
                      },
                      child: const Text(
                        'SAVE CHANGES',
                        style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackerProvider>(
      builder: (context, tracker, _) {
        final tasks = tracker.tasks;
        final reminders = tracker.reminders;

        final filteredTasks = tasks.where((t) {
          if (_filterIndex == 1) return !t.done;
          if (_filterIndex == 2) return t.done;
          return true;
        }).toList();

        final doneCount = tasks.where((t) => t.done).length;

        return Scaffold(
          floatingActionButton: FloatingActionButton(
            backgroundColor: _activeTab == 0 ? AppTheme.orangeFlame : AppTheme.cyanTelemetry,
            onPressed: () {
              AppTheme.hapticAction();
              _activeTab == 0 ? _showAddTaskSheet(context) : _showAddReminderSheet(context);
            },
            child: Icon(
              Icons.add,
              color: _activeTab == 0 ? AppTheme.onPrimaryAccent : Colors.black,
              size: 28,
            ),
          ),
          body: RefreshIndicator(
            onRefresh: () => tracker.refreshData(),
            color: _activeTab == 0 ? AppTheme.orangeFlame : AppTheme.cyanTelemetry,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dual Mode Segmented Tab Switch
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDeck,
                      borderRadius: BorderRadius.circular(AppTheme.radiusDeck),
                      border: Border.all(color: AppTheme.hairlineSeam),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTopTab(
                            title: 'PRIORITY TASKS',
                            count: tasks.length,
                            isSelected: _activeTab == 0,
                            accentColor: AppTheme.orangeFlame,
                            onTap: () => setState(() => _activeTab = 0),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _buildTopTab(
                            title: AppTheme.notesTitle,
                            count: reminders.length,
                            isSelected: _activeTab == 1,
                            accentColor: AppTheme.cyanTelemetry,
                            onTap: () => setState(() => _activeTab = 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // TAB CONTENT
                  if (_activeTab == 0) ...[
                    // Filter bar & Done counter for Tasks
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            _buildFilterChip('ALL (${tasks.length})', 0),
                            const SizedBox(width: 6),
                            _buildFilterChip('PENDING (${tasks.length - doneCount})', 1),
                            const SizedBox(width: 6),
                            _buildFilterChip('DONE ($doneCount)', 2),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Tasks list
                    Expanded(
                      child: filteredTasks.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.task_alt_rounded,
                                    size: 48,
                                    color: AppTheme.textMuted.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'NO TASKS IN VIEW',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textMuted,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Tap + to add a priority task synced to your desk.',
                                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: filteredTasks.length,
                              itemBuilder: (context, idx) {
                                final task = filteredTasks[idx];
                                return TaskTile(
                                  task: task,
                                  onToggle: () => tracker.toggleTask(task.id),
                                  onDelete: () => tracker.deleteTask(task.id),
                                  onEdit: () => _showEditTaskSheet(context, task),
                                );
                              },
                            ),
                    ),
                  ] else ...[
                    // Reminders & Daily Notes Tab
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.cyanTelemetry.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.cyanTelemetry.withOpacity(0.25)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.cyanTelemetry),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Hold GPIO 20 on tracker to open notes list on OLED. Scroll with knob.',
                              style: TextStyle(fontSize: 11, color: AppTheme.cyanTelemetry, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    Expanded(
                      child: reminders.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.edit_note_rounded,
                                    size: 48,
                                    color: AppTheme.textMuted.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'NO DAILY NOTES RECORDED',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textMuted,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Tap + to add daily habit reminders without tick boxes.',
                                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: reminders.length,
                              itemBuilder: (context, idx) {
                                final reminder = reminders[idx];
                                return ReminderTile(
                                  reminder: reminder,
                                  onDelete: () => tracker.deleteReminder(reminder.id),
                                  onEdit: () => _showEditReminderSheet(context, reminder),
                                );
                              },
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopTab({
    required String title,
    required int count,
    required bool isSelected,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        AppTheme.hapticSelection();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withOpacity(0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
          border: Border.all(
            color: isSelected ? accentColor.withOpacity(0.8) : Colors.transparent,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withOpacity(0.12),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: isSelected ? accentColor : AppTheme.textMuted,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected ? accentColor : AppTheme.surfaceRecessed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  color: isSelected
                      ? (accentColor == AppTheme.cyanTelemetry ? AppTheme.surfaceVoid : Colors.black)
                      : AppTheme.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final isSelected = _filterIndex == index;
    return GestureDetector(
      onTap: () {
        AppTheme.hapticSelection();
        setState(() => _filterIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.orangeFlame : AppTheme.surfaceRecessed,
          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
          border: Border.all(
            color: isSelected ? AppTheme.orangeFlame : AppTheme.hairlineSeam,
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            fontFamily: 'monospace',
            color: isSelected ? AppTheme.onPrimaryAccent : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}
