import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/task_item.dart';
import 'priority_badge.dart';

class TaskTile extends StatelessWidget {
  final TaskItem task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;

  const TaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('task_${task.id}'),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: task.done ? AppTheme.surfaceRecessed.withOpacity(0.4) : AppTheme.surfaceDeck,
          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
          border: Border.all(
            color: task.done
                ? AppTheme.hairlineSeam.withOpacity(0.4)
                : AppTheme.hairlineSeam,
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            // Studio Mechanical Tactile Checkbox
            GestureDetector(
              onTap: () {
                AppTheme.hapticAction();
                onToggle();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: task.done ? AppTheme.emeraldLive : AppTheme.surfaceRecessed,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMicro + 1),
                  border: Border.all(
                    color: task.done
                        ? AppTheme.emeraldLive
                        : AppTheme.textMuted.withOpacity(0.4),
                    width: 1.2,
                  ),
                ),
                child: task.done
                    ? const Icon(Icons.check_rounded, size: 14, color: Colors.black)
                    : null,
              ),
            ),
            const SizedBox(width: 12),

            // Priority Stars Badge
            PriorityBadge(stars: task.stars, size: 11),
            const SizedBox(width: 10),

            // Task Text Hierarchy with tap to edit
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onEdit,
                child: Text(
                  task.text,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: task.done ? FontWeight.w400 : FontWeight.w600,
                    color: task.done ? AppTheme.textMuted : AppTheme.textPrimary,
                    decoration: task.done ? TextDecoration.lineThrough : null,
                    decorationColor: AppTheme.textMuted,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ),

            if (onEdit != null) ...[
              IconButton(
                icon: Icon(Icons.edit_outlined, size: 16, color: AppTheme.textMuted.withOpacity(0.7)),
                tooltip: 'Edit task',
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

            // Clean Delete Button
            IconButton(
              icon: Icon(Icons.close_rounded, size: 16, color: AppTheme.textMuted.withOpacity(0.6)),
              tooltip: 'Delete task',
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
