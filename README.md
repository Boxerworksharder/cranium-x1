# ⚡ Cranium X1 · Tactical Deep Work & Focus Engine

> **A hardware-accelerated, dual-sync (BLE + Wi-Fi) desk chronograph & companion mobile app engineered for uninterrupted deep work, time sink isolation, and biometric wellness pacing.**

---

## 🏗️ Repository Architecture

This monorepo houses both the embedded ESP32 firmware and the cross-platform Flutter companion application:

```
cranium-x1/
├── firmware/                 # ESP32-WROOM-32 Hardware Firmware (PlatformIO)
│   ├── src/                  # Core runtime: main, event loops, power management
│   ├── include/              # Modular subsystems: BLE, OLED UI, Storage, Haptics
│   ├── dashboard/            # Embedded zero-dependency web dashboard (HTML/CSS/JS)
│   └── platformio.ini        # Target configuration & embedded dependencies
│
└── mobile/                   # Flutter Companion App (Android / iOS / Desktop)
    ├── lib/                  # Application code (State, Services, Models, UI)
    │   ├── data/             # BLE service, HTTP client, JSON/CSV serialization
    │   ├── state/            # Reactive state management (TrackerProvider)
    │   └── ui/               # OLED-styled Cyberpunk HUD widgets & screens
    └── test/                 # 49 unit, regression & widget test cases
```

---

## 🌟 Key Features

### 1. ESP32 Physical Hardware Chronograph
- **SH1106 1.3" OLED Display**: Real-time chronograph digits, progress arc, level progression, and live wellness alerts.
- **Rotary Encoder & Tactical Knob**: Rotate to browse sections; single click to start/pause/resume tracking; long click for stress-buster breathing pacing.
- **Dedicated Tally Button (GPIO 21)**: Real-time rep counting and one-click conversion between **Deep Work** and **Time Sink** activities.
- **Active Haptics & Visual Feedback**: Vibrations for start/pause/stop/tally and LED warning pulses.
- **Smart Powerbank Keep-Alive**: Periodically pulses current loads to keep auto-shutoff USB powerbanks alive indefinitely.
- **Offline Resilient**: Local EEPROM/NVS flash saves data every 60 seconds; tracks streak counts, daily goals, and history without internet.

### 2. Flutter Companion App (`titiksha_mobile`)
- **Direct Bluetooth Low Energy (BLE)**: Zero-latency pairing (`CRANIUM-X1`) with 1Hz streaming telemetry and chunk reassembly.
- **Local Wi-Fi / SoftAP Sync**: Seamless fallback to HTTP REST API when connected to the local home network or ESP32 away-mode hotspot.
- **Cyberpunk Tactical HUD**: Monospaced chronograph display, focus depth indicators, time sink banners, and analytics charts.
- **Negative Activity Isolation**: Tracks distractions and doomscrolling separately with live Focus Purity calculation (`% Deep Work vs Total Time`).
- **Full Offline Operation**: Lossless JSON/CSV data backup, offline task management, and customizable haptic feedback.

---

## ⚡ BLE Protocol & Real-Time Telemetry

The ESP32 communicates over Bluetooth Low Energy via:
- **Service UUID**: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
- **Telemetry Characteristic (Notify)**: `beb5483e-36e1-4688-b7f5-ea07361b26a8`
- **Command Characteristic (Write Without Response)**: `6e400002-b5a3-f393-e0a9-e50e24dcca9e`

### Command Dispatch (Phone ➡️ ESP32)
```json
{"action": "start", "id": 3}
{"action": "pause"}
{"action": "resume"}
{"action": "stop"}
{"action": "select", "id": 3}
{"action": "rep_plus"}
{"action": "rep_minus"}
{"action": "set_brightness", "level": 200}
{"action": "wellness", "enabled": true, "interval": 45}
{"action": "stress_buster"}
{"action": "toggle_negative", "id": 3, "isNegative": true}
```

---

## 🚀 Getting Started

### 1. Flash the ESP32 Firmware
1. Navigate to the firmware directory:
   ```bash
   cd firmware
   ```
2. Copy configuration template and set your preferences:
   ```bash
   cp include/config.example.h include/config.h
   ```
3. Connect the ESP32 via USB and upload:
   ```bash
   pio run --target upload
   ```

### 2. Run / Build the Flutter Companion App
1. Navigate to the mobile directory:
   ```bash
   cd mobile
   ```
2. Fetch dependencies and run tests:
   ```bash
   flutter pub get
   flutter test
   ```
3. Build release APK:
   ```bash
   flutter build apk --release
   ```

---

## 🧪 Testing & Verification

The test suite covers:
- Streaming BLE packet chunk reassembly across variable MTU packet boundaries.
- Negative activity & time sink metric isolation.
- Offline task/reminder persistence.
- Lossless JSON / CSV export and import validation.

Run all tests:
```bash
cd mobile && flutter test
```

---

## 📜 License
MIT License. Crafted with precision for deep workers.
