import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/services/data_import_service.dart';
import '../../core/theme/app_theme.dart';
import '../../state/tracker_provider.dart';

class ImportDataDialog extends StatefulWidget {
  const ImportDataDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const ImportDataDialog(),
    );
  }

  @override
  State<ImportDataDialog> createState() => _ImportDataDialogState();
}

class _ImportDataDialogState extends State<ImportDataDialog> {
  final TextEditingController _textCtrl = TextEditingController();
  ImportPreviewResult? _preview;
  bool _overwrite = false;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _textCtrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textCtrl.removeListener(_onTextChanged);
    _textCtrl.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _preview = null);
      return;
    }
    final tracker = context.read<TrackerProvider>();
    final res = DataImportService.parseAndValidate(text, currentStatus: tracker.status);
    setState(() => _preview = res);
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _textCtrl.text = data.text!;
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Clipboard is empty or does not contain text.', style: AppTheme.bodyLabel(color: AppTheme.textPrimary)),
            backgroundColor: AppTheme.bgPanel,
          ),
        );
      }
    }
  }

  Future<void> _executeImport() async {
    if (_preview == null || !_preview!.isValid) return;

    setState(() => _isImporting = true);
    final tracker = context.read<TrackerProvider>();

    final success = await tracker.importData(
      preview: _preview!,
      overwrite: _overwrite,
    );

    if (!mounted) return;
    setState(() => _isImporting = false);

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _overwrite
                ? 'Full Data Restore Completed (${_preview!.sectionCount} sections, ${_preview!.recordsToAdd + _preview!.recordsToUpdate} records imported).'
                : 'Data Merge Completed! ${_preview!.recordsToAdd} added, ${_preview!.recordsToUpdate} updated.',
            style: AppTheme.bodyLabel(color: AppTheme.onPrimaryAccent, fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppTheme.accentSage,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Import failed. Please check payload formatting or device connection.',
            style: AppTheme.bodyLabel(color: Colors.white),
          ),
          backgroundColor: AppTheme.dangerCrimson,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.borderSubtle, width: 1),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Bar
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentPrimary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.accentPrimary.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download_rounded, size: 14, color: AppTheme.accentPrimary),
                      const SizedBox(width: 6),
                      Text(
                        'DATA BACKUP & RESTORE',
                        style: AppTheme.technicalLabel(
                          color: AppTheme.accentPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, size: 20, color: AppTheme.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Title & Subtitle
            Text(
              'Import Data & Sessions',
              style: AppTheme.editorialTitle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Paste a Cranium lossless JSON backup (v1/v2) or structured CSV logs to restore or merge into your diary.',
              style: AppTheme.bodyLabel(
                color: AppTheme.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),

            // Action Toolbar
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pasteFromClipboard,
                  icon: Icon(Icons.content_paste_rounded, size: 14, color: AppTheme.accentPrimary),
                  label: Text('PASTE CLIPBOARD', style: AppTheme.uiButton(fontSize: 11, color: AppTheme.accentPrimary)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppTheme.accentPrimary.withOpacity(0.4)),
                    backgroundColor: AppTheme.accentPrimary.withOpacity(0.06),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 10),
                if (_textCtrl.text.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _textCtrl.clear(),
                    icon: Icon(Icons.clear, size: 14, color: AppTheme.textMuted),
                    label: Text('CLEAR', style: AppTheme.bodyLabel(fontSize: 11, color: AppTheme.textMuted)),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Text Input Area
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppTheme.bgBase,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _preview == null
                              ? AppTheme.borderSubtle
                              : (_preview!.isValid
                                  ? AppTheme.accentSage.withOpacity(0.6)
                                  : AppTheme.dangerCrimson.withOpacity(0.6)),
                          width: 1.2,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: TextField(
                        controller: _textCtrl,
                        maxLines: null,
                        expands: true,
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: 11,
                          color: AppTheme.textPrimary,
                          height: 1.4,
                        ),
                        decoration: InputDecoration(
                          hintText: '// Paste JSON backup {"clients":[...]} or CSV rows (Date,Section,Duration_Secs...)...',
                          hintStyle: GoogleFonts.ibmPlexMono(
                            color: AppTheme.textMuted.withOpacity(0.7),
                            fontSize: 11,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Pre-Commit Preview & Diff Analytics Card
                    if (_preview != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _preview!.isValid
                              ? AppTheme.accentSage.withOpacity(0.08)
                              : AppTheme.dangerCrimson.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _preview!.isValid
                                ? AppTheme.accentSage.withOpacity(0.35)
                                : AppTheme.dangerCrimson.withOpacity(0.35),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header badge
                            Row(
                              children: [
                                Icon(
                                  _preview!.isValid ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                                  size: 16,
                                  color: _preview!.isValid ? AppTheme.accentSage : AppTheme.dangerCrimson,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _preview!.isValid
                                        ? '${_preview!.format} (v${_preview!.schemaVersion})'
                                        : 'VALIDATION ERROR',
                                    style: AppTheme.technicalLabel(
                                      color: _preview!.isValid ? AppTheme.accentSage : AppTheme.dangerCrimson,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            if (_preview!.isValid) ...[
                              // Diff 4-column metric grid
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.bgBase.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.borderSubtle),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildDiffMetric('FOUND', '${_preview!.recordsFound}', AppTheme.textPrimary),
                                    _buildDiffMetric('NEW (+)', '+${_preview!.recordsToAdd}', AppTheme.accentSage),
                                    _buildDiffMetric('UPDATE (~)', '~${_preview!.recordsToUpdate}', AppTheme.accentPrimary),
                                    _buildDiffMetric('EXISTING (=)', '=${_preview!.recordsAlreadyPresent}', AppTheme.textMuted),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Payload breakdown pills
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _buildDataPill('${_preview!.sectionCount} SECTIONS', AppTheme.accentPrimary),
                                  _buildDataPill('${_preview!.sessionCount} SESSIONS', AppTheme.accentPrimary),
                                  _buildDataPill(_preview!.totalDurationFormatted, AppTheme.accentSage),
                                  if (_preview!.tasks.isNotEmpty)
                                    _buildDataPill('${_preview!.tasks.length} TASKS', AppTheme.accentSage),
                                  if (_preview!.reminders.isNotEmpty)
                                    _buildDataPill('${_preview!.reminders.length} REMINDERS', AppTheme.textSecondary),
                                  if (_preview!.currentStreak != null)
                                    _buildDataPill('STREAK: ${_preview!.currentStreak}d', AppTheme.accentPrimary),
                                ],
                              ),

                              // Section list summary
                              if (_preview!.sectionNames.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Sections: ${_preview!.sectionNames.join(', ')}',
                                  style: AppTheme.bodyLabel(color: AppTheme.textMuted, fontSize: 11),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],

                              // Warnings
                              if (_preview!.warnings.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentPrimary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppTheme.accentPrimary.withOpacity(0.3)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: _preview!.warnings
                                        .map((w) => Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Icon(Icons.info_outline, size: 12, color: AppTheme.accentPrimary),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    w,
                                                    style: AppTheme.bodyLabel(color: AppTheme.accentPrimary, fontSize: 10.5),
                                                  ),
                                                ),
                                              ],
                                            ))
                                        .toList(),
                                  ),
                                ),
                              ],

                              // Conflicts
                              if (_preview!.conflicts.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.dangerCrimson.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppTheme.dangerCrimson.withOpacity(0.3)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: _preview!.conflicts
                                        .map((c) => Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Icon(Icons.warning_amber_rounded, size: 12, color: AppTheme.dangerCrimson),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    c,
                                                    style: AppTheme.bodyLabel(color: AppTheme.dangerCrimson, fontSize: 10.5),
                                                  ),
                                                ),
                                              ],
                                            ))
                                        .toList(),
                                  ),
                                ),
                              ],
                            ] else ...[
                              Text(
                                _preview!.errorMessage ?? 'Unrecognized payload structure. Please verify formatting.',
                                style: GoogleFonts.ibmPlexMono(
                                  color: AppTheme.dangerCrimson,
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Conflict Strategy Selector
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.bgPanel,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CONFLICT RESOLUTION STRATEGY',
                            style: AppTheme.technicalLabel(
                              color: AppTheme.textMuted,
                              fontSize: 9.5,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _overwrite = false),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: !_overwrite ? AppTheme.accentSage.withOpacity(0.15) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: !_overwrite ? AppTheme.accentSage : AppTheme.borderSubtle,
                                        width: !_overwrite ? 1.4 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              !_overwrite ? Icons.radio_button_checked : Icons.radio_button_off,
                                              size: 14,
                                              color: !_overwrite ? AppTheme.accentSage : AppTheme.textMuted,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'MERGE DATA',
                                              style: AppTheme.bodyLabel(
                                                color: !_overwrite ? AppTheme.textPrimary : AppTheme.textMuted,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Non-destructive. Keeps existing items, dedupes history, merges tasks.',
                                          style: AppTheme.bodyLabel(color: AppTheme.textMuted, fontSize: 9.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _overwrite = true),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _overwrite ? AppTheme.dangerCrimson.withOpacity(0.15) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _overwrite ? AppTheme.dangerCrimson : AppTheme.borderSubtle,
                                        width: _overwrite ? 1.4 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              _overwrite ? Icons.radio_button_checked : Icons.radio_button_off,
                                              size: 14,
                                              color: _overwrite ? AppTheme.dangerCrimson : AppTheme.textMuted,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'REPLACE ALL',
                                              style: AppTheme.bodyLabel(
                                                color: _overwrite ? AppTheme.textPrimary : AppTheme.textMuted,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Atomic replace. Overwrites existing sections and restores state.',
                                          style: AppTheme.bodyLabel(color: AppTheme.textMuted, fontSize: 9.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Dialog Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
                  child: Text('CANCEL', style: AppTheme.bodyLabel(color: AppTheme.textMuted, fontSize: 12)),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: (_preview != null && _preview!.isValid && !_isImporting)
                      ? _executeImport
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _overwrite ? AppTheme.dangerCrimson : AppTheme.accentPrimary,
                    foregroundColor: AppTheme.onPrimaryAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    disabledBackgroundColor: AppTheme.bgPanel,
                    disabledForegroundColor: AppTheme.textMuted,
                  ),
                  icon: _isImporting
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.onPrimaryAccent),
                        )
                      : const Icon(Icons.cloud_download_rounded, size: 16),
                  label: Text(
                    _isImporting
                        ? 'IMPORTING...'
                        : (_overwrite ? 'CONFIRM & RESTORE' : 'EXECUTE MERGE'),
                    style: AppTheme.uiButton(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: (_preview != null && _preview!.isValid && !_isImporting)
                          ? AppTheme.onPrimaryAccent
                          : AppTheme.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiffMetric(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          label,
          style: AppTheme.technicalLabel(color: AppTheme.textMuted, fontSize: 9, letterSpacing: 0.8),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.ibmPlexMono(
            color: valueColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildDataPill(String text, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: accentColor.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: GoogleFonts.ibmPlexMono(
          color: accentColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

