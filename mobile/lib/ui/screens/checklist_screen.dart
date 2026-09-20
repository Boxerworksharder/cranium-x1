import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/checklist_item.dart';
import '../../state/tracker_provider.dart';

class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  final TextEditingController _textCtrl = TextEditingController();

  void _showAddItemSheet(BuildContext context, TrackerProvider tracker) {
    if (tracker.checklist.length >= 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checklist is full (maximum 20 items for device sync)')),
      );
      return;
    }
    _textCtrl.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceOverlay,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
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
                    'NEW CHECKLIST ITEM',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: AppTheme.accentPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _textCtrl,
                autofocus: true,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'What is the item?',
                  hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: AppTheme.surfaceRecessed,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (value) {
                  final text = value.trim();
                  if (text.isNotEmpty) {
                    final newList = List<ChecklistItem>.from(tracker.checklist);
                    newList.add(ChecklistItem(id: DateTime.now().millisecondsSinceEpoch, text: text, done: false));
                    tracker.saveChecklist(newList);
                  }
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final text = _textCtrl.text.trim();
                    if (text.isNotEmpty) {
                      final newList = List<ChecklistItem>.from(tracker.checklist);
                      newList.add(ChecklistItem(id: DateTime.now().millisecondsSinceEpoch, text: text, done: false));
                      tracker.saveChecklist(newList);
                    }
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('ADD ITEM', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, ChecklistItem item, TrackerProvider tracker) {
    AppTheme.hapticAction();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Delete Item',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          content: Text(
            'Delete "${item.text}" from checklist?',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'CANCEL',
                style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: () {
                final newList = List<ChecklistItem>.from(tracker.checklist);
                newList.removeWhere((e) => e.id == item.id);
                tracker.saveChecklist(newList);
                Navigator.pop(ctx);
                AppTheme.hapticAction();
              },
              child: Text(
                'DELETE',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        );
      },
    );
  }

  void _resetChecklist(BuildContext context, TrackerProvider tracker) {
    AppTheme.hapticAction();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Reset Checklist',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          content: Text(
            'Un-check all items in the list?',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'CANCEL',
                style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: () {
                final newList = tracker.checklist.map((e) => e.copyWith(done: false)).toList();
                tracker.saveChecklist(newList);
                Navigator.pop(ctx);
                AppTheme.hapticAction();
              },
              child: Text(
                'RESET',
                style: TextStyle(color: AppTheme.orangeFlame, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tracker = context.watch<TrackerProvider>();
    final checklist = tracker.checklist;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${checklist.where((e) => e.done).length} / ${checklist.length} Completed',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              Row(
                children: [
                  if (checklist.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.refresh_rounded, color: AppTheme.orangeFlame, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 20,
                      onPressed: () => _resetChecklist(context, tracker),
                    ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: Icon(Icons.add_circle_outline, color: AppTheme.accentPrimary, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 20,
                    onPressed: () => _showAddItemSheet(context, tracker),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: checklist.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.checklist_rounded, size: 48, color: AppTheme.borderSubtle),
                      const SizedBox(height: 16),
                      Text(
                        'NO CHECKLIST ITEMS',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create items to track repeatable procedures.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('NEW ITEM'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.accentPrimary,
                          side: BorderSide(color: AppTheme.accentPrimary.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusCapsule)),
                        ),
                        onPressed: () => _showAddItemSheet(context, tracker),
                      ),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: checklist.length,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    final newList = List<ChecklistItem>.from(checklist);
                    final item = newList.removeAt(oldIndex);
                    newList.insert(newIndex, item);
                    tracker.saveChecklist(newList);
                  },
                  itemBuilder: (ctx, idx) {
                    final item = checklist[idx];
                    return _buildChecklistItem(context, item, tracker, key: ValueKey(item.id));
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildChecklistItem(BuildContext context, ChecklistItem item, TrackerProvider tracker, {required Key key}) {
    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceRecessed,
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        border: Border.all(color: AppTheme.hairlineSeam),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: InkWell(
          onTap: () {
            AppTheme.hapticSelection();
            final newList = List<ChecklistItem>.from(tracker.checklist);
            final index = newList.indexWhere((e) => e.id == item.id);
            if (index >= 0) {
              newList[index] = item.copyWith(done: !item.done);
              tracker.saveChecklist(newList);
            }
          },
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: item.done ? AppTheme.accentPrimary : Colors.transparent,
              border: Border.all(
                color: item.done ? AppTheme.accentPrimary : AppTheme.borderSubtle,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: item.done
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : null,
          ),
        ),
        title: Text(
          item.text,
          style: TextStyle(
            color: item.done ? AppTheme.textMuted : AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: item.done ? FontWeight.w500 : FontWeight.w600,
            decoration: item.done ? TextDecoration.lineThrough : null,
            decorationColor: AppTheme.textMuted,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.delete_outline, color: AppTheme.textMuted, size: 20),
              splashRadius: 20,
              onPressed: () => _confirmDelete(context, item, tracker),
            ),
            Icon(Icons.drag_handle_rounded, color: AppTheme.borderSubtle, size: 20),
          ],
        ),
      ),
    );
  }
}
