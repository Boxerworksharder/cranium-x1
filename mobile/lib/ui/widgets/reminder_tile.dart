import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/reminder_item.dart';

class ReminderTile extends StatelessWidget {
  final ReminderItem reminder;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;

  const ReminderTile({
    super.key,
    required this.reminder,
    required this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('reminder_${reminder.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        AppTheme.hapticLight();
        onDelete();
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.dangerCrimson.withOpacity(0.85),
          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDeck,
          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
          border: Border.all(
            color: AppTheme.hairlineSeam,
            width: 0.8,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Glowing cyan bullet (no tick/checkbox)
            Padding(
              padding: const EdgeInsets.only(top: 5, right: 12),
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: AppTheme.cyanTelemetry,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.cyanTelemetry.withOpacity(0.6),
                      blurRadius: 5,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
            // Text content
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onEdit,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.text,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    if (reminder.createdAt.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        reminder.createdAt,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9.5,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (onEdit != null) ...[
              IconButton(
                icon: Icon(Icons.edit_outlined, size: 16, color: AppTheme.textMuted.withOpacity(0.7)),
                tooltip: 'Edit note',
                onPressed: () {
                  AppTheme.hapticLight();
                  onEdit!();
                },
                splashRadius: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
            ],
            // Delete button
            IconButton(
              icon: Icon(Icons.close_rounded, size: 16, color: AppTheme.textMuted.withOpacity(0.6)),
              tooltip: 'Delete note',
              onPressed: () {
                AppTheme.hapticLight();
                onDelete();
              },
              splashRadius: 16,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
