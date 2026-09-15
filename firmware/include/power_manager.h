#pragma once
#include <Arduino.h>
#include "config.h"
#include "pin_config.h"

#if FEATURE_WIFI
#include <WiFi.h>
#include <WiFiUdp.h>
#endif

// ============================================================================
// CRANIUM X1 · POWER BANK ANTI-SLEEP KEEP-ALIVE ENGINE
// ============================================================================
// Modern USB power banks monitor output current and shut down if draw falls
// below ~30-80mA for 15-30 seconds.
// PowerManager executes an active ~180-240mA load burst for 120ms every 10s
// unconditionally (on home Wi-Fi, in SoftAP Away-Mode, or during pure BLE).
// ============================================================================

class PowerManager {
public:
    static bool keepAliveEnabled;
    static unsigned long lastPulseMillis;
    static bool isPulsing;
    static unsigned long pulseStartMillis;
#if FEATURE_WIFI
    static WiFiUDP keepAliveUdp;
#endif

    static void init() {
        Serial.println("[POWER] Initializing Power Bank Keep-Alive Engine...");
#if FEATURE_WIFI
        WiFi.setTxPower(WIFI_POWER_19_5dBm); // Set RF transceiver to maximum +19.5dBm
#endif
        lastPulseMillis = millis();
        isPulsing = false;
    }

    static void setEnabled(bool enabled) {
        keepAliveEnabled = enabled;
        Serial.printf("[POWER] Power Bank Keep-Alive: %s\n", enabled ? "ENABLED (10s pulse)" : "DISABLED");
    }

    static void update() {
        if (!keepAliveEnabled) return;

        unsigned long now = millis();

        // 1. Start Keep-Alive Current Load Pulse every 10 seconds
        if (!isPulsing && (now - lastPulseMillis >= POWERBANK_PULSE_INTERVAL_MS)) {
            lastPulseMillis = now;
            isPulsing = true;
            pulseStartMillis = now;

            // Bump CPU frequency to maximum 160MHz
            setCpuFrequencyMhz(160);

            // Subtle visual heartbeat: brief pulse on status LED
            #ifdef PIN_LED_STATUS
            digitalWrite(PIN_LED_STATUS, HIGH);
            #endif

#if FEATURE_WIFI
            // Burst high-power RF transmission packets
            if (WiFi.getMode() != WIFI_OFF) {
                for (int i = 0; i < 4; i++) {
                    keepAliveUdp.beginPacket(IPAddress(255, 255, 255, 255), 9999);
                    keepAliveUdp.write((const uint8_t*)"CRANIUM_POWER_PULSE", 19);
                    keepAliveUdp.endPacket();
                }
            }
#endif
        }

        // 2. End Keep-Alive Pulse after calibrated 120ms duration
        if (isPulsing && (now - pulseStartMillis >= POWERBANK_PULSE_DURATION_MS)) {
            isPulsing = false;

            #ifdef PIN_LED_STATUS
            digitalWrite(PIN_LED_STATUS, LOW);
            #endif
        }
    }
};

