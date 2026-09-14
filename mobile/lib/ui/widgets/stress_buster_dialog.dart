import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';

class StressBusterDialog extends StatefulWidget {
  const StressBusterDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Stress Buster',
      barrierColor: Colors.black.withOpacity(0.85),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) => const StressBusterDialog(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(anim1.value),
          child: Opacity(
            opacity: anim1.value,
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<StressBusterDialog> createState() => _StressBusterDialogState();
}

class _StressBusterDialogState extends State<StressBusterDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _lastHapticPhase = -1;

  @override
  void initState() {
    super.initState();
    // 2-Minute guided breathing timeline (6 cycles × 20s)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 120),
    );

    _controller.addListener(() {
      setState(() {});
      _handleHaptics();
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        HapticFeedback.mediumImpact();
        Future.delayed(const Duration(milliseconds: 100), () {
          HapticFeedback.heavyImpact();
        });
      }
    });

    _controller.forward();

    // Initial gentle tactile pulse
    HapticFeedback.mediumImpact();
  }

  void _handleHaptics() {
    final double elapsedSec = _controller.value * 120.0;
    final double cycleElapsed = elapsedSec % 20.0;

    // Phase 1 (0 - 6s per cycle): Inhale pulses every ~1.5s
    if (cycleElapsed < 6.0) {
      int phase = (elapsedSec / 1.5).floor();
      if (phase != _lastHapticPhase) {
        _lastHapticPhase = phase;
        HapticFeedback.lightImpact();
      }
    }
    // Phase 2 (6 - 10s per cycle): Hold (quiet stillness)
    else if (cycleElapsed < 10.0) {
      _lastHapticPhase = -2; // reset for next phase transition
    }
    // Phase 3 (10 - 20s per cycle): Exhale pulses every ~2s
    else {
      int phase = 1000 + (elapsedSec / 2.0).floor();
      if (phase != _lastHapticPhase) {
        _lastHapticPhase = phase;
        HapticFeedback.selectionClick();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsedSec = _controller.value * 20.0;
    final remSec = math.max(1, (20.0 - elapsedSec).ceil());
    final isDone = _controller.isCompleted;

    String phaseText;
    String instructionText;
    Color phaseColor;

    if (elapsedSec < 6.0) {
      phaseText = 'INHALE';
      instructionText = 'Deep breath in through your nose...';
      phaseColor = AppTheme.cyanTelemetry;
    } else if (elapsedSec < 10.0) {
      phaseText = 'HOLD';
      instructionText = 'Hold stillness gently...';
      phaseColor = AppTheme.warningGold;
    } else if (!isDone) {
      phaseText = 'EXHALE';
      instructionText = 'Smooth, slow release...let go...';
      phaseColor = AppTheme.orangeFlame;
    } else {
      phaseText = 'TRANQUIL';
      instructionText = 'Zen reset complete. Clarity restored.';
      phaseColor = AppTheme.emeraldGreen;
    }

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.bgPanel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: phaseColor.withOpacity(0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: phaseColor.withOpacity(0.25),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header — minimal, no title, just countdown pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.spa_rounded, size: 18, color: phaseColor.withOpacity(0.7)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: phaseColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: phaseColor.withOpacity(0.5)),
                    ),
                    child: Text(
                      isDone ? 'DONE' : '${remSec}s',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: phaseColor,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Animated Breathing Lotus Mandala
              SizedBox(
                width: 170,
                height: 170,
                child: CustomPaint(
                  painter: _LotusBreathingPainter(
                    progress: _controller.value,
                    color: phaseColor,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isDone ? '✨' : '$remSec',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textPrimary,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          phaseText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: phaseColor,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Dynamic Subtitle prompt
              Text(
                instructionText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Fluid Linear 20-Second Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _controller.value,
                  backgroundColor: AppTheme.bgSurface,
                  valueColor: AlwaysStoppedAnimation<Color>(phaseColor),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppTheme.borderSubtle),
                        foregroundColor: AppTheme.textMuted,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        isDone ? 'CLOSE' : 'CANCEL',
                        style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.8),
                      ),
                    ),
                  ),
                  if (isDone) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: phaseColor,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          _controller.reset();
                          _lastHapticPhase = -1;
                          _controller.forward();
                        },
                        child: const Text(
                          'REPEAT',
                          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LotusBreathingPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0 (over 20 seconds)
  final Color color;

  _LotusBreathingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final elapsedSec = progress * 20.0;

    // Radius progression:
    // 0 - 6s: Inhale (radius: 26 -> 66, eased)
    // 6 - 10s: Hold (radius: 66 with subtle pulse)
    // 10 - 20s: Exhale (radius: 66 -> 26, eased)
    double radius;
    if (elapsedSec < 6.0) {
      final p = elapsedSec / 6.0;
      final eased = 0.5 - 0.5 * math.cos(p * math.pi);
      radius = 26.0 + (eased * 40.0);
    } else if (elapsedSec < 10.0) {
      final p = (elapsedSec - 6.0) / 4.0;
      final pulse = math.sin(p * math.pi * 2) * 2.0;
      radius = 66.0 + pulse;
    } else {
      final p = (elapsedSec - 10.0) / 10.0;
      final eased = 0.5 - 0.5 * math.cos(p * math.pi);
      radius = 66.0 - (eased * 40.0);
      if (radius < 26.0) radius = 26.0;
    }

    // Outer Progress Ring (0 to 1)
    final ringPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, 78, ringPaint);

    final activeRingPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 78),
      -math.pi / 2,
      progress * 2 * math.pi,
      false,
      activeRingPaint,
    );

    // Expanding / Contracting Aura
    final auraPaint = Paint()
      ..color = color.withOpacity(0.12)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, auraPaint);

    final auraBorderPaint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, auraBorderPaint);

    // Inner Concentric Ring
    if (radius > 36) {
      final innerRingPaint = Paint()
        ..color = color.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(center, radius - 12, innerRingPaint);
    }

    // Rotating Lotus Petal Dots — slower, meditative rotation
    final double rotAngle = progress * 3 * math.pi; // 1.5 revolutions over 20s
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 8; i++) {
      final a = rotAngle + (i * (math.pi / 4));
      final px = center.dx + (math.cos(a) * (radius - 2));
      final py = center.dy + (math.sin(a) * (radius - 2));
      canvas.drawCircle(Offset(px, py), 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LotusBreathingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
