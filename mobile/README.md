# 📱 Cranium X1 Companion Mobile App (`titiksha_mobile`)

> **Production-grade Flutter mobile companion for Cranium X1 — designed for tactile deep work, real-time Bluetooth Low Energy (BLE 5.0) telemetry synchronization, task management, and tamper-proof focus analytics.**

---

[![Release](https://img.shields.io/github/v/release/Boxerworksharder/cranium-x1?style=for-the-badge&color=ff5500)](https://github.com/Boxerworksharder/cranium-x1/releases/tag/v1.8)
[![Download APK](https://img.shields.io/badge/Download_APK-v1.8_(22.8MB)-00e5ff?style=for-the-badge&logo=android)](https://github.com/Boxerworksharder/cranium-x1/releases/download/v1.8/cranium_x1.apk)
[![Tests](https://img.shields.io/badge/Tests-66%20Passed%20(100%25)-39ff14?style=for-the-badge&logo=flutter)](https://github.com/Boxerworksharder/cranium-x1)

---

## 🏗️ Architecture & Core Components

```
mobile/
├── lib/
│   ├── data/
│   │   ├── models/           # ClientSection, SessionEntry, TelemetryPacket, FocusTask, DailyNote
│   │   ├── ble_service.dart  # BLE scanning, MTU chunk reassembly, and connection state machine
│   │   └── data_exporter.dart# Lossless JSON database & CSV export/import engine
│   ├── state/
│   │   └── tracker_provider.dart # Central reactive state, offline sync queue, and mutex locks
│   └── ui/
│       ├── screens/          # Dashboard, Analytics & Receipts, Tasks & Notes, Settings
│       ├── theme/            # Cyberpunk OLED theme, custom colors & typography
│       └── widgets/          # Chronograph HUD, Heatmap grid, Haptic clickers, Receipt cards
└── test/                     # 66 comprehensive automated unit & regression tests
```

---

## 🌟 Key Features & Systems (v1.8)

### 1. Pure BLE 5.0 GATT Architecture
- Zero-latency pairing with device broadcast `CRANIUM-X1`.
- High-efficiency 1Hz streaming telemetry with automatic MTU-safe chunk reassembly.
- Automatic phone RTC synchronization (`set_time` epoch timestamp dispatch on connect).
- Complete elimination of Wi-Fi setup overhead for true instant-on mobile connectivity.

### 2. Persistent Offline Sync Queue (`_pendingSyncQueue`)
- **Offline Mutability**: Users can create, edit, toggle, or delete tasks, daily notes, and reminders completely offline without hardware presence.
- **Ordered Queue Execution**: Mutations are buffered in a FIFO queue and sequentially dispatched to the hardware via BLE command packets upon reconnection.
- **Non-Destructive State Merging**: Incoming hardware telemetry is merged non-destructively, ensuring pending local offline drafts are never overwritten by device state.

### 3. Guaranteed Dual-Wipe Factory Hard Reset
- Executing a factory reset from the app immediately purges local SQLite/memory state.
- If disconnected from hardware, the reset operation is enqueued (`_pendingResetOnConnect`) and automatically dispatched as a `hard_reset` command upon the next BLE handshake.
- Both mobile analytics and hardware LittleFS flash enter a synchronized zero-state.

### 4. True Receipts & Analytics Engine
- **Session Double-Counting Elimination**: Accurately computes cumulative time by distinguishing active live sessions from recorded history entries.
- **True Zero-State**: After factory reset, renders `0%` focus score, 0 sessions, and 0 hours cleanly without fallback artifacts.
- **Focus Purity Index**: Computes ratio of true productive deep work against isolated time sinks and distractions:
  $$\text{Focus Purity} = \frac{\text{Deep Work Seconds}}{\text{Total Tracked Seconds}} \times 100\%$$

---

## 🧪 Running Automated Tests

The test suite covers BLE streaming reassembly, state merging, offline sync queue flushing, zero-state resets, and analytics precision:

```bash
flutter pub get
flutter test
```

Expected result:
```
00:04 +66: All tests passed!
```

---

## 📦 Building Release APK

To compile an optimized, production-signed release APK:

```bash
flutter build apk --release
```

Output binary:
`build/app/outputs/flutter-apk/app-release.apk`

---

## 📜 License
MIT License. Part of the Cranium X1 Open Source Project.

