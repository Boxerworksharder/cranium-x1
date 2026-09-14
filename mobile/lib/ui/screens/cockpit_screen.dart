import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/client_section.dart';
import '../../data/models/device_status.dart';
import '../../state/tracker_provider.dart';
import '../widgets/chrono_display.dart';
import '../widgets/stress_buster_dialog.dart';
import '../widgets/wellness_card.dart';

class CockpitScreen extends StatelessWidget {
  final VoidCallback? onOpenSettings;

  const CockpitScreen({super.key, this.onOpenSettings});

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  String _formatHoursMins(int totalSeconds) {
    final hrs = totalSeconds ~/ 3600;
    final mins = (totalSeconds % 3600) ~/ 60;
    if (hrs > 0) {
      return '${hrs}h ${mins}m';
    }
    return '${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackerProvider>(
      builder: (context, tracker, _) {
        final status = tracker.status;
        final activeClient = status.activeClient;
        final todayFocusSecs = status.totalDeepWorkToday;
        final totalSessions = status.clients.fold<int>(
          0,
          (sum, c) => sum + c.history.length + (c.totalSecondsToday > 60 ? 1 : 0),
        );
        final totalReps = status.clients.fold<int>(
          0,
          (sum, c) => sum + c.reps,
        );

        return SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () => tracker.refreshData(),
            color: AppTheme.accentPrimary,
            backgroundColor: AppTheme.bgCard,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. EDITORIAL APP BAR (Screenshot 1 Top)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Moon phase glyph (tap to toggle theme)
                      InkWell(
                        onTap: () {
                          AppTheme.hapticSelection();
                          tracker.toggleTheme();
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.bgCard,
                            border: Border.all(color: AppTheme.borderSubtle),
                          ),
                          child: Icon(
                            AppTheme.isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                            size: 18,
                            color: AppTheme.accentPrimary,
                          ),
                        ),
                      ),

                      // Brand center
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'CRANIUM',
                              style: AppTheme.editorialTitle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2.2,
                                height: 1.25,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'A CALMER YOU',
                              style: AppTheme.technicalLabel(
                                fontSize: 8.5,
                                letterSpacing: 1.8,
                                color: AppTheme.textMuted,
                                height: 1.25,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      // Settings Icon
                      InkWell(
                        onTap: () {
                          AppTheme.hapticSelection();
                          if (onOpenSettings != null) {
                            onOpenSettings!();
                          } else {
                            try {
                              DefaultTabController.of(context).animateTo(3);
                            } catch (_) {}
                          }
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.bgCard,
                            border: Border.all(color: AppTheme.borderSubtle),
                          ),
                          child: Icon(
                            Icons.settings_outlined,
                            size: 18,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 14),

                // Active Transport Pill & Hardware Indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildTransportPill(context, tracker),
                    if (status.powerbankKeepAlive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.orangeFlame.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.orangeFlame.withOpacity(0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt_rounded, size: 11, color: AppTheme.orangeFlame),
                            const SizedBox(width: 4),
                            Text(
                              'PB KEEPALIVE',
                              style: TextStyle(
                                color: AppTheme.orangeFlame,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 14),

                // 2. EDITORIAL GREETING (Screenshot 1)
                Text(
                  '${_getTimeGreeting()}\nSandeep.',
                  style: AppTheme.editorialTitle(
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Small steps. A clearer mind.',
                  style: AppTheme.bodyLabel(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),

                const SizedBox(height: 18),

                // 3. "FOCUS TODAY" HISTOGRAM CARD (Screenshot 1)
                _buildFocusTodayCard(context, todayFocusSecs, status.totalWasteToday, status.focusPurityPct),

                const SizedBox(height: 12),

                // 4. SIDE-BY-SIDE METRICS ROW (Screenshot 1: SESSIONS & DISTRACTIONS)
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        label: 'SESSIONS',
                        value: '$totalSessions',
                        deltaText: '+2 vs yesterday',
                        isPositive: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'DISTRACTIONS',
                        value: '$totalReps',
                        deltaText: '-40%',
                        isPositive: true,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // 5. EDITORIAL QUOTE
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(AppTheme.radiusDeck),
                    border: Border.all(color: AppTheme.borderSubtle, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '"A focused mind builds a different life."',
                        style: AppTheme.editorialQuote(
                          fontSize: 14.5,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '— CRANIUM',
                        style: AppTheme.technicalLabel(
                          fontSize: 9.5,
                          letterSpacing: 1.5,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // TIME SINK ACTIVE BANNER (When active client is classified as negative)
                if (activeClient?.isNegative == true) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A1215),
                      borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                      border: Border.all(color: const Color(0xFFFF453A).withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF453A), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TIME SINK ACTIVE: ${activeClient?.name.toUpperCase()}',
                                style: const TextStyle(
                                  color: Color(0xFFFF453A),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10.5,
                                  letterSpacing: 0.8,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Excluded from Deep Work total & daily goal. Tracked for accountability.',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 6. HERO CHRONOGRAPH RADIAL DIAL (Screen 6 from attached images)
                ChronoDisplay(
                  totalSeconds: status.sessionSeconds,
                  state: status.state,
                  timerMode: tracker.timerMode,
                  countdownTargetMinutes: tracker.countdownTargetMinutes,
                  remainingSeconds: tracker.remainingSeconds,
                  activeSectionName: activeClient?.name ?? 'Deep work',
                  isNegative: activeClient?.isNegative == true,
                  onToggleMode: () => tracker.toggleTimerMode(),
                  onSelectCountdownMinutes: (mins) => tracker.setCountdownDuration(mins),
                  onStart: () {
                    final targetId = activeClient?.id ??
                        (status.clients.isNotEmpty ? status.clients.first.id : 1);
                    tracker.startSession(targetId);
                  },
                  onPause: () => tracker.pauseSession(),
                  onResume: () => tracker.resumeSession(),
                  onStop: () => tracker.stopSession(),
                ),

                const SizedBox(height: 16),

                // 7. SECTION SELECTOR DOCK
                _buildSectionSelectorDock(context, tracker, status),

                const SizedBox(height: 14),

                // 8. TALLY STEPPER & 2-MIN ZEN RESET
                Row(
                  children: [
                    Expanded(
                      child: _buildRepStepperCard(tracker, activeClient),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildZenResetCard(context, tracker, status),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // 9. WELLNESS & POSTURE REMINDERS
                const WellnessCard(),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      );
      },
    );
  }

  // --- 3. FOCUS TODAY CARD ---
  Widget _buildFocusTodayCard(BuildContext context, int todaySecs, int wasteSecs, int purityPct) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusDeck),
        border: Border.all(color: AppTheme.borderSubtle, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('FOCUS TODAY', style: AppTheme.technicalLabel()),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accentSage.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMicro),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_upward_rounded, size: 11, color: AppTheme.accentSage),
                    const SizedBox(width: 2),
                    Text(
                      '12%',
                      style: AppTheme.technicalLabel(
                        color: AppTheme.accentSage,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Text(
            _formatHoursMins(todaySecs),
            style: AppTheme.editorialDisplayLarge(
              fontSize: 34,
              fontWeight: FontWeight.w400,
            ),
          ),

          const SizedBox(height: 16),

          // Hourly histogram visualization
          SizedBox(
            height: 52,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(24, (i) {
                // Synthetic or real distribution peaks around 9am, 2pm, 8pm
                final heights = [
                  6, 4, 3, 3, 4, 8, 14, 22, 34, 46, 38, 30, 24, 28, 38, 44, 36, 28, 34, 48, 40, 26, 16, 10
                ];
                final barH = (heights[i] * 0.9).clamp(4.0, 48.0);
                final isPeak = i == 19; // 7-8 PM spike

                return Container(
                  width: 5,
                  height: barH,
                  decoration: BoxDecoration(
                    color: isPeak
                        ? AppTheme.accentPrimary
                        : (barH > 25 ? AppTheme.accentSage : AppTheme.borderSubtle),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('6 AM', style: AppTheme.technicalLabel(fontSize: 9)),
              Text('12 PM', style: AppTheme.technicalLabel(fontSize: 9)),
              Text('6 PM', style: AppTheme.technicalLabel(fontSize: 9)),
              Text('12 AM', style: AppTheme.technicalLabel(fontSize: 9)),
            ],
          ),

          const SizedBox(height: 14),

          // Focus Purity & Time Sink Telemetry Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.bgPanel,
              borderRadius: BorderRadius.circular(AppTheme.radiusMicro),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 13,
                          color: purityPct >= 75 ? AppTheme.accentSage : const Color(0xFFFF453A),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$purityPct% FOCUS PURITY',
                          style: AppTheme.technicalLabel(
                            fontSize: 9.5,
                            color: purityPct >= 75 ? AppTheme.accentSage : const Color(0xFFFF453A),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'SINK: ${_formatHoursMins(wasteSecs)}',
                      style: AppTheme.technicalLabel(
                        fontSize: 9.5,
                        color: wasteSecs > 0 ? const Color(0xFFFF453A) : AppTheme.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Row(
                    children: [
                      Expanded(
                        flex: purityPct > 0 ? purityPct : (wasteSecs > 0 ? 0 : 100),
                        child: Container(
                          height: 4,
                          color: AppTheme.accentSage,
                        ),
                      ),
                      if (100 - purityPct > 0)
                        Expanded(
                          flex: 100 - purityPct,
                          child: Container(
                            height: 4,
                            color: const Color(0xFFFF453A),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. METRIC TILE ---
  Widget _buildMetricTile({
    required String label,
    required String value,
    required String deltaText,
    required bool isPositive,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusDeck),
        border: Border.all(color: AppTheme.borderSubtle, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTheme.technicalLabel(fontSize: 9.5)),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTheme.largeMetric(fontSize: 26),
          ),
          const SizedBox(height: 4),
          Text(
            deltaText,
            style: AppTheme.bodyLabel(
              fontSize: 11,
              color: isPositive ? AppTheme.accentSage : AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // --- SECTION SELECTOR DOCK ---
  Widget _buildSectionSelectorDock(
    BuildContext context,
    TrackerProvider tracker,
    DeviceStatus status,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusDeck),
        border: Border.all(color: AppTheme.borderSubtle, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('FOCUS SECTIONS', style: AppTheme.technicalLabel()),
              InkWell(
                onTap: () {
                  AppTheme.hapticSelection();
                  _showAddSectionDialog(context, tracker);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 14, color: AppTheme.accentPrimary),
                    const SizedBox(width: 4),
                    Text(
                      'ADD',
                      style: AppTheme.technicalLabel(color: AppTheme.accentPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: status.clients.map((client) {
                final isSelected = client.id == status.activeClientId;
                final todayHrs = (client.totalSecondsToday / 3600).toStringAsFixed(1);
                final isNegative = client.isNegative;

                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                    onTap: () {
                      AppTheme.hapticSelection();
                      tracker.selectSection(client.id);
                    },
                    onLongPress: () {
                      AppTheme.hapticAction();
                      _showSectionOptionsDialog(context, tracker, client);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isNegative
                            ? (isSelected ? const Color(0xFF4A1A1E) : const Color(0xFF281316))
                            : (isSelected ? AppTheme.accentPrimary.withOpacity(0.15) : AppTheme.bgPanel),
                        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                        border: Border.all(
                          color: isNegative
                              ? (isSelected ? const Color(0xFFFF453A) : const Color(0xFFFF453A).withOpacity(0.45))
                              : (isSelected ? AppTheme.accentPrimary : AppTheme.borderSubtle),
                          width: isSelected ? 1.4 : 1.0,
                        ),
                        boxShadow: isSelected && isNegative
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFFF453A).withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isNegative) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF453A).withOpacity(isSelected ? 0.3 : 0.18),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: const Color(0xFFFF453A).withOpacity(0.5)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.remove_circle_outline_rounded,
                                    size: 9.5,
                                    color: Color(0xFFFF453A),
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    'SINK',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFFF453A),
                                      fontFamily: 'monospace',
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          Text(
                            client.name,
                            style: AppTheme.bodyLabel(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isNegative
                                  ? (isSelected ? Colors.white : const Color(0xFFFF9E94))
                                  : (isSelected ? AppTheme.textPrimary : AppTheme.textSecondary),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${todayHrs}h',
                            style: AppTheme.technicalLabel(
                              fontSize: 9.5,
                              color: isNegative
                                  ? const Color(0xFFFF453A)
                                  : (isSelected ? AppTheme.accentPrimary : AppTheme.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // --- REP STEPPER CARD ---
  Widget _buildRepStepperCard(TrackerProvider tracker, ClientSection? client) {
    final reps = client?.reps ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        border: Border.all(color: AppTheme.borderSubtle, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('REPS / TALLY', style: AppTheme.technicalLabel(fontSize: 8.5)),
                const SizedBox(height: 2),
                Text(
                  '$reps',
                  style: AppTheme.largeMetric(fontSize: 18),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  AppTheme.hapticSelection();
                  tracker.adjustRep(increment: false);
                },
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.remove_circle_outline, size: 20, color: AppTheme.textMuted),
                ),
              ),
              const SizedBox(width: 2),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  AppTheme.hapticSelection();
                  tracker.adjustRep(increment: true);
                },
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.add_circle, size: 20, color: AppTheme.accentPrimary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- ZEN RESET CARD ---
  Widget _buildZenResetCard(BuildContext context, TrackerProvider tracker, DeviceStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        border: Border.all(color: AppTheme.borderSubtle, width: 1),
      ),
      child: InkWell(
        onTap: () {
          AppTheme.hapticAction();
          StressBusterDialog.show(context);
        },
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentSage.withOpacity(0.15),
              ),
              child: Icon(Icons.spa_rounded, size: 17, color: AppTheme.accentSage),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('2-MIN RESET', style: AppTheme.technicalLabel(fontSize: 8.5)),
                  const SizedBox(height: 2),
                  Text(
                    'Box Breathing',
                    style: AppTheme.bodyLabel(fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSectionDialog(BuildContext context, TrackerProvider tracker) {
    final controller = TextEditingController();
    bool isNegative = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: AppTheme.bgCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusDeck),
              side: BorderSide(color: AppTheme.borderSubtle),
            ),
            title: Text('New Activity Section', style: AppTheme.editorialTitle(fontSize: 18)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    style: AppTheme.bodyText(),
                    decoration: InputDecoration(
                      hintText: isNegative ? 'e.g. YouTube & Reels, Gaming' : 'e.g. Research, Deep Writing',
                      hintStyle: AppTheme.bodyLabel(color: AppTheme.textMuted),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.borderSubtle)),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: isNegative ? const Color(0xFFFF453A) : AppTheme.accentPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.bgPanel,
                      borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                      border: Border.all(
                        color: isNegative ? const Color(0xFFFF453A).withOpacity(0.4) : AppTheme.borderSubtle,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isNegative ? 'TRACK AS TIME SINK' : 'COUNT AS DEEP WORK',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isNegative ? const Color(0xFFFF453A) : AppTheme.accentSage,
                                  letterSpacing: 0.8,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isNegative
                                    ? 'Excluded from Deep Work total & goal'
                                    : 'Adds to your daily Deep Work goal',
                                style: AppTheme.technicalLabel(fontSize: 9),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: isNegative,
                          activeColor: const Color(0xFFFF453A),
                          onChanged: (val) {
                            setModalState(() {
                              isNegative = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  if (isNegative) ...[
                    const SizedBox(height: 12),
                    Text('QUICK PRESETS:', style: AppTheme.technicalLabel(fontSize: 8.5)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: ['YouTube & Reels', 'Instagram', 'Gaming', 'Doomscrolling'].map((tag) {
                        return InkWell(
                          onTap: () {
                            controller.text = tag;
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF453A).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFFF453A).withOpacity(0.3)),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(fontSize: 10, color: Color(0xFFFF453A)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('CANCEL', style: AppTheme.technicalLabel()),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isNegative ? const Color(0xFFFF453A) : AppTheme.accentPrimary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final name = controller.text.trim();
                  if (name.isNotEmpty) {
                    tracker.addSection(name, isNegative: isNegative);
                    Navigator.pop(ctx);
                  }
                },
                child: Text('CREATE', style: AppTheme.uiButton(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSectionOptionsDialog(
    BuildContext context,
    TrackerProvider tracker,
    ClientSection client,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusDeck),
          side: BorderSide(color: AppTheme.borderSubtle),
        ),
        title: Text(client.name, style: AppTheme.editorialTitle(fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: client.isNegative
                    ? const Color(0xFFFF453A).withOpacity(0.15)
                    : AppTheme.accentSage.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: client.isNegative
                      ? const Color(0xFFFF453A).withOpacity(0.45)
                      : AppTheme.accentSage.withOpacity(0.45),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    client.isNegative ? Icons.remove_circle_outline_rounded : Icons.check_circle_outline_rounded,
                    size: 16,
                    color: client.isNegative ? const Color(0xFFFF453A) : AppTheme.accentSage,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      client.isNegative
                          ? 'STATUS: TIME SINK / NEGATIVE ACTIVITY'
                          : 'STATUS: PRODUCTIVE DEEP WORK',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: client.isNegative ? const Color(0xFFFF453A) : AppTheme.accentSage,
                        fontFamily: 'monospace',
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              client.isNegative
                  ? 'Excluded from Deep Work total, daily goal, and streak counter. Tracked separately for accountability.'
                  : 'Counts directly toward daily focus goal, streaks, and Level XP progression.',
              style: AppTheme.bodyText(fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                client.isNegative ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                color: client.isNegative ? AppTheme.accentSage : const Color(0xFFFF453A),
              ),
              title: Text(
                client.isNegative ? 'Reclassify as Deep Work' : 'Reclassify as Time Sink',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: client.isNegative ? AppTheme.accentSage : const Color(0xFFFF453A),
                ),
              ),
              subtitle: Text(
                client.isNegative
                  ? 'Future time will count towards your daily goal'
                  : 'Time will be tracked separately as waste',
                style: AppTheme.technicalLabel(fontSize: 9),
              ),
              onTap: () {
                tracker.toggleSectionNegative(client.id, !client.isNegative);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: AppTheme.technicalLabel()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerCrimson,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _showDeleteSectionDialog(context, tracker, client.id, client.name);
            },
            child: Text('DELETE', style: AppTheme.uiButton(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteSectionDialog(
    BuildContext context,
    TrackerProvider tracker,
    int clientId,
    String clientName,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusDeck),
          side: BorderSide(color: AppTheme.borderSubtle),
        ),
        title: Text('Delete Section', style: AppTheme.editorialTitle(fontSize: 18)),
        content: Text(
          'Are you sure you want to remove "$clientName"? Historical data will remain archived.',
          style: AppTheme.bodyText(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: AppTheme.technicalLabel()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerCrimson,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              tracker.deleteSection(clientId);
              Navigator.pop(ctx);
            },
            child: Text('DELETE', style: AppTheme.uiButton(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildTransportPill(BuildContext context, TrackerProvider tracker) {
    final isBle = tracker.protocol == SyncProtocol.bluetooth && tracker.bleService.isConnected;
    final isHotspot = tracker.isOnline && (tracker.host.contains('192.168.4.1') || tracker.status.isAwayMode);
    final isHome = tracker.isOnline && !isBle && !isHotspot;

    Color badgeColor;
    IconData badgeIcon;
    String badgeLabel;

    if (isBle) {
      badgeColor = AppTheme.cyanTelemetry;
      badgeIcon = Icons.bluetooth_connected_rounded;
      badgeLabel = 'BLUETOOTH (AWAY)';
    } else if (isHotspot) {
      badgeColor = AppTheme.orangeFlame;
      badgeIcon = Icons.wifi_tethering_rounded;
      badgeLabel = 'HOTSPOT (192.168.4.1)';
    } else if (isHome) {
      badgeColor = AppTheme.emeraldGreen;
      badgeIcon = Icons.wifi_rounded;
      badgeLabel = 'HOME WI-FI';
    } else {
      badgeColor = AppTheme.textMuted;
      badgeIcon = Icons.wifi_off_rounded;
      badgeLabel = 'OFFLINE (STANDBY)';
    }

    return InkWell(
      onTap: () {
        AppTheme.hapticSelection();
        tracker.refreshData();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: badgeColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: badgeColor.withOpacity(0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(badgeIcon, size: 12, color: badgeColor),
            const SizedBox(width: 5),
            Text(
              badgeLabel,
              style: TextStyle(
                color: badgeColor,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
