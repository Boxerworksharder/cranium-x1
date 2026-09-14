import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class ConnectionIndicator extends StatelessWidget {
  final bool isOnline;
  final String host;
  final bool isBluetooth;
  final VoidCallback onTap;

  const ConnectionIndicator({
    super.key,
    required this.isOnline,
    required this.host,
    this.isBluetooth = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isOnline
        ? (isBluetooth ? AppTheme.cyanTelemetry : AppTheme.emeraldGreen)
        : AppTheme.dangerCrimson;

    String label;
    if (isBluetooth) {
      label = isOnline ? '● BLE CONNECTED' : '✕ BLE OFFLINE';
    } else {
      label = isOnline ? AppTheme.statusLiveText : AppTheme.statusOfflineText;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isBluetooth ? Icons.bluetooth_rounded : Icons.circle,
              size: isBluetooth ? 12 : 7,
              color: color,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
