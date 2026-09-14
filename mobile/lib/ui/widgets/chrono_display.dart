import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/device_status.dart';
import '../../state/tracker_provider.dart' show TimerMode;
import 'stress_buster_dialog.dart';

class ChronoDisplay extends StatefulWidget {
  final int totalSeconds;
  final TrackerState state;
  final TimerMode timerMode;
  final int countdownTargetMinutes;
  final int remainingSeconds;
  final String activeSectionName;
  final bool isNegative;
  final VoidCallback? onToggleMode;
  final ValueChanged<int>? onSelectCountdownMinutes;
  final VoidCallback? onStart;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onStop;

  const ChronoDisplay({
    super.key,
    required this.totalSeconds,
    required this.state,
    this.timerMode = TimerMode.countUp,
    this.countdownTargetMinutes = 25,
    this.remainingSeconds = 1500,
    this.activeSectionName = 'Deep work',
    this.isNegative = false,
    this.onToggleMode,
    this.onSelectCountdownMinutes,
    this.onStart,
    this.onPause,
    this.onResume,
    this.onStop,
  });

  @override
  State<ChronoDisplay> createState() => _ChronoDisplayState();
}

class _ChronoDisplayState extends State<ChronoDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isAmbientPlaying = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    if (widget.state == TrackerState.tracking) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant ChronoDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == TrackerState.tracking) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _formatTime(int sec) {
    final hrs = sec ~/ 3600;
    final mins = (sec % 3600) ~/ 60;
    final secs = sec % 60;
    if (hrs > 0) {
      return '${hrs.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  double get _progress {
    if (widget.timerMode == TimerMode.countDown) {
      final total = widget.countdownTargetMinutes * 60;
      if (total <= 0) return 0.0;
      final elapsed = total - widget.remainingSeconds;
      return (elapsed / total).clamp(0.0, 1.0);
    } else {
      // 60-minute continuous loop for count-up
      return ((widget.totalSeconds % 3600) / 3600.0).clamp(0.0, 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTracking = widget.state == TrackerState.tracking;
    final isPaused = widget.state == TrackerState.paused;
    final displaySecs = widget.timerMode == TimerMode.countDown
        ? widget.remainingSeconds
        : widget.totalSeconds;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusDeck),
        border: Border.all(color: AppTheme.borderSubtle, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mode Pill & Duration Preset Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: widget.onToggleMode,
                borderRadius: BorderRadius.circular(AppTheme.radiusCapsule),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.bgPanel,
                    borderRadius: BorderRadius.circular(AppTheme.radiusCapsule),
                    border: Border.all(
                      color: AppTheme.borderSubtle,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.timerMode == TimerMode.countDown
                            ? Icons.hourglass_bottom_rounded
                            : Icons.timer_outlined,
                        size: 13,
                        color: AppTheme.accentPrimary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        widget.timerMode == TimerMode.countDown
                            ? 'COUNTDOWN · ${widget.countdownTargetMinutes}M'
                            : 'STOPWATCH',
                        style: AppTheme.technicalLabel(
                          color: AppTheme.accentPrimary,
                          fontSize: 10,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Status indicator dot
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.isNegative
                      ? const Color(0xFFFF453A).withOpacity(0.18)
                      : (isTracking
                          ? AppTheme.accentSage.withOpacity(0.15)
                          : (isPaused ? AppTheme.accentPrimary.withOpacity(0.15) : AppTheme.bgPanel)),
                  borderRadius: BorderRadius.circular(AppTheme.radiusCapsule),
                  border: Border.all(
                    color: widget.isNegative
                        ? const Color(0xFFFF453A).withOpacity(0.45)
                        : (isTracking
                            ? AppTheme.accentSage.withOpacity(0.4)
                            : (isPaused ? AppTheme.accentPrimary.withOpacity(0.4) : AppTheme.borderSubtle)),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.isNegative
                            ? const Color(0xFFFF453A)
                            : (isTracking
                                ? AppTheme.accentSage
                                : (isPaused ? AppTheme.accentPrimary : AppTheme.textMuted)),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      widget.isNegative
                          ? (isTracking ? 'TRACKING SINK' : (isPaused ? 'SINK PAUSED' : 'TIME SINK READY'))
                          : (isTracking ? 'ACTIVE' : (isPaused ? 'PAUSED' : 'READY')),
                      style: AppTheme.technicalLabel(
                        color: widget.isNegative
                            ? const Color(0xFFFF453A)
                            : (isTracking
                                ? AppTheme.accentSage
                                : (isPaused ? AppTheme.accentPrimary : AppTheme.textMuted)),
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Preset Chips if Down-Timer
          if (widget.timerMode == TimerMode.countDown && widget.state == TrackerState.idle) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [15, 25, 45, 60].map((mins) {
                final isSelected = widget.countdownTargetMinutes == mins;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: InkWell(
                    onTap: () => widget.onSelectCountdownMinutes?.call(mins),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMicro),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.accentPrimary : AppTheme.bgPanel,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMicro),
                        border: Border.all(
                          color: isSelected ? AppTheme.accentPrimary : AppTheme.borderSubtle,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        mins == 25 ? '25m POMO' : '${mins}m',
                        style: isSelected
                            ? AppTheme.uiButton(fontSize: 11, color: AppTheme.onPrimaryAccent)
                            : AppTheme.bodyLabel(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 20),

          // THE RADIAL DIAL GAUGE (Screen 6 Editorial Clock)
          Center(
            child: SizedBox(
              width: 250,
              height: 250,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Animated or Static Custom Painter for Radial Ticks
                  CustomPaint(
                    size: const Size(250, 250),
                    painter: RadialDialPainter(
                      progress: _progress,
                      activeColor: widget.isNegative
                          ? const Color(0xFFFF453A)
                          : (isTracking ? AppTheme.accentPrimary : AppTheme.accentSage),
                      inactiveColor: AppTheme.isDark
                          ? (widget.isNegative ? const Color(0xFF2C1619) : const Color(0xFF23252A))
                          : (widget.isNegative ? const Color(0xFFFFE5E5) : const Color(0xFFDBD5C9)),
                      highlightDot: isTracking,
                    ),
                  ),

                  // Center Text Content
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.isNegative ? 'TIME SINK SESSION' : 'Focus Session',
                        style: AppTheme.bodyLabel(
                          fontSize: 12.5,
                          color: widget.isNegative ? const Color(0xFFFF453A) : AppTheme.textSecondary,
                          fontWeight: widget.isNegative ? FontWeight.w700 : FontWeight.w400,
                          letterSpacing: widget.isNegative ? 0.8 : 0.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(displaySecs),
                        style: AppTheme.editorialDisplayLarge(
                          fontSize: 48,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.isNegative) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              margin: const EdgeInsets.only(right: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF453A).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: const Color(0xFFFF453A).withOpacity(0.4)),
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
                          ],
                          Text(
                            widget.activeSectionName,
                            style: AppTheme.bodyLabel(
                              fontSize: 13,
                              color: widget.isNegative ? const Color(0xFFFF453A) : AppTheme.accentSage,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // TACTILE CONTROL ROW (3 Buttons: Ambient / Main Play-Pause / Zen Leaf)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. Ambient Audio Button
              InkWell(
                onTap: () {
                  AppTheme.hapticLight();
                  setState(() => _isAmbientPlaying = !_isAmbientPlaying);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _isAmbientPlaying
                            ? '♫ Rain & White Noise enabled'
                            : '♫ Ambient audio muted',
                        style: AppTheme.bodyLabel(color: Colors.white),
                      ),
                      duration: const Duration(seconds: 1),
                      backgroundColor: AppTheme.bgPanel,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isAmbientPlaying ? AppTheme.accentSage.withOpacity(0.2) : AppTheme.bgPanel,
                    border: Border.all(
                      color: _isAmbientPlaying ? AppTheme.accentSage : AppTheme.borderSubtle,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    _isAmbientPlaying ? Icons.music_note : Icons.music_note_outlined,
                    size: 20,
                    color: _isAmbientPlaying ? AppTheme.accentSage : AppTheme.textSecondary,
                  ),
                ),
              ),

              const SizedBox(width: 24),

              // 2. PRIMARY CIRCULAR PLAY / PAUSE BUTTON (64px)
              InkWell(
                onTap: () {
                  AppTheme.hapticAction();
                  if (isTracking) {
                    widget.onPause?.call();
                  } else if (isPaused) {
                    widget.onResume?.call();
                  } else {
                    widget.onStart?.call();
                  }
                },
                borderRadius: BorderRadius.circular(32),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isNegative
                        ? const Color(0xFFFF453A)
                        : (isPaused ? AppTheme.accentSage : AppTheme.accentPrimary),
                    boxShadow: [
                      BoxShadow(
                        color: (widget.isNegative
                                ? const Color(0xFFFF453A)
                                : (isPaused ? AppTheme.accentSage : AppTheme.accentPrimary))
                            .withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    isTracking ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 34,
                    color: AppTheme.onPrimaryAccent,
                  ),
                ),
              ),

              const SizedBox(width: 24),

              // 3. Mindfulness / Leaf Button (Triggers 2-Min Reset)
              InkWell(
                onTap: () {
                  AppTheme.hapticSelection();
                  StressBusterDialog.show(context);
                },
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.bgPanel,
                    border: Border.all(
                      color: AppTheme.borderSubtle,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.spa_outlined,
                    size: 20,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          if (isTracking || isPaused) ...[
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: () {
                AppTheme.hapticAction();
                widget.onStop?.call();
              },
              icon: Icon(Icons.stop_circle_outlined, size: 16, color: AppTheme.dangerCrimson),
              label: Text(
                'END & LOG SESSION',
                style: AppTheme.technicalLabel(
                  color: AppTheme.dangerCrimson,
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // CURRENT GOAL PILL / CARD
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: widget.isNegative ? const Color(0xFF281316) : AppTheme.bgPanel,
              borderRadius: BorderRadius.circular(AppTheme.radiusControl),
              border: Border.all(
                color: widget.isNegative ? const Color(0xFFFF453A).withOpacity(0.4) : AppTheme.borderSubtle,
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isNegative ? 'TIME SINK (EXCLUDED FROM DEEP WORK)' : 'CURRENT GOAL',
                      style: AppTheme.technicalLabel(
                        fontSize: 9.5,
                        color: widget.isNegative ? const Color(0xFFFF453A) : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.activeSectionName,
                      style: AppTheme.bodyLabel(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: widget.isNegative ? const Color(0xFFFF8A80) : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: widget.isNegative ? const Color(0xFFFF453A) : AppTheme.textMuted,
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Editorial Quote Footer
          Text(
            '"Distraction is expensive. Attention is a superpower."',
            textAlign: TextAlign.center,
            style: AppTheme.editorialQuote(
              fontSize: 13,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class RadialDialPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color activeColor;
  final Color inactiveColor;
  final bool highlightDot;

  RadialDialPainter({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    this.highlightDot = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const totalTicks = 72; // 72 ticks around circle (5 degrees each)

    final paintTick = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.fill;

    final activeCount = (totalTicks * progress).round();

    for (int i = 0; i < totalTicks; i++) {
      // Angle starting from top (-90 degrees)
      final angle = (i * 2 * math.pi / totalTicks) - (math.pi / 2);
      final isCardinal = (i % 18 == 0); // 12, 3, 6, 9 o'clock marks
      final isActive = i <= activeCount;

      final tickLength = isCardinal ? 8.0 : 4.0;
      final tickThickness = isCardinal ? 2.2 : 1.4;

      paintTick.color = isActive
          ? activeColor
          : (isCardinal ? inactiveColor.withOpacity(0.8) : inactiveColor.withOpacity(0.4));
      paintTick.strokeWidth = tickThickness;

      final startR = radius - tickLength;
      final endR = radius;

      final p1 = Offset(
        center.dx + startR * math.cos(angle),
        center.dy + startR * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + endR * math.cos(angle),
        center.dy + endR * math.sin(angle),
      );

      canvas.drawLine(p1, p2, paintTick);
    }

    // Draw active progress point / dot
    if (progress > 0.01) {
      final leadAngle = (activeCount * 2 * math.pi / totalTicks) - (math.pi / 2);
      final dotOffset = Offset(
        center.dx + (radius - 2) * math.cos(leadAngle),
        center.dy + (radius - 2) * math.sin(leadAngle),
      );

      final dotPaint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.fill;

      canvas.drawCircle(dotOffset, 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant RadialDialPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}
