#pragma once
#include <Arduino.h>

// ============================================================================
// CRANIUM X1 · CONFIGURATION TEMPLATE (Copy to config.h)
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
#define WIFI_CONNECT_TIMEOUT_MS 12000

#define SOFTAP_SSID             "DeskTracker"
#define SOFTAP_PASSWORD         nullptr  // Open network for setup
#define SOFTAP_IP               IPAddress(192, 168, 4, 1)

#define MDNS_HOSTNAME           "timetracker"
#define NTP_SERVER_PRIMARY      "pool.ntp.org"
#define NTP_SERVER_SECONDARY    "time.google.com"
#define NTP_GMT_OFFSET_SEC      19800             // IST (UTC+5:30) = 19800. Adjust for your timezone!
#define NTP_DAYLIGHT_OFFSET_SEC 0
#endif

// ----------------------------------------------------------------------------
// 3. Bluetooth Low Energy (BLE)
// ----------------------------------------------------------------------------
#define BLE_DEVICE_NAME         "CRANIUM-X1"

// ----------------------------------------------------------------------------
// 4. Time Tracking & Streak Engine Defaults
// ----------------------------------------------------------------------------
#define DEFAULT_DEEP_WORK_GOAL_SEC   36000
#define DAILY_STREAK_THRESHOLD_SEC   3600
#define RUNAWAY_ALERT_THRESHOLD_SEC  12600
#define IDLE_DIM_TIMEOUT_MS          180000
#define AUTO_SAVE_INTERVAL_MS        60000

// ----------------------------------------------------------------------------
// 5. Hardware Display Settings
// ----------------------------------------------------------------------------
#define OLED_I2C_CLOCK_SPEED         400000
#define OLED_CONTRAST_ACTIVE         255
#define OLED_CONTRAST_DIMMED         10
