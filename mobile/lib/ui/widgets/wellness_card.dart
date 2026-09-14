import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../state/tracker_provider.dart';

class WellnessCard extends StatelessWidget {
  const WellnessCard({super.key});

  static const List<int> intervalOptions = [15, 30, 45, 60, 90];

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackerProvider>(
      builder: (context, tracker, _) {
        final enabled = tracker.wellnessEnabled;
        final currentInterval = tracker.wellnessIntervalMinutes;
        final currentMode = tracker.wellnessMode; // 0 = Alternating, 1 = Water, 2 = Stretch

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
              // 1. Header with Title & Switch
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: enabled
                          ? AppTheme.accentPrimary.withOpacity(0.12)
                          : AppTheme.borderSubtle,
                      borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                    ),
                    child: Center(
                      child: Icon(
                        enabled ? Icons.water_drop_rounded : Icons.water_drop_outlined,
                        size: 18,
                        color: enabled ? AppTheme.accentPrimary : AppTheme.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WELLNESS & POSTURE',
                          style: AppTheme.technicalLabel(
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          enabled
                              ? 'Active · Every ${currentInterval}m alert'
                              : 'Disabled · Turn ON to stay sharp',
                          style: AppTheme.bodyText(
                            color: enabled ? AppTheme.accentSage : AppTheme.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: enabled,
                    activeColor: AppTheme.accentPrimary,
                    onChanged: (_) {
                      AppTheme.hapticSelection();
                      tracker.toggleWellness();
                    },
                  ),
                ],
              ),

              if (enabled) ...[
                const SizedBox(height: 16),
                const Divider(height: 1, thickness: 0.5),
                const SizedBox(height: 14),

                // 2. Interval Selection
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'REMIND EVERY',
                      style: AppTheme.technicalLabel(
                        fontSize: 9.5,
                        color: AppTheme.textSecondary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      '$currentInterval Minutes',
                      style: AppTheme.technicalLabel(
                        fontSize: 9.5,
                        color: AppTheme.accentPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: intervalOptions.map((mins) {
                    final isSel = (currentInterval == mins);
                    return InkWell(
                      onTap: () {
                        AppTheme.hapticSelection();
                        tracker.setWellnessInterval(mins);
                      },
                      borderRadius: BorderRadius.circular(AppTheme.radiusMicro),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSel ? AppTheme.accentPrimary : AppTheme.bgPanel,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMicro),
                          border: Border.all(
                            color: isSel ? AppTheme.accentPrimary : AppTheme.borderSubtle,
                          ),
                        ),
                        child: Text(
                          '${mins}m',
                          style: AppTheme.technicalLabel(
                            color: isSel ? AppTheme.onPrimaryAccent : AppTheme.textPrimary,
                            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 14),

                // 3. Mode Selection (Alternating, Water Only, Stretch Only)
                Text(
                  'REMINDER MODE',
                  style: AppTheme.technicalLabel(
                    fontSize: 9.5,
                    color: AppTheme.textSecondary,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    _buildModeOption(
                      label: 'Alternate',
                      subtitle: '💧 + 🧘',
                      mode: 0,
                      selectedMode: currentMode,
                      onTap: () => tracker.setWellnessMode(0),
                    ),
                    const SizedBox(width: 8),
                    _buildModeOption(
                      label: 'Water Only',
                      subtitle: '💧 Hydrate',
                      mode: 1,
                      selectedMode: currentMode,
                      onTap: () => tracker.setWellnessMode(1),
                    ),
                    const SizedBox(width: 8),
                    _buildModeOption(
                      label: 'Stretch Only',
                      subtitle: '🧘 Posture',
                      mode: 2,
                      selectedMode: currentMode,
                      onTap: () => tracker.setWellnessMode(2),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // 4. Test Alert Buttons (Instant 5s OLED Flash Preview)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.bgPanel,
                    borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                    border: Border.all(color: AppTheme.hairlineSeam),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.visibility_outlined, size: 12, color: AppTheme.textMuted),
                          const SizedBox(width: 6),
                          Text(
                            'TEST OLED FLASH ALERT',
                            style: AppTheme.technicalLabel(
                              fontSize: 9,
                              letterSpacing: 1.0,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                AppTheme.hapticSelection();
                                await tracker.testWellnessAlert(kind: 0);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('💧 Water droplet alert flashed on OLED!'),
                                      duration: const Duration(seconds: 2),
                                      backgroundColor: AppTheme.bgCard,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.water_drop_rounded, size: 14),
                              label: const Text('Water Alert', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.accentPrimary,
                                side: BorderSide(color: AppTheme.borderSubtle),
                                padding: const EdgeInsets.symmetric(vertical: 6),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                AppTheme.hapticSelection();
                                await tracker.testWellnessAlert(kind: 1);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('🧘 Stand & Stretch alert flashed on OLED!'),
                                      duration: const Duration(seconds: 2),
                                      backgroundColor: AppTheme.bgCard,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.accessibility_new_rounded, size: 14),
                              label: const Text('Stretch Alert', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.accentSage,
                                side: BorderSide(color: AppTheme.borderSubtle),
                                padding: const EdgeInsets.symmetric(vertical: 6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildModeOption({
    required String label,
    required String subtitle,
    required int mode,
    required int selectedMode,
    required VoidCallback onTap,
  }) {
    final isSel = (mode == selectedMode);
    return Expanded(
      child: InkWell(
        onTap: () {
          AppTheme.hapticSelection();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusMicro),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSel ? AppTheme.accentPrimary.withOpacity(0.12) : AppTheme.bgPanel,
            borderRadius: BorderRadius.circular(AppTheme.radiusMicro),
            border: Border.all(
              color: isSel ? AppTheme.accentPrimary : AppTheme.borderSubtle,
              width: isSel ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTheme.technicalLabel(
                  fontSize: 9.5,
                  color: isSel ? AppTheme.accentPrimary : AppTheme.textSecondary,
                  fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
