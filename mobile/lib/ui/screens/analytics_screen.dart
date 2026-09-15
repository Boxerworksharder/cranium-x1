import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/services/csv_export_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/client_section.dart';
import '../../data/models/device_status.dart';
import '../../state/tracker_provider.dart';
import '../widgets/import_data_dialog.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _selectedFilterIndex = 0; // 0: Days, 1: Weeks, 2: Months, 3: Years
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackerProvider>(
      builder: (context, tracker, _) {
        final status = tracker.status;

        final deepWorkClients = status.clients.where((c) => !c.isNegative).toList();
        final negativeClients = status.clients.where((c) => c.isNegative).toList();

        final isTrackingOrPaused = status.state == TrackerState.tracking || status.state == TrackerState.paused;
        final activeClient = status.activeClient;
        final activeDeepWorkSecs = (isTrackingOrPaused && activeClient != null && !activeClient.isNegative) ? status.sessionSeconds : 0;
        final activeWasteSecs = (isTrackingOrPaused && activeClient != null && activeClient.isNegative) ? status.sessionSeconds : 0;

        // Calculate all-time and session metrics for pure Deep Work
        final int totalDeepWorkSecs = deepWorkClients.fold<int>(0, (sum, c) => sum + c.totalAccumulatedSecs) + activeDeepWorkSecs;
        final int totalMinsFocused = totalDeepWorkSecs ~/ 60;

        final int totalSessions = deepWorkClients.fold<int>(0, (sum, c) => sum + c.history.length + (c.totalSecondsToday >= 60 ? 1 : 0));
        final int streakDays = status.currentStreak;

        // Separate Metrics for Negative Activities / Time Sinks
        final totalWasteSecsToday = status.totalWasteToday + activeWasteSecs;
        final totalWasteSecsAllTime = negativeClients.fold<int>(0, (sum, c) => sum + c.totalAccumulatedSecs) + activeWasteSecs;
        final totalWasteSessions = negativeClients.fold<int>(0, (sum, c) => sum + c.history.length + (c.totalSecondsToday >= 60 ? 1 : 0));
        final purityPct = status.focusPurityPct;

        // Focus Score (Purity) across all tracked time
        final totalTrackedAllTime = totalDeepWorkSecs + totalWasteSecsAllTime;
        final String focusScore = totalTrackedAllTime > 0
            ? '${((totalDeepWorkSecs * 100) / totalTrackedAllTime).round()}%'
            : (totalDeepWorkSecs > 0 ? '100%' : (totalSessions > 0 ? '${status.focusPurityPct}%' : '100%'));

        final now = DateTime.now();

        // Distinct active dates & calendar weeks & daily average
        final Set<String> distinctDateStrings = {};
        final Set<String> distinctWeekStrings = {};

        if (status.totalDeepWorkToday >= 60 || activeDeepWorkSecs >= 60) {
          distinctDateStrings.add(DateFormat('yyyy-MM-dd').format(now));
          final weekNum = ((now.difference(DateTime(now.year, 1, 1)).inDays) / 7).floor();
          distinctWeekStrings.add('${now.year}-W$weekNum');
        }

        for (final c in deepWorkClients) {
          for (final h in c.history) {
            if (h.seconds < 60) continue;
            final dt = _parseEntryDate(h);
            if (dt != null) {
              distinctDateStrings.add(DateFormat('yyyy-MM-dd').format(dt));
              final weekNum = ((dt.difference(DateTime(dt.year, 1, 1)).inDays) / 7).floor();
              distinctWeekStrings.add('${dt.year}-W$weekNum');
            }
          }
        }

        final int weeksCount = distinctWeekStrings.length;
        final String dailyAvgHrs = (distinctDateStrings.isNotEmpty && totalDeepWorkSecs > 0)
            ? '${(totalDeepWorkSecs / distinctDateStrings.length / 3600.0).toStringAsFixed(1)}h'
            : '0.0h';

        // Weekday distribution for "Most Productive Day"
        final List<int> weekdaySecs = List<int>.filled(7, 0);
        final List<Set<String>> weekdayDistinctDates = List.generate(7, (_) => <String>{});

        if (status.totalDeepWorkToday >= 60 || activeDeepWorkSecs >= 60) {
          final dayIdx = now.weekday - 1; // Mon=0 .. Sun=6
          weekdaySecs[dayIdx] += status.totalDeepWorkToday + activeDeepWorkSecs;
          weekdayDistinctDates[dayIdx].add(DateFormat('yyyy-MM-dd').format(now));
        }

        for (final c in deepWorkClients) {
          for (final h in c.history) {
            if (h.seconds < 60) continue;
            final dt = _parseEntryDate(h);
            if (dt != null) {
              final dayIdx = dt.weekday - 1;
              weekdaySecs[dayIdx] += h.seconds;
              weekdayDistinctDates[dayIdx].add(DateFormat('yyyy-MM-dd').format(dt));
            }
          }
        }

        int maxDaySecs = 0;
        int peakDayIndex = -1;
        for (int i = 0; i < 7; i++) {
          if (weekdaySecs[i] > maxDaySecs) {
            maxDaySecs = weekdaySecs[i];
            peakDayIndex = i;
          }
        }

        const weekdayPlural = ['Mondays', 'Tuesdays', 'Wednesdays', 'Thursdays', 'Fridays', 'Saturdays', 'Sundays'];
        const weekdayChars = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

        final String peakDayTitle = maxDaySecs > 0 && peakDayIndex >= 0 ? weekdayPlural[peakDayIndex] : 'No data yet';
        final String peakDaySubtitle = maxDaySecs > 0 && peakDayIndex >= 0
            ? 'Avg. ${_formatDurationHoursMins(maxDaySecs ~/ (weekdayDistinctDates[peakDayIndex].isNotEmpty ? weekdayDistinctDates[peakDayIndex].length : 1))}'
            : 'Log sessions to see peak day';

        final deepWorkSecsToday = status.totalDeepWorkToday + activeDeepWorkSecs;
        final totalTrackedSecsToday = deepWorkSecsToday + totalWasteSecsToday;
        final deepWorkRatio = totalTrackedSecsToday > 0 ? (deepWorkSecsToday / totalTrackedSecsToday).clamp(0.0, 1.0) : 1.0;
        final wasteRatio = totalTrackedSecsToday > 0 ? (totalWasteSecsToday / totalTrackedSecsToday).clamp(0.0, 1.0) : 0.0;

        // Trajectory Histogram calculation based on _selectedFilterIndex
        int numBuckets = 14;
        List<String> bucketLabels = [];
        List<int> bucketSecs = [];

        if (_selectedFilterIndex == 0) {
          // Days: Last 14 days ending today
          numBuckets = 14;
          bucketSecs = List.filled(numBuckets, 0);
          final startDay = DateTime(now.year, now.month, now.day).subtract(Duration(days: numBuckets - 1));

          for (int i = 0; i < numBuckets; i++) {
            final dayDate = startDay.add(Duration(days: i));
            final dayKey = DateFormat('yyyy-MM-dd').format(dayDate);

            if (dayKey == DateFormat('yyyy-MM-dd').format(now)) {
              bucketSecs[i] += status.totalDeepWorkToday + activeDeepWorkSecs;
            }
            for (final c in deepWorkClients) {
              for (final h in c.history) {
                final dt = _parseEntryDate(h);
                if (dt != null && DateFormat('yyyy-MM-dd').format(dt) == dayKey) {
                  bucketSecs[i] += h.seconds;
                }
              }
            }
          }
          bucketLabels = [
            DateFormat('MMM d').format(startDay),
            DateFormat('MMM d').format(startDay.add(const Duration(days: 4))),
            DateFormat('MMM d').format(startDay.add(const Duration(days: 7))),
            DateFormat('MMM d').format(startDay.add(const Duration(days: 10))),
            DateFormat('MMM d').format(now),
          ];
        } else if (_selectedFilterIndex == 1) {
          // Weeks: Last 8 weeks ending this week
          numBuckets = 8;
          bucketSecs = List.filled(numBuckets, 0);
          for (int i = 0; i < numBuckets; i++) {
            final weekEnd = DateTime(now.year, now.month, now.day).subtract(Duration(days: (numBuckets - 1 - i) * 7));
            final weekStart = weekEnd.subtract(const Duration(days: 6));

            for (final c in deepWorkClients) {
              for (final h in c.history) {
                final dt = _parseEntryDate(h);
                if (dt != null && !dt.isBefore(weekStart) && !dt.isAfter(weekEnd.add(const Duration(days: 1)))) {
                  bucketSecs[i] += h.seconds;
                }
              }
            }
            if (i == numBuckets - 1) {
              bucketSecs[i] += status.totalDeepWorkToday + activeDeepWorkSecs;
            }
          }
          bucketLabels = ['8w ago', '6w ago', '4w ago', '2w ago', 'This week'];
        } else if (_selectedFilterIndex == 2) {
          // Months: Last 6 months ending this month
          numBuckets = 6;
          bucketSecs = List.filled(numBuckets, 0);
          for (int i = 0; i < numBuckets; i++) {
            final mDate = DateTime(now.year, now.month - (numBuckets - 1 - i), 1);
            final mYear = mDate.year;
            final mMonth = mDate.month;
            for (final c in deepWorkClients) {
              for (final h in c.history) {
                final dt = _parseEntryDate(h);
                if (dt != null && dt.year == mYear && dt.month == mMonth) {
                  bucketSecs[i] += h.seconds;
                }
              }
            }
            if (mYear == now.year && mMonth == now.month) {
              bucketSecs[i] += status.totalDeepWorkToday + activeDeepWorkSecs;
            }
          }
          bucketLabels = List.generate(numBuckets, (i) {
            final mDate = DateTime(now.year, now.month - (numBuckets - 1 - i), 1);
            return DateFormat('MMM').format(mDate);
          });
        } else {
          // Years: Last 3 years
          numBuckets = 3;
          bucketSecs = List.filled(numBuckets, 0);
          for (int i = 0; i < numBuckets; i++) {
            final y = now.year - (numBuckets - 1 - i);
            for (final c in deepWorkClients) {
              for (final h in c.history) {
                final dt = _parseEntryDate(h);
                if (dt != null && dt.year == y) {
                  bucketSecs[i] += h.seconds;
                }
              }
            }
            if (y == now.year) {
              bucketSecs[i] += status.totalDeepWorkToday + activeDeepWorkSecs;
            }
          }
          bucketLabels = List.generate(numBuckets, (i) => '${now.year - (numBuckets - 1 - i)}');
        }

        int maxBucketSecs = 0;
        for (final s in bucketSecs) {
          if (s > maxBucketSecs) maxBucketSecs = s;
        }

        // Total This Month calculation
        int thisMonthSecs = 0;
        int lastMonthSecs = 0;
        final lastMonthDate = DateTime(now.year, now.month - 1, 1);

        for (final c in deepWorkClients) {
          for (final h in c.history) {
            final dt = _parseEntryDate(h);
            if (dt != null) {
              if (dt.year == now.year && dt.month == now.month) {
                thisMonthSecs += h.seconds;
              } else if (dt.year == lastMonthDate.year && dt.month == lastMonthDate.month) {
                lastMonthSecs += h.seconds;
              }
            }
          }
        }
        thisMonthSecs += status.totalDeepWorkToday + activeDeepWorkSecs;

        final String thisMonthFormatted = _formatDurationHoursMins(thisMonthSecs);
        String monthTrendText = '—';
        Color monthTrendColor = AppTheme.textSecondary;
        IconData monthTrendIcon = Icons.remove;

        if (thisMonthSecs > 0 && lastMonthSecs == 0) {
          monthTrendText = 'NEW';
          monthTrendColor = AppTheme.accentSage;
          monthTrendIcon = Icons.trending_up_rounded;
        } else if (lastMonthSecs > 0) {
          final pct = (((thisMonthSecs - lastMonthSecs) / lastMonthSecs) * 100).round();
          if (pct >= 0) {
            monthTrendText = '↑ $pct%';
            monthTrendColor = AppTheme.accentSage;
            monthTrendIcon = Icons.show_chart_rounded;
          } else {
            monthTrendText = '↓ ${pct.abs()}%';
            monthTrendColor = const Color(0xFFFF453A);
            monthTrendIcon = Icons.trending_down_rounded;
          }
        }

        // Focus Rhythm (When We Focus) Heatmap calculation
        final List<List<int>> heatmapGrid = List.generate(5, (_) => List.filled(7, 0));
        const timeRowLabels = ['12 AM', '6 AM', '12 PM', '6 PM', '9 PM'];

        int getHourRow(int hour) {
          if (hour < 6) return 0;
          if (hour < 12) return 1;
          if (hour < 17) return 2;
          if (hour < 21) return 3;
          return 4;
        }

        if (status.totalDeepWorkToday >= 60 || activeDeepWorkSecs >= 60) {
          final r = getHourRow(now.hour);
          final c = now.weekday - 1;
          heatmapGrid[r][c] += status.totalDeepWorkToday + activeDeepWorkSecs;
        }

        for (final c in deepWorkClients) {
          for (final h in c.history) {
            if (h.seconds < 60) continue;
            final dt = _parseEntryDate(h);
            if (dt != null) {
              final r = getHourRow(dt.hour);
              final col = dt.weekday - 1;
              heatmapGrid[r][col] += h.seconds;
            }
          }
        }

        int maxHeatmapSecs = 0;
        int peakHeatmapRow = 0;
        for (int r = 0; r < 5; r++) {
          for (int c = 0; c < 7; c++) {
            if (heatmapGrid[r][c] > maxHeatmapSecs) {
              maxHeatmapSecs = heatmapGrid[r][c];
              peakHeatmapRow = r;
            }
          }
        }

        final allTimeFocusBlocks = deepWorkClients.fold<int>(0, (sum, c) => sum + c.history.length + (c.totalSecondsToday >= 60 ? 1 : 0));

        final String heatmapTitle = maxHeatmapSecs > 0
            ? 'The ${timeRowLabels[peakHeatmapRow].toLowerCase()} focus.'
            : 'Focus distribution.';
        final String heatmapSubtitle = maxHeatmapSecs > 0
            ? "You're most consistent at ${timeRowLabels[peakHeatmapRow]}.\nThat's when you do your best work."
            : 'Track focus sessions to reveal your rhythm.';

        final String bestTimeValue = maxHeatmapSecs > 0 ? timeRowLabels[peakHeatmapRow] : '—';
        final String bestTimeSubtitle = maxHeatmapSecs > 0
            ? 'Avg. ${_formatDurationHoursMins(maxHeatmapSecs)}'
            : 'No sessions yet';
        final String allTimeBlocksValue = NumberFormat('#,###').format(allTimeFocusBlocks);

        return RefreshIndicator(
          onRefresh: () => tracker.refreshData(),
          color: AppTheme.accentPrimary,
          backgroundColor: AppTheme.bgCard,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==========================================
                // 1. "THE RECEIPTS" SECTION (Screenshot 2)
                // ==========================================
                Text('BY THE NUMBERS', style: AppTheme.technicalLabel()),
                const SizedBox(height: 4),
                Text(
                  'The receipts.',
                  style: AppTheme.editorialTitle(fontSize: 28, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  'A record of your focus, one day at a time.',
                  style: AppTheme.bodyLabel(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),

                // 2x3 Grid of Metric Cards (Screenshot 2)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(AppTheme.radiusDeck),
                    border: Border.all(color: AppTheme.borderSubtle, width: 1),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildReceiptCell(NumberFormat('#,###').format(totalMinsFocused), 'MINUTES FOCUSED')),
                          Container(width: 1, height: 50, color: AppTheme.borderSubtle),
                          Expanded(child: _buildReceiptCell(NumberFormat('#,###').format(totalSessions), 'SESSIONS')),
                        ],
                      ),
                      Divider(color: AppTheme.borderSubtle, height: 24),
                      Row(
                        children: [
                          Expanded(child: _buildReceiptCell('$streakDays', 'DEEP WORK DAYS')),
                          Container(width: 1, height: 50, color: AppTheme.borderSubtle),
                          Expanded(child: _buildReceiptCell(focusScore, 'FOCUS SCORE')),
                        ],
                      ),
                      Divider(color: AppTheme.borderSubtle, height: 24),
                      Row(
                        children: [
                          Expanded(child: _buildReceiptCell('$weeksCount', 'WEEKS & COUNTING')),
                          Container(width: 1, height: 50, color: AppTheme.borderSubtle),
                          Expanded(child: _buildReceiptCell(dailyAvgHrs, 'DAILY AVERAGE')),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Progress Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('0%', style: AppTheme.technicalLabel(fontSize: 9)),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: status.goalProgress.clamp(0.0, 1.0),
                                  backgroundColor: AppTheme.bgPanel,
                                  valueColor: AlwaysStoppedAnimation(AppTheme.accentSage),
                                  minHeight: 4,
                                ),
                              ),
                            ),
                          ),
                          Text('100%', style: AppTheme.technicalLabel(fontSize: 9)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // MOST PRODUCTIVE DAY CARD (Screenshot 2)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(AppTheme.radiusDeck),
                    border: Border.all(color: AppTheme.borderSubtle, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MOST PRODUCTIVE DAY', style: AppTheme.technicalLabel()),
                      const SizedBox(height: 4),
                      Text(peakDayTitle, style: AppTheme.editorialTitle(fontSize: 20)),
                      Text(peakDaySubtitle, style: AppTheme.bodyLabel(fontSize: 12, color: AppTheme.textSecondary)),
                      const SizedBox(height: 16),

                      // Day of week bars: M T W T F S S
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(7, (i) {
                          final double barHeight = maxDaySecs > 0 ? math.max(4.0, (weekdaySecs[i] / maxDaySecs) * 48.0) : 4.0;
                          final bool isPeak = i == peakDayIndex && maxDaySecs > 0;
                          return _buildDayBar(weekdayChars[i], barHeight, isPeak);
                        }),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Editorial Quote
                Text(
                  '"Consistency turns intention into reality."',
                  style: AppTheme.editorialQuote(color: AppTheme.textMuted),
                ),

                const SizedBox(height: 24),

                // ==========================================
                // 2. SEPARATE STATS: TIME SINKS & DISTRACTIONS
                // ==========================================
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF453A).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFFF453A).withOpacity(0.4)),
                      ),
                      child: const Text(
                        'SEPARATE ACCOUNTING',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFF453A),
                          letterSpacing: 1.0,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('SHADOW TIME', style: AppTheme.technicalLabel()),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Time sinks & distractions.',
                  style: AppTheme.editorialTitle(fontSize: 28, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  'Activities tracked for brutal honesty. Never added to your deep work streak or goals.',
                  style: AppTheme.bodyLabel(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),

                // Dedicated Time Sink Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.isDark ? const Color(0xFF1E1113) : const Color(0xFFFFF5F5),
                    borderRadius: BorderRadius.circular(AppTheme.radiusDeck),
                    border: Border.all(
                      color: const Color(0xFFFF453A).withOpacity(0.35),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 2x2 Metric Grid for Time Sinks
                      Row(
                        children: [
                          Expanded(
                            child: _buildReceiptCell(
                              _formatDurationHoursMins(totalWasteSecsToday),
                              'SINK TIME TODAY',
                              valueColor: const Color(0xFFFF453A),
                            ),
                          ),
                          Container(width: 1, height: 50, color: const Color(0xFFFF453A).withOpacity(0.2)),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12.0),
                              child: _buildReceiptCell(
                                _formatDurationHoursMins(totalWasteSecsAllTime),
                                'ALL-TIME SINK',
                                valueColor: const Color(0xFFFF453A),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Divider(color: const Color(0xFFFF453A).withOpacity(0.2), height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _buildReceiptCell(
                              '$totalWasteSessions',
                              'SINK SESSIONS',
                              valueColor: const Color(0xFFFF8A80),
                            ),
                          ),
                          Container(width: 1, height: 50, color: const Color(0xFFFF453A).withOpacity(0.2)),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12.0),
                              child: _buildReceiptCell(
                                '$purityPct%',
                                'FOCUS PURITY',
                                valueColor: purityPct >= 85
                                    ? AppTheme.accentSage
                                    : (purityPct >= 65 ? AppTheme.accentPrimary : const Color(0xFFFF453A)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Comparative Ratio Split Bar
                      Text('TODAY: FOCUS VS. TIME SINK RATIO', style: AppTheme.technicalLabel(fontSize: 9)),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: SizedBox(
                          height: 8,
                          child: Row(
                            children: [
                              if (deepWorkRatio > 0)
                                Expanded(
                                  flex: (deepWorkRatio * 100).round(),
                                  child: Container(
                                    color: AppTheme.accentSage,
                                  ),
                                ),
                              if (wasteRatio > 0)
                                Expanded(
                                  flex: (wasteRatio * 100).round(),
                                  child: Container(
                                    color: const Color(0xFFFF453A),
                                  ),
                                ),
                              if (deepWorkRatio == 0 && wasteRatio == 0)
                                Expanded(
                                  child: Container(color: AppTheme.bgPanel),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(width: 7, height: 7, decoration: BoxDecoration(color: AppTheme.accentSage, shape: BoxShape.circle)),
                              const SizedBox(width: 4),
                              Text(
                                'Deep Work: ${(deepWorkSecsToday / 3600).toStringAsFixed(1)}h (${(deepWorkRatio * 100).toStringAsFixed(0)}%)',
                                style: AppTheme.technicalLabel(fontSize: 9),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFFFF453A), shape: BoxShape.circle)),
                              const SizedBox(width: 4),
                              Text(
                                'Sink: ${(totalWasteSecsToday / 3600).toStringAsFixed(1)}h (${(wasteRatio * 100).toStringAsFixed(0)}%)',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFFF453A),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      Divider(color: const Color(0xFFFF453A).withOpacity(0.2), height: 1),
                      const SizedBox(height: 12),

                      // Time Sink Activity Breakdown
                      Text('LOGGED TIME SINK TAGS', style: AppTheme.technicalLabel(fontSize: 9.5)),
                      const SizedBox(height: 8),

                      if (negativeClients.isEmpty) ...[
                        Text(
                          'No time sink tags created yet.\nUse Cockpit to add activities like YouTube, Reels, or Gaming.',
                          style: AppTheme.bodyLabel(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ] else ...[
                        ...negativeClients.map((client) {
                          final cHrsToday = (client.totalSecondsToday / 3600).toStringAsFixed(1);
                          final cHrsAll = (client.totalAccumulatedSecs / 3600).toStringAsFixed(1);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.isDark ? const Color(0xFF281316) : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFF453A).withOpacity(0.35)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF453A).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: const Text(
                                    'SINK',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFFF453A),
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        client.name,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.isDark ? const Color(0xFFFF9E94) : const Color(0xFFC92A2A),
                                        ),
                                      ),
                                      Text(
                                        '${client.reps} logged sessions',
                                        style: AppTheme.technicalLabel(fontSize: 8.5, color: AppTheme.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${cHrsToday}h today',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFFF453A),
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    Text(
                                      '${cHrsAll}h total',
                                      style: AppTheme.technicalLabel(fontSize: 8.5, color: AppTheme.textMuted),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ==========================================
                // 3. "THE SHAPE OF YOUR FOCUS" (Screenshot 3)
                // ==========================================
                Text('PATTERNS OVER TIME', style: AppTheme.technicalLabel()),
                const SizedBox(height: 4),
                Text(
                  'The shape of your focus.',
                  style: AppTheme.editorialTitle(fontSize: 28, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  "Some days are peaks, some are valleys.\nIt's all part of the process.",
                  style: AppTheme.bodyLabel(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),

                // Filter switcher: [ Days ] [ Weeks ] [ Months ] [ Years ]
                Row(
                  children: ['Days', 'Weeks', 'Months', 'Years'].asMap().entries.map((e) {
                    final isSel = _selectedFilterIndex == e.key;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: InkWell(
                        onTap: () => setState(() => _selectedFilterIndex = e.key),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMicro),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSel ? AppTheme.accentPrimary : AppTheme.bgCard,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMicro),
                            border: Border.all(
                              color: isSel ? AppTheme.accentPrimary : AppTheme.borderSubtle,
                            ),
                          ),
                          child: Text(
                            e.value,
                            style: isSel
                                ? AppTheme.uiButton(fontSize: 11, color: AppTheme.onPrimaryAccent)
                                : AppTheme.bodyLabel(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Trajectory Histogram with Peak Highlight
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(AppTheme.radiusDeck),
                    border: Border.all(color: AppTheme.borderSubtle, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Peak tag
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.bgPanel,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppTheme.borderSubtle),
                          ),
                          child: Text(
                            maxBucketSecs > 0 ? _formatDurationHoursMins(maxBucketSecs) : '0h 00m',
                            style: AppTheme.technicalLabel(fontSize: 10, color: AppTheme.accentPrimary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Dynamic Histogram
                      SizedBox(
                        height: 90,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(numBuckets, (i) {
                            final double h = maxBucketSecs > 0 ? math.max(4.0, (bucketSecs[i] / maxBucketSecs) * 80.0) : 4.0;
                            final bool isMax = maxBucketSecs > 0 && bucketSecs[i] == maxBucketSecs;
                            final double barWidth = numBuckets <= 4 ? 24.0 : (numBuckets <= 8 ? 16.0 : 10.0);
                            return Container(
                              width: barWidth,
                              height: h,
                              decoration: BoxDecoration(
                                color: isMax
                                    ? AppTheme.accentPrimary
                                    : (bucketSecs[i] > 0
                                        ? AppTheme.accentSage.withOpacity(0.65)
                                        : AppTheme.bgPanel),
                                borderRadius: BorderRadius.circular(2),
                                border: bucketSecs[i] == 0 ? Border.all(color: AppTheme.borderSubtle, width: 0.5) : null,
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 8),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: bucketLabels
                            .map((label) => Text(label, style: AppTheme.technicalLabel(fontSize: 9)))
                            .toList(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // TOTAL THIS MONTH CARD
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(AppTheme.radiusDeck),
                    border: Border.all(color: AppTheme.borderSubtle, width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TOTAL THIS MONTH', style: AppTheme.technicalLabel()),
                          const SizedBox(height: 4),
                          Text(thisMonthFormatted, style: AppTheme.editorialTitle(fontSize: 22)),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(monthTrendIcon, size: 24, color: monthTrendColor),
                          const SizedBox(width: 4),
                          Text(monthTrendText, style: AppTheme.technicalLabel(color: monthTrendColor, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Botanical Editorial Quote
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '"Progress isn\'t linear, but it always compounds."\n— CRANIUM',
                        style: AppTheme.editorialQuote(color: AppTheme.textMuted),
                      ),
                    ),
                    Icon(Icons.spa_outlined, size: 28, color: AppTheme.accentSage.withOpacity(0.5)),
                  ],
                ),

                const SizedBox(height: 24),

                // ==========================================
                // 3. "THE 9PM SPIKE" / FOCUS RHYTHM HEATMAP
                // ==========================================
                Text('WHEN WE FOCUS', style: AppTheme.technicalLabel()),
                const SizedBox(height: 4),
                Text(
                  heatmapTitle,
                  style: AppTheme.editorialTitle(fontSize: 28, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  heatmapSubtitle,
                  style: AppTheme.bodyLabel(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),

                // Heatmap Grid: Hours (12 AM, 6 AM, 12 PM, 6 PM, 9 PM) x Days (M T W T F S S)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(AppTheme.radiusDeck),
                    border: Border.all(color: AppTheme.borderSubtle, width: 1),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 40),
                          ...['M', 'T', 'W', 'T', 'F', 'S', 'S'].map(
                            (day) => Expanded(
                              child: Center(
                                child: Text(day, style: AppTheme.technicalLabel(fontSize: 10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      ...timeRowLabels.asMap().entries.map((row) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 40,
                                child: Text(row.value, style: AppTheme.technicalLabel(fontSize: 8.5)),
                              ),
                              ...List.generate(7, (col) {
                                final secs = heatmapGrid[row.key][col];
                                Color cellColor;
                                if (maxHeatmapSecs == 0 || secs == 0) {
                                  cellColor = AppTheme.bgPanel;
                                } else if (secs == maxHeatmapSecs) {
                                  cellColor = AppTheme.accentPrimary;
                                } else if (secs >= maxHeatmapSecs * 0.4) {
                                  cellColor = AppTheme.accentSage.withOpacity(0.65);
                                } else {
                                  cellColor = AppTheme.accentSage.withOpacity(0.3);
                                }

                                return Expanded(
                                  child: Container(
                                    height: 16,
                                    margin: const EdgeInsets.all(1.5),
                                    decoration: BoxDecoration(
                                      color: cellColor,
                                      borderRadius: BorderRadius.circular(2),
                                      border: (maxHeatmapSecs == 0 || secs == 0)
                                          ? Border.all(color: AppTheme.borderSubtle.withOpacity(0.4), width: 0.5)
                                          : null,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Best Time & All Time side-by-side
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(AppTheme.radiusDeck),
                          border: Border.all(color: AppTheme.borderSubtle),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('BEST TIME', style: AppTheme.technicalLabel(fontSize: 9)),
                            const SizedBox(height: 4),
                            Text(bestTimeValue, style: AppTheme.editorialTitle(fontSize: 18)),
                            Text(bestTimeSubtitle, style: AppTheme.bodyLabel(fontSize: 11, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(AppTheme.radiusDeck),
                          border: Border.all(color: AppTheme.borderSubtle),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ALL TIME', style: AppTheme.technicalLabel(fontSize: 9)),
                            const SizedBox(height: 4),
                            Text(allTimeBlocksValue, style: AppTheme.editorialTitle(fontSize: 18)),
                            Text('Focus blocks', style: AppTheme.bodyLabel(fontSize: 11, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ==========================================
                // 4. DATA LOGISTICS & CSV BACKUP
                // ==========================================
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(AppTheme.radiusDeck),
                    border: Border.all(color: AppTheme.borderSubtle, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DATA ARCHIVE & BACKUP', style: AppTheme.technicalLabel()),
                      const SizedBox(height: 6),
                      Text(
                        'Export or restore full telemetry history and focus records.',
                        style: AppTheme.bodyLabel(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.share_outlined, size: 15),
                              label: const Text('EXPORT CSV', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.accentPrimary,
                                side: BorderSide(color: AppTheme.accentPrimary.withOpacity(0.5)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: _isExporting
                                  ? null
                                  : () async {
                                      setState(() => _isExporting = true);
                                      try {
                                        final csv = await CsvExportService.generateSessionsCsv(
                                          status: status,
                                          host: tracker.isOnline ? tracker.host : null,
                                        );
                                        await CsvExportService.shareCsvFile(csvContent: csv, filenamePrefix: 'sessions');
                                      } finally {
                                        setState(() => _isExporting = false);
                                      }
                                    },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.download_rounded, size: 15),
                              label: const Text('RESTORE DATA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentPrimary,
                                foregroundColor: AppTheme.onPrimaryAccent,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: () => ImportDataDialog.show(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReceiptCell(String value, String label, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppTheme.largeMetric(fontSize: 22, color: valueColor),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTheme.technicalLabel(fontSize: 9),
        ),
      ],
    );
  }

  String _formatDurationHoursMins(int totalSecs) {
    if (totalSecs <= 0) return '0m';
    final hrs = totalSecs ~/ 3600;
    final mins = (totalSecs % 3600) ~/ 60;
    if (hrs > 0) {
      return '${hrs}h ${mins}m';
    }
    return '${mins}m';
  }

  Widget _buildDayBar(String day, double height, bool isPeak) {
    return Column(
      children: [
        Container(
          width: 18,
          height: height,
          decoration: BoxDecoration(
            color: isPeak ? AppTheme.accentPrimary : AppTheme.accentSage.withOpacity(0.7),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(height: 6),
        Text(day, style: AppTheme.technicalLabel(fontSize: 10)),
      ],
    );
  }

  DateTime? _parseEntryDate(HistoryEntry entry) {
    if (entry.timestamp.isNotEmpty) {
      final dt = DateTime.tryParse(entry.timestamp.replaceAll(' ', 'T'));
      if (dt != null) return dt;
    }
    if (entry.date.isNotEmpty) {
      try {
        return DateFormat('d MMM yyyy').parseLoose(entry.date);
      } catch (_) {}
      try {
        return DateFormat('dd MMM yyyy').parseLoose(entry.date);
      } catch (_) {}
    }
    return null;
  }
}
