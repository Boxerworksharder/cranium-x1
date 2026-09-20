import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import '../../core/services/csv_export_service.dart';
import '../../core/theme/app_theme.dart';
import '../../state/tracker_provider.dart';
import '../widgets/import_data_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isConnectingBle = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackerProvider>(
      builder: (context, tracker, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 0. HUD Interface Theme Selector (Ghost in the Shell vs Tactical Flame)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDeck,
                  borderRadius: BorderRadius.circular(AppTheme.radiusDeck),
                  border: Border.all(color: AppTheme.hairlineSeam),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'VISUAL THEME',
                            style: AppTheme.technicalLabel(),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.accentPrimary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(AppTheme.radiusMicro),
                              border: Border.all(color: AppTheme.accentPrimary.withOpacity(0.4)),
                            ),
                            child: Text(
                              tracker.themeStyle == UiThemeStyle.dark
                                  ? 'DARK OBSIDIAN'
                                  : 'LIGHT PARCHMENT',
                              style: AppTheme.technicalLabel(
                                color: AppTheme.accentPrimary,
                                fontSize: 9.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _buildThemeCard(
                            tracker: tracker,
                            style: UiThemeStyle.dark,
                            title: 'DARK OBSIDIAN',
                            subtitle: 'Warm Charcoal · Sand Amber',
                            accentColor: const Color(0xFFE5B887),
                            activeBg: const Color(0xFF161719),
                          ),
                          const SizedBox(width: 10),
                          _buildThemeCard(
                            tracker: tracker,
                            style: UiThemeStyle.light,
                            title: 'LIGHT PARCHMENT',
                            subtitle: 'Oatmeal Paper · Forest Sage',
                            accentColor: const Color(0xFFC68E54),
                            activeBg: const Color(0xFFEBE7DE),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

              // 1. Direct Bluetooth BLE Connection Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDeck,
                  borderRadius: BorderRadius.circular(AppTheme.radiusDeck),
                  border: Border.all(color: AppTheme.hairlineSeam),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'HARDWARE CONNECTION',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textMuted,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.cyanTelemetry.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(AppTheme.radiusMicro),
                            border: Border.all(
                              color: AppTheme.cyanTelemetry.withOpacity(0.4),
                            ),
                          ),
                          child: Text(
                            'BLE 5.0 GATT',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.cyanTelemetry,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildBleControls(tracker),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 1b. Power Bank Keep-Alive & Portability
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDeck,
                  borderRadius: BorderRadius.circular(AppTheme.radiusDeck),
                  border: Border.all(color: AppTheme.hairlineSeam),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'PORTABILITY & POWER BANK',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textMuted,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: (tracker.status.powerbankKeepAlive ? AppTheme.orangeFlame : AppTheme.textMuted).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: (tracker.status.powerbankKeepAlive ? AppTheme.orangeFlame : AppTheme.textMuted).withOpacity(0.35)),
                          ),
                          child: Text(
                            tracker.status.powerbankKeepAlive ? 'ACTIVE' : 'DISABLED',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: tracker.status.powerbankKeepAlive ? AppTheme.orangeFlame : AppTheme.textMuted,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Power Bank Keep-Alive',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Draws a periodic 120ms RF pulse every 10s to prevent USB power banks from automatically cutting off 5V power when running portably.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.5),
                      ),
                      activeColor: AppTheme.orangeFlame,
                      value: tracker.status.powerbankKeepAlive,
                      onChanged: (val) {
                        AppTheme.hapticSelection();
                        tracker.togglePowerBankKeepAlive(val);
                      },
                    ),
                    Divider(color: AppTheme.hairlineSeam, height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.sync_rounded, size: 15),
                        label: const Text('SYNC PHONE TIME (RTC)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.cyanTelemetry,
                          side: BorderSide(color: AppTheme.cyanTelemetry.withOpacity(0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        ),
                        onPressed: () async {
                          AppTheme.hapticAction();
                          final ok = await tracker.syncTimeToDevice();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok ? '✓ Real-world RTC clock synced to ESP32!' : 'Failed to sync clock'),
                                backgroundColor: ok ? AppTheme.emeraldGreen : AppTheme.dangerCrimson,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),



              // 3. Data Logistics, Backup & Full Export Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDeck,
                  borderRadius: BorderRadius.circular(AppTheme.radiusDeck),
                  border: Border.all(color: AppTheme.hairlineSeam),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'DATA BACKUP & EXPORT',
                          style: AppTheme.technicalLabel(
                            color: AppTheme.textMuted,
                            fontSize: 10.5,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.accentPrimary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(AppTheme.radiusMicro),
                            border: Border.all(color: AppTheme.accentPrimary.withOpacity(0.35)),
                          ),
                          child: Text(
                            'JSON v2 + CSV ZIP',
                            style: AppTheme.technicalLabel(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.accentPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Unified Data Management',
                      style: AppTheme.editorialTitle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Preserve all your deep work telemetry, historical session tallies, tasks, and streaks. Export structured archives or restore atomically.',
                      style: AppTheme.bodyLabel(
                        color: AppTheme.textSecondary,
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Data Telemetry HUD Summary Box
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceRecessed,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.hairlineSeam),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildMetricItem('SESSIONS', '${tracker.dataSummaryMetrics['sessionsCount']}'),
                              _buildMetricItem('HOURS', '${tracker.dataSummaryMetrics['totalHours']}h'),
                              _buildMetricItem('SECTIONS', '${tracker.dataSummaryMetrics['sectionsCount']}'),
                              _buildMetricItem('TASKS', '${tracker.dataSummaryMetrics['tasksCount']}'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history_rounded, size: 12, color: AppTheme.textMuted),
                              const SizedBox(width: 5),
                              Text(
                                'Last Backup: ${tracker.lastBackupDateFormatted}',
                                style: AppTheme.technicalLabel(
                                  color: AppTheme.textMuted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Primary Action: BACK UP NOW (JSON v2)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                        label: Text(
                          'BACK UP NOW (LOSSLESS JSON v2)',
                          style: AppTheme.uiButton(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: AppTheme.onPrimaryAccent,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentPrimary,
                          foregroundColor: AppTheme.onPrimaryAccent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
                        ),
                        onPressed: () async {
                          AppTheme.hapticAction();
                          try {
                            final jsonStr = CsvExportService.generateLosslessJsonBackup(
                              status: tracker.status,
                              tasks: tracker.tasks,
                              reminders: tracker.reminders,
                            );
                            await CsvExportService.shareJsonFile(
                              jsonContent: jsonStr,
                              filenamePrefix: 'cranium_backup_v2',
                            );
                            await tracker.recordBackupCompleted();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Backup export error: $e'), backgroundColor: AppTheme.dangerCrimson),
                              );
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Secondary Action: Export Data Archive (Multi-table CSV ZIP)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: Icon(Icons.archive_rounded, size: 16, color: AppTheme.accentSage),
                        label: Text(
                          'EXPORT DATA ARCHIVE (.ZIP)',
                          style: AppTheme.uiButton(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppTheme.accentSage,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppTheme.accentSage.withOpacity(0.5)),
                          backgroundColor: AppTheme.accentSage.withOpacity(0.06),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
                        ),
                        onPressed: () async {
                          AppTheme.hapticAction();
                          try {
                            final zipBytes = await CsvExportService.generateStructuredCsvZip(
                              status: tracker.status,
                              tasks: tracker.tasks,
                              reminders: tracker.reminders,
                              host: tracker.isOnline ? tracker.host : null,
                            );
                            await CsvExportService.shareZipArchive(
                              zipBytes: zipBytes,
                              filenamePrefix: 'cranium_archive',
                            );
                            await tracker.recordBackupCompleted();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Archive export error: $e'), backgroundColor: AppTheme.dangerCrimson),
                              );
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Standalone CSVs Row
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(Icons.description_outlined, size: 14, color: AppTheme.textPrimary),
                            label: Text('SESSIONS CSV', style: AppTheme.uiButton(fontSize: 9.5, color: AppTheme.textPrimary)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppTheme.borderSubtle),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
                            ),
                            onPressed: () async {
                              AppTheme.hapticAction();
                              try {
                                final csv = await CsvExportService.generateSessionsCsv(
                                  status: tracker.status,
                                  host: tracker.isOnline ? tracker.host : null,
                                );
                                await CsvExportService.shareCsvFile(csvContent: csv, filenamePrefix: 'cranium_sessions');
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Export error: $e'), backgroundColor: AppTheme.dangerCrimson),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(Icons.table_chart_outlined, size: 14, color: AppTheme.textPrimary),
                            label: Text('SUMMARY CSV', style: AppTheme.uiButton(fontSize: 9.5, color: AppTheme.textPrimary)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppTheme.borderSubtle),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
                            ),
                            onPressed: () async {
                              AppTheme.hapticAction();
                              try {
                                final csv = await CsvExportService.generateSummaryCsv(
                                  status: tracker.status,
                                  host: tracker.isOnline ? tracker.host : null,
                                );
                                await CsvExportService.shareCsvFile(csvContent: csv, filenamePrefix: 'cranium_summary');
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Export error: $e'), backgroundColor: AppTheme.dangerCrimson),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Restore & Ingestion Action
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: Icon(Icons.restore_page_rounded, size: 16, color: AppTheme.accentPrimary),
                        label: Text(
                          'IMPORT & RESTORE BACKUP',
                          style: AppTheme.uiButton(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppTheme.accentPrimary,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppTheme.accentPrimary.withOpacity(0.5)),
                          backgroundColor: AppTheme.accentPrimary.withOpacity(0.04),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
                        ),
                        onPressed: () {
                          AppTheme.hapticAction();
                          ImportDataDialog.show(context);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. Device Hardware Specs
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDeck,
                  borderRadius: BorderRadius.circular(AppTheme.radiusDeck),
                  border: Border.all(color: AppTheme.hairlineSeam),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HARDWARE TELEMETRY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textMuted,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildTelemetryRow('APP VERSION', 'v1.9.0 (Build 10)'),
                    _buildTelemetryRow('DEVICE', 'ESP32-C3 SuperMini'),
                    _buildTelemetryRow('DISPLAY', '128x64 SH1106 OLED (I2C)'),
                    _buildTelemetryRow('BLUETOOTH', 'BLE 5.0 GATT (Cranium-X1)'),
                    _buildTelemetryRow('TASK BUTTON', 'GPIO 20 (Direct Sync)'),
                    _buildTelemetryRow('ENCODER KNOB', 'GPIO 3, 4 (SW: GPIO 2)'),
                    _buildTelemetryRow('HAPTICS', 'GPIO 6 PWM Vibration Motor'),
                  ],
                ),
              ),
              const SizedBox(height: 16),



              // 6. Danger Zone: Factory Data Reset with Warning Modal
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDeck,
                  borderRadius: BorderRadius.circular(AppTheme.radiusDeck),
                  border: Border.all(color: AppTheme.dangerCrimson.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: AppTheme.dangerCrimson, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'FACTORY DATA RESET',
                          style: AppTheme.technicalLabel(
                            color: AppTheme.dangerCrimson,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Zero out all flash memory on the physical ESP32 tracker and erase local session caches. This removes all historical sessions, streaks, and focus tallies.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.delete_forever_rounded, size: 18),
                        label: const Text(
                          'RESET ALL TRACKER DATA',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.dangerCrimson,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
                        ),
                        onPressed: () => _showResetConfirmationDialog(context, tracker),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  // --- BLE CONTROLS WIDGET ---
  Widget _buildBleControls(TrackerProvider tracker) {
    final ble = tracker.bleService;
    final isConnected = ble.isConnected;
    final isReconnecting = ble.isAutoReconnecting;
    final hasPairedDevice = tracker.lastBleDeviceId != null && tracker.lastBleDeviceId!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bluetooth Adapter State Warning
        StreamBuilder<BluetoothAdapterState>(
          stream: ble.adapterState,
          initialData: BluetoothAdapterState.unknown,
          builder: (context, snap) {
            final state = snap.data;
            if (state == BluetoothAdapterState.off) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.dangerCrimson.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                  border: Border.all(color: AppTheme.dangerCrimson.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.bluetooth_disabled_rounded, color: AppTheme.dangerCrimson, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'BLUETOOTH IS DISABLED: Enable Bluetooth in phone settings to link to Cranium X1.',
                        style: TextStyle(fontSize: 10.5, color: AppTheme.dangerCrimson, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox();
          },
        ),

        // Device Link Status Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceRecessed,
            borderRadius: BorderRadius.circular(AppTheme.radiusControl),
            border: Border.all(
              color: isConnected
                  ? AppTheme.cyanTelemetry
                  : (isReconnecting ? AppTheme.orangeFlame : AppTheme.hairlineSeam),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      isConnected
                          ? Icons.bluetooth_connected_rounded
                          : (isReconnecting ? Icons.bluetooth_searching_rounded : Icons.bluetooth_rounded),
                      color: isConnected
                          ? AppTheme.cyanTelemetry
                          : (isReconnecting ? AppTheme.orangeFlame : AppTheme.textMuted),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isConnected
                                ? 'LINKED: ${ble.connectedDeviceName ?? tracker.lastBleDeviceName ?? "CRANIUM-X1"}'
                                : (isReconnecting
                                    ? 'RECONNECTING: ${tracker.lastBleDeviceName ?? "CRANIUM-X1"}'
                                    : (hasPairedDevice
                                        ? 'PAIRED: ${tracker.lastBleDeviceName ?? "CRANIUM-X1"}'
                                        : 'BLUETOOTH STANDBY')),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isConnected
                                  ? AppTheme.cyanTelemetry
                                  : (isReconnecting ? AppTheme.orangeFlame : AppTheme.textPrimary),
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            isConnected
                                ? '1Hz Ground Truth Telemetry Stream Active'
                                : (isReconnecting
                                    ? 'Watchdog auto-retry active • Keeping sync ready'
                                    : (hasPairedDevice
                                        ? 'Saved ID: ${tracker.lastBleDeviceId}'
                                        : 'Ready to scan and pair')),
                            style: TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isConnected)
                    TextButton(
                      onPressed: () async {
                        AppTheme.hapticAction();
                        await ble.disconnect();
                      },
                      child: Text('DISCONNECT', style: TextStyle(fontSize: 10, color: AppTheme.dangerCrimson, fontWeight: FontWeight.bold)),
                    )
                  else if (hasPairedDevice) ...[
                    TextButton(
                      onPressed: _isConnectingBle
                          ? null
                          : () async {
                              AppTheme.hapticAction();
                              setState(() => _isConnectingBle = true);
                              final ok = await ble.connectWithId(tracker.lastBleDeviceId!);
                              if (mounted) {
                                setState(() => _isConnectingBle = false);
                                if (ok) {
                                  await tracker.setSyncProtocol(SyncProtocol.bluetooth);
                                }
                              }
                            },
                      child: Text(_isConnectingBle ? '...' : 'CONNECT', style: TextStyle(fontSize: 10, color: AppTheme.cyanTelemetry, fontWeight: FontWeight.bold)),
                    ),
                    TextButton(
                      onPressed: () async {
                        AppTheme.hapticAction();
                        await tracker.forgetBleDevice();
                      },
                      child: Text('FORGET', style: TextStyle(fontSize: 10, color: AppTheme.dangerCrimson, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        StreamBuilder<bool>(
          stream: ble.isScanning,
          initialData: false,
          builder: (context, snapshot) {
            final isScanning = snapshot.data ?? false;

            return Row(
              children: [
                ElevatedButton.icon(
                  icon: isScanning || _isConnectingBle
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.bluetooth_searching_rounded, size: 16),
                  label: Text(
                    isScanning ? 'SCANNING...' : 'SCAN FOR CRANIUM-X1',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cyanTelemetry,
                    foregroundColor: AppTheme.surfaceVoid,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
                  ),
                  onPressed: isScanning || _isConnectingBle
                      ? null
                      : () async {
                          AppTheme.hapticAction();
                          final err = await ble.startScan();
                          if (err != null && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(err),
                                backgroundColor: AppTheme.dangerCrimson,
                              ),
                            );
                          }
                        },
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),

        // Discovered Devices List
        StreamBuilder<List<ScanResult>>(
          stream: ble.scanResults,
          initialData: const [],
          builder: (context, snapshot) {
            final results = snapshot.data ?? [];
            if (results.isEmpty) {
              return const SizedBox();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DISCOVERED BLE DEVICES',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textMuted, fontFamily: 'monospace'),
                ),
                const SizedBox(height: 6),
                ...results.map((r) {
                  final name = r.device.platformName.isNotEmpty ? r.device.platformName : r.advertisementData.advName;
                  final displayName = name.isNotEmpty ? name : 'Unknown Device';
                  final isTarget = displayName.toLowerCase().contains('cranium') || displayName.toLowerCase().contains('titiksha') || displayName.toLowerCase().contains('x1');

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isTarget ? AppTheme.orangeFlame.withOpacity(0.12) : AppTheme.surfaceRecessed,
                      borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                      border: Border.all(
                        color: isTarget ? AppTheme.orangeFlame : AppTheme.hairlineSeam,
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
                                displayName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: isTarget ? AppTheme.orangeFlame : AppTheme.textPrimary,
                                  fontFamily: 'monospace',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'RSSI: ${r.rssi} dBm  •  ${r.device.remoteId.str}',
                                style: TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isTarget ? AppTheme.orangeFlame : AppTheme.cyanTelemetry,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: _isConnectingBle
                              ? null
                              : () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  setState(() => _isConnectingBle = true);
                                  final ok = await tracker.connectBle(r.device);
                                  if (mounted) {
                                    setState(() => _isConnectingBle = false);
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(ok ? '✓ Connected & Paired with $displayName!' : 'Failed to connect to $displayName'),
                                        backgroundColor: ok ? AppTheme.cyanTelemetry : AppTheme.dangerCrimson,
                                      ),
                                    );
                                  }
                                },
                          child: const Text('PAIR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ],
    );
  }

  // --- RESET CONFIRMATION DIALOG ---
  void _showResetConfirmationDialog(BuildContext context, TrackerProvider tracker) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceOverlay,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusDeck),
            side: BorderSide(color: AppTheme.dangerCrimson, width: 1.5),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.dangerCrimson, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'CONFIRM HARD RESET',
                  style: TextStyle(
                    color: AppTheme.dangerCrimson,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    fontFamily: 'monospace',
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you absolutely sure you want to perform a zero-wipe factory reset?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.dangerCrimson.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                  border: Border.all(color: AppTheme.dangerCrimson.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'The following will be PERMANENTLY ERASED:',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.dangerCrimson),
                    ),
                    const SizedBox(height: 6),
                    _buildWarningBullet('All session logs in LittleFS flash'),
                    _buildWarningBullet('Current active streak & best streak records'),
                    _buildWarningBullet("Today's deep work accumulation & reps"),
                    _buildWarningBullet('All custom focus sections'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '⚠️ This operation is irreversible and cannot be undone.',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                AppTheme.hapticSelection();
                Navigator.pop(ctx);
              },
              child: Text('CANCEL', style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w800)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.dangerCrimson,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
              ),
              onPressed: () async {
                AppTheme.hapticAction();
                Navigator.pop(ctx);
                final isConnected = tracker.bleService.isConnected;
                await tracker.resetAllData();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isConnected
                          ? '✓ Hard reset complete. Storage zeroed.'
                          : '✓ App storage zeroed. Hardware will wipe upon next link.'),
                      backgroundColor: AppTheme.orangeFlame,
                    ),
                  );
                }
              },
              child: const Text('ERASE ALL DATA', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWarningBullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: AppTheme.dangerCrimson, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 10, color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontFamily: 'monospace')),
          Text(value, style: TextStyle(fontSize: 11, color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildThemeCard({
    required TrackerProvider tracker,
    required UiThemeStyle style,
    required String title,
    required String subtitle,
    required Color accentColor,
    required Color activeBg,
  }) {
    final isSelected = tracker.themeStyle == style;
    return Expanded(
      child: InkWell(
        onTap: () {
          AppTheme.hapticSelection();
          tracker.setThemeStyle(style);
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : AppTheme.surfaceRecessed,
            borderRadius: BorderRadius.circular(AppTheme.radiusControl),
            border: Border.all(
              color: isSelected ? accentColor : AppTheme.hairlineSeam,
              width: isSelected ? 2 : 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentColor,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: accentColor.withOpacity(0.6),
                                blurRadius: 4,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: isSelected ? accentColor : AppTheme.textPrimary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  color: isSelected ? AppTheme.textPrimary.withOpacity(0.85) : AppTheme.textMuted,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: AppTheme.technicalLabel(color: AppTheme.textMuted, fontSize: 9, letterSpacing: 0.8),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTheme.dataValue(
            color: AppTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
