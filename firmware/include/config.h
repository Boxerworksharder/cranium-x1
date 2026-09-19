#pragma once
#include <Arduino.h>

// ============================================================================
// CRANIUM X1 · TACTICAL FOCUS ENGINE CONFIGURATION
// ============================================================================

// ----------------------------------------------------------------------------
// 0. System Features Toggle
// ----------------------------------------------------------------------------
// Set FEATURE_WIFI to 0 for ultra-lean, battery-efficient, pure-BLE operation
// (saves ~1.1MB Flash, ~50KB RAM, cuts power draw by ~75%, unlocks Dual OTA).
// Set FEATURE_WIFI to 1 to enable the embedded HTTP web server and SoftAP.
#define FEATURE_WIFI                    0

// ----------------------------------------------------------------------------
// 1. Wi-Fi Station & SoftAP Credentials (Active when FEATURE_WIFI == 1)
// ----------------------------------------------------------------------------
#if FEATURE_WIFI
#define WIFI_SSID               "YOUR_WIFI_SSID"
#define WIFI_PASSWORD           "YOUR_WIFI_PASSWORD"
#define WIFI_CONNECT_TIMEOUT_MS 8000              // 8s timeout allows typical home Wi-Fi DHCP handshakes ample time

#define SOFTAP_SSID             "CRANIUM-X1-AP"   // Away-Mode Hotspot
#define SOFTAP_PASSWORD         nullptr           // Open network for zero-friction access
#define SOFTAP_IP               IPAddress(192, 168, 4, 1)

#define MDNS_HOSTNAME           "timetracker"     // Access via http://timetracker.local
#define NTP_SERVER_PRIMARY      "pool.ntp.org"
#define NTP_SERVER_SECONDARY    "time.google.com"
#define NTP_GMT_OFFSET_SEC      19800             // IST (UTC+5:30) = 5.5 * 3600
#define NTP_DAYLIGHT_OFFSET_SEC 0
#endif

#define POWERBANK_PULSE_INTERVAL_MS 10000         // 10 Seconds keep-alive pulse cycle
#define POWERBANK_PULSE_DURATION_MS 120           // 120ms load duration to trip power bank sensing

// ----------------------------------------------------------------------------
// 3. Bluetooth Low Energy (BLE)
// ----------------------------------------------------------------------------
#define BLE_DEVICE_NAME         "CRANIUM-X1"

// ----------------------------------------------------------------------------
// 4. Time Tracking & Streak Engine Defaults
// ----------------------------------------------------------------------------
#define DEFAULT_DEEP_WORK_GOAL_SEC   36000        // 10 Hours daily target
#define DAILY_STREAK_THRESHOLD_SEC   3600         // 1 Hour required to count streak
#define RUNAWAY_ALERT_THRESHOLD_SEC  12600        // 3.5 Hours runaway LED alert
#define IDLE_DIM_TIMEOUT_MS          60000        // 1 Minute to dim display
#define SCREENSAVER_TIMEOUT_MS       120000       // 2 Minutes to launch Matrix
#define AUTO_SAVE_INTERVAL_MS        60000        // 60 Seconds flash flush

// ----------------------------------------------------------------------------
// 5. Hardware Display Settings
// ----------------------------------------------------------------------------
#define OLED_I2C_CLOCK_SPEED         400000       // 400kHz Fast I2C
#define OLED_CONTRAST_ACTIVE         255
#define OLED_CONTRAST_DIMMED         10
