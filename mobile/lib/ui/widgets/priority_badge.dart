import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class PriorityBadge extends StatelessWidget {
  final int stars;
  final double size;

  const PriorityBadge({
    super.key,
    required this.stars,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = stars.clamp(1, 3);
    Color color;
    switch (clamped) {
      case 3:
        color = AppTheme.orangeFlame;
        break;
      case 2:
        color = AppTheme.warningGold;
        break;
      default:
        color = AppTheme.cyanTelemetry;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          clamped,
          (index) => Icon(
            Icons.star_rounded,
            size: size,
            color: color,
          ),
        ),
      ),
    );
  }
}
