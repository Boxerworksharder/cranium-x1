# ⚡ Cranium X1 · Tactical Deep Work & Focus Engine

> **A hardware-accelerated desk chronograph & mobile companion app engineered for uninterrupted deep work, time sink isolation, offline task synchronization, and biometric pacing.**

---

[![Release](https://img.shields.io/github/v/release/Boxerworksharder/cranium-x1?style=for-the-badge&color=ff5500)](https://github.com/Boxerworksharder/cranium-x1/releases/tag/v1.8.1)
[![Download APK](https://img.shields.io/badge/Download_APK-v1.8.1_(22.8MB)-00e5ff?style=for-the-badge&logo=android)](https://github.com/Boxerworksharder/cranium-x1/releases/download/v1.8.1/cranium_x1.apk)
[![Tests](https://img.shields.io/badge/Tests-66%20Passed%20(100%25)-39ff14?style=for-the-badge&logo=flutter)](https://github.com/Boxerworksharder/cranium-x1)
[![Hardware](https://img.shields.io/badge/Hardware-ESP32--C3%20%7C%20ESP32--WROOM-blueviolet?style=for-the-badge&logo=espressif)](https://github.com/Boxerworksharder/cranium-x1)
[![Buy Me A Coffee](https://img.shields.io/badge/Buy_Me_A_Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/boxerworksharder)

---

## 🏗️ Repository Architecture

This monorepo houses both the embedded ESP32 firmware and the cross-platform Flutter companion application:

```
cranium-x1/
├── firmware/                 # Embedded C++ Firmware (PlatformIO)
│   ├── src/                  # Core runtime: main, FreeRTOS event loops, input interrupts
│   ├── include/              # Modular subsystems: BLE GATT, OLED UI, LittleFS Storage
│   │   ├── ble_manager.h     # 1Hz telemetry chunking & JSON command receiver
│   │   ├── oled_ui.h         # SH1106/SSD1306 rendering with micro-indicator dots
│   │   ├── storage_manager.h # Power-loss protected LittleFS persistence
│   │   └── tracker_state.h   # Streak engine, session straddling, FreeRTOS mutexes
│   ├── dashboard/            # Zero-dependency embedded Glassmorphism web cockpit
│   └── platformio.ini        # Dual environment: esp32-c3 & esp32dev
│
└── mobile/                   # Flutter Companion App (Android / iOS / Desktop)
    ├── lib/                  # Application code
    │   ├── data/             # Bluetooth Low Energy service & JSON/CSV backup engines
    │   ├── state/            # Reactive state management with offline sync queue
    │   └── ui/               # OLED Cyberpunk Tactical HUD widgets & receipts
    └── test/                 # 66 unit, regression, and hardware hardening test cases
```

---

## 🌟 Key Subsystems (v1.8.1)

### 1. ESP32 Physical Hardware Chronograph
- **SH1106 / SSD1306 I2C OLED Display**: High-contrast 128x64 tactical display with micro-dot page indicators (`● ○`), session timer pulse ring, dynamic mastery levels (`LVL 0`–`LVL 5`), and auto-dimming idle screensaver.
- **Rotary Encoder & Menu Navigation**: Smooth scrolling between focus categories, click-to-toggle session state (Start / Pause / Resume / Stop), and physical rotary menu with `>> ZERO HARD RESET <<`.
- **Dedicated Tally Button (GPIO 21)**: Physical rep logging and one-click conversion between **Deep Work** and **Time Sink** activities.
- **Multi-Board Firmware Architecture**: Pre-configured build targets for both **ESP32-C3 SuperMini** (RISC-V) and **ESP32-WROOM-32 Dev Module** (Xtensa).
- **Active Haptics & Visual Feedback**: Vibrations for start/pause/stop/tally and LED warning pulses.
- **Smart Powerbank Keep-Alive**: Periodically pulses current loads to keep auto-shutoff USB powerbanks alive indefinitely.
- **LittleFS Flash Persistence**: Flash memory storage with power-loss protection and JSON integrity validation.

### 2. Flutter Companion App (`titiksha_mobile`)
- **Pure Bluetooth Low Energy (BLE 5.0)**: Streamlined, low-power pairing (`CRANIUM-X1`) with 1Hz streaming telemetry and chunk reassembly. All legacy Wi-Fi dependencies removed for maximum battery life and zero-setup connectivity.
- **Persistent Offline Sync Queue (`_pendingSyncQueue`)**:
  - Tasks, daily notes, and reminders created or updated offline are automatically enqueued.
  - Sequentially flushes all pending mutations upon BLE reconnection.
  - Non-destructive telemetry merging guarantees hardware state never overwrites pending local edits.
- **Guaranteed Dual-Wipe Factory Hard Reset**:
  - **From Phone**: One-tap factory reset immediately cleanses local state and queues a hardware wipe payload (`_pendingResetOnConnect`) if offline.
  - **From Physical Device**: Select `>> ZERO HARD RESET <<` from the OLED rotary menu to instantly wipe LittleFS flash and restore factory zero-state.
- **True Receipts & Analytics Engine**:
  - Eliminates session double-counting between active session today and historical logs.
  - Clean zero-state rendering (`0%` focus score, 0 sessions, 0 hours) upon reset.
  - Live Focus Purity calculation (`% Deep Work vs Total Time`).
- **Cyberpunk Tactical HUD**: Monospaced chronograph display, focus depth indicators, time sink banners, and analytics charts.
- **Full Offline Operation**: Lossless JSON/CSV data backup, offline task management, and customizable haptic feedback.

---

## ⚡ BLE Protocol & Real-Time Telemetry

The ESP32 communicates over Bluetooth Low Energy via:
- **Service UUID**: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
- **Telemetry Characteristic (Notify)**: `beb5483e-36e1-4688-b7f5-ea07361b26a8`
- **Command Characteristic (Write Without Response)**: `6e400002-b5a3-f393-e0a9-e50e24dcca9e`

### Telemetry Packet (ESP32 ➡️ Phone)
Transmitted at 1Hz, chunked into MTU-safe segments with framing:
```json
{
  "state": "TRACKING",
  "activeId": 1,
  "activeName": "Coding",
  "sessionSeconds": 1420,
  "todaySeconds": 5020,
  "dailyGoal": 28800,
  "currentStreak": 5,
  "longestStreak": 14,
  "reps": 12,
  "clients": [
    {
      "id": 1,
      "name": "Coding",
      "totalSecsToday": 5020,
      "reps": 12,
      "isNegative": false,
      "history": [{"date": "15 Sep 2026", "secs": 14400, "reps": 20}]
    }
  ]
}
```

### Command Dispatch (Phone ➡️ ESP32)
```json
{"action": "start", "id": 1}
{"action": "pause"}
{"action": "resume"}
{"action": "stop"}
{"action": "select", "id": 2}
{"action": "rep_plus"}
{"action": "rep_minus"}
{"action": "toggle_negative", "id": 3, "isNegative": true}
{"action": "set_brightness", "level": 200}
{"action": "wellness", "enabled": true, "interval": 45}
{"action": "sync_tasks", "tasks": [...]}
{"action": "sync_daily_notes", "notes": [...]}
{"action": "hard_reset"}
{"action": "set_time", "epoch": 1789448000}
```

---

## 🚀 Getting Started

### 1. Flash the ESP32 Firmware
1. Navigate to the firmware directory:
   ```bash
   cd firmware
   ```
2. Build for your board target:
   - **ESP32-C3 SuperMini**:
     ```bash
     pio run -e esp32-c3 -t upload
     ```
   - **ESP32-WROOM-32 / DevKit**:
     ```bash
     pio run -e esp32dev -t upload
     ```
3. Open the serial monitor:
   ```bash
   pio device monitor -b 115200
   ```

### 2. Run / Build the Flutter Companion App
1. Navigate to the mobile directory:
   ```bash
   cd mobile
   ```
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Run the complete automated test suite:
   ```bash
   flutter test
   ```
4. Build release APK:
   ```bash
   flutter build apk --release
   ```
   *The optimized output APK is located at `build/app/outputs/flutter-apk/app-release.apk`.*

---

## 🧪 Testing & Verification

The project includes **66 automated tests** verifying core logic, hardware communication, and edge cases:
- **BLE Streaming & Chunking**: Packet reassembly across variable MTU packet boundaries (20–512 bytes) and corrupt chunk recovery.
- **Offline Sync Queue**: Enqueueing offline task edits, toggles, notes, and sequential flushing on reconnection.
- **Non-Destructive Merging**: Hardware state packet integration without data clobbering.
- **Guaranteed Factory Reset**: Offline hard reset queueing and 0-state telemetry handling.
- **Analytics & Receipts Precision**: Mathematical verification against double-counting active session seconds with history entries.
- **Negative Activity Isolation**: Live purity percentage calculation (`Deep Work / Total Time`).
- **Data Portability**: Lossless JSON / CSV database export, validation, and restoration.

Run tests:
```bash
cd mobile && flutter test
```

---

## ☕ Support the Project

If Cranium X1 has helped streamline your focus sessions and level up your deep work, consider supporting its open-source development:

[![Buy Me A Coffee](https://img.shields.io/badge/Buy_Me_A_Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/boxerworksharder)

---

## 📜 License
MIT License. Crafted with precision for deep workers.
