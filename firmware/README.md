# TITIKSHA X1 · Tactical Focus & Habit Tracking Engine ⚡
> **Release**: Version 1.8.0 (Stable Production Firmware) · ESP32-C3 & ESP32-WROOM-32 Multi-Board Edition

**TITIKSHA X1** is an open-source, ultra-low latency hardware time tracker, habit ledger, and deep work engine powered by the **ESP32-C3** and **ESP32-WROOM-32**. It pairs physical tactile controls (Rotary Encoder + Tally Clicker + 0.96"/1.3" OLED) with real-time Bluetooth Low Energy (BLE 5.0 GATT) Android companion sync, offline queuing, and physical hard reset capabilities.

---

## 📸 Key Features

- **Hardware Cockpit**: 0.96"/1.3" SH1106 / SSD1306 I2C OLED (128x64) with smooth micro-slide transitions, micro-dot page indicators (`● ○`), dynamic mastery levels (`LVL 0`–`LVL 5`), and auto-dimming screensaver.
- **Physical Rotary Menu & Hard Reset**: Rotary encoder for seamless category selection and session pausing, plus dedicated physical rotary menu containing `>> ZERO HARD RESET <<` for instant hardware zero-wipes.
- **Dedicated Tally Clicker Button**: Physical button (GPIO 21) for habit rep logging and toggling negative/time sink categories.
- **Pure BLE 5.0 GATT Engine**: 1Hz streaming telemetry, chunked MTU packets, and bidirectional task/daily notes synchronization.
- **Dual Board Architecture**: Preconfigured builds for both ESP32-C3 SuperMini (RISC-V) and standard ESP32-WROOM-32 Dev Module (Xtensa).
- **Daily Streak Engine**: Automatic midnight rollover evaluation with active in-progress session straddle support.
- **Thread-Safe Architecture**: Full FreeRTOS mutex synchronization across BLE tasks, ISR interrupts, and display rendering loops.
- **Safe Persistence**: LittleFS flash memory storage with power-loss protection and JSON integrity validation.
- **Guaranteed Zero Reset**: Dual-wipe support via both BLE remote commands and direct on-device rotary menu trigger.

---

## 🛠️ Hardware Bill of Materials & Wiring

| Component | Pin / Function | ESP32-C3 SuperMini Pin | Notes |
|---|---|---|---|
| **0.96" SH1106 OLED** | SDA (Data) | **GPIO 4** | 400kHz Fast Hardware I2C |
| | SCL (Clock) | **GPIO 5** | 400kHz Fast Hardware I2C |
| | VCC / GND | **3.3V / GND** | Clean regulated rail |
| **Rotary Encoder** | CLK (A) | **GPIO 0** | Hardware interrupt (IRAM) |
| | DT (B) | **GPIO 1** | Hardware interrupt (IRAM) |
| | SW (Push Button) | **GPIO 2** | Internal pull-up (`INPUT_PULLUP`) |
| **Tally Clicker Button** | Signal (Active LOW) | **GPIO 21** | Internal pull-up (`INPUT_PULLUP`) |
| **Onboard Blue LED** | Runaway / Tracking Indicator | **GPIO 8** | Active LOW indicator |
| **External Red SMD LED** | Focus Engine / "On Air" | **GPIO 6** | 390Ω resistor to GND |
| **External Blue SMD LED**| Bluetooth Link / Break / Tally | **GPIO 10** | 390Ω resistor to GND |
| **Haptic Vibration Motor**| NPN Transistor Driver | **GPIO 7** | Transistor Base via 1kΩ + Diode |

---

## 📂 Project Architecture

```text
esp32-time-tracker/
├── .gitignore                      # Git exclusion rules
├── README.md                       # Documentation & setup manual
├── platformio.ini                  # PlatformIO config & min_spiffs partition table
├── include/
│   ├── config.h                    # Central configuration (Wi-Fi, BLE, NTP, Pins)
│   ├── config.example.h            # Sanitized configuration template for GitHub
│   ├── pin_config.h                # Hardware pin definitions
│   ├── tracker_state.h             # Core domain logic, streak engine, mutex locks
│   ├── storage_manager.h           # LittleFS flash persistence and integrity validator
│   ├── oled_ui.h                   # Modular SH1106 OLED UI screens & font helpers
│   ├── web_server_handler.h        # Async HTTP REST API, CORS, and gzip server
│   ├── ble_manager.h               # Bluetooth Low Energy GATT server & notify engine
│   └── web_assets.h                # Pre-compressed GZIP web dashboard binary
├── src/
│   └── main.cpp                    # Clean controller: setup, loop, input interrupts
├── dashboard/
│   ├── index.html                  # Standalone Glassmorphism HUD Cockpit & Web BLE PWA
│   └── manifest.json               # Android Chrome PWA Web App Manifest
├── scripts/
│   └── compress_web.py             # Re-compiles index.html -> include/web_assets.h
└── tests/
    └── test_api.py                 # 12-test automated integration test suite
```

---

## 🚀 Quick Start Guide

### 1. Prerequisites
- Install [PlatformIO Core (CLI)](https://platformio.org/install/cli) or the PlatformIO extension for VS Code / Cursor / CLion.
- Python 3.8+ installed.

### 2. Configure Wi-Fi & Credentials
Open `include/config.h` and edit your Wi-Fi network:
```c
#define WIFI_SSID       "Your_WiFi_Network"
#define WIFI_PASSWORD   "Your_WiFi_Password"
```
*(If pushing to a public repository, use `include/config.example.h` as a reference and add `include/config.h` to your `.gitignore`).*

### 3. Build & Flash Firmware
Connect your board via USB and compile/upload for your specific target:

- **ESP32-C3 SuperMini**:
  ```bash
  pio run -e esp32-c3 -t upload
  ```

- **ESP32-WROOM-32 DevKit**:
  ```bash
  pio run -e esp32dev -t upload
  ```

Open the serial monitor (115200 baud):
```bash
pio device monitor -b 115200
```

### 4. Access the Cockpit
Once connected, your ESP32 will display its IP on the OLED screen. Open your browser and navigate to:
- **`http://timetracker.local`** *(mDNS auto-discovery)*
- or **`http://<YOUR_ESP32_IP>`** *(e.g. `http://192.168.0.210`)*

---

## 📡 Web Bluetooth PWA (Android / Chrome)

1. Open the dashboard on your Android phone using Google Chrome.
2. Tap the cyan **`BLE: PAIR 📡`** button in the header.
3. Select **`TITIKSHA-X1`** from the Bluetooth device dialog.
4. Tap the three dots in Chrome and select **"Add to Home screen"** to install it as a native offline PWA!

---

## 🧪 Automated Testing

Run the included automated integration test suite against your live hardware:
```bash
python3 tests/test_api.py --host http://timetracker.local
```
This script runs **12 automated integration tests** covering schema integrity, real-time actions, streak evaluation, dynamic categories, CSV exports, CORS preflight, and flash reset wiping.

---

## 🔄 Modifying the Web Dashboard

If you modify `dashboard/index.html`, re-compress the web assets into firmware with:
```bash
python3 scripts/compress_web.py
pio run -t upload
```

---

## 🔌 REST API Reference

| Method | Endpoint | Description | Payload Example |
|---|---|---|---|
| `GET` | `/api/status` | Full live telemetry, streak, and section history | None |
| `GET` | `/api/quick` | Mini-telemetry widget packet | None |
| `POST` | `/api/action` | Remote control actions (`start`, `pause`, `resume`, `stop`, `rep_plus`, `rep_minus`, `reset_all`) | `{"action":"start"}` |
| `POST` | `/api/goal` | Update daily Deep Work target (seconds) | `{"goal":28800}` |
| `POST` | `/api/sections/add` | Create a new focus category | `{"name":"System Design"}` |
| `POST` | `/api/sections/update` | Rename or update reps/seconds | `{"id":1,"name":"Coding"}` |
| `POST` | `/api/sections/delete` | Delete category by ID | `{"id":2}` |
| `POST` | `/api/reset` | Complete flash memory & state zero wipe | None |
| `GET` | `/api/export/sessions.csv`| Download all historical sessions as CSV | None |
| `GET` | `/api/export/summary.csv` | Download section mastery summary as CSV | None |
| `GET` | `/api/backup.json` | Download raw LittleFS database backup | None |
| `POST` | `/api/restore.json`| Restore JSON database to LittleFS flash | Raw JSON string |

---

## 📶 Bluetooth (BLE GATT) Profile

- **Device Name**: `TITIKSHA-X1`
- **Primary Service UUID**: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
- **Telemetry Characteristic (READ / NOTIFY)**: `beb5483e-36e1-4688-b7f5-ea07361b26a8`
- **Command Characteristic (WRITE)**: `6e400002-b5a3-f393-e0a9-e50e24dcca9e`

---

## 📄 License
MIT License. Free to use, modify, and build upon.
