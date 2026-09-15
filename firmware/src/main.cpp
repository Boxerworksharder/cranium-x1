#include <Arduino.h>
#include <Wire.h>
#include <U8g2lib.h>
#include <RotaryEncoder.h>
#include <esp_task_wdt.h>
#include "config.h"
#include "pin_config.h"
#include "tracker_state.h"
#include "storage_manager.h"
#include "web_server_handler.h"
#include "ble_manager.h"
#include "oled_ui.h"
#include "haptic_manager.h"
#include "power_manager.h"

// --------------------------------------------------------------------------
// Hardware Display: Fast Hardware I2C (400kHz) on Pins 4 & 5
// --------------------------------------------------------------------------
U8G2_SH1106_128X64_NONAME_F_HW_I2C u8g2(U8G2_R0, /* reset=*/ U8X8_PIN_NONE, /* clock=*/ PIN_OLED_SCL, /* data=*/ PIN_OLED_SDA);

RotaryEncoder encoder(PIN_ENCODER_CLK, PIN_ENCODER_DT, RotaryEncoder::LatchMode::FOUR3);

TrackerManager tracker;
DeskTrackerWebServer webServer;
BLEManager bleManager;
SemaphoreHandle_t trackerMutex = NULL;

bool needsRedraw = true;
int slideOffset = 0;
int trackingPageView = 0; // 0 = Screen 1 (Chronograph), 1 = Screen 2 (Tactical Mastery), 2 = Screen 3 (Daily Report)

// --------------------------------------------------------------------------
// Button Handler Class (Hardware Debounce + Short/Long Press)
// --------------------------------------------------------------------------
class ButtonHandler {
private:
    int pin;
    unsigned long debounceMs;
    unsigned long longPressMs;

    int lastRawState;
    int stableState;
    unsigned long lastDebounceTime;
    unsigned long pressStartTime;
    bool longPressTriggered;

public:
    enum Event { NONE, CLICK, LONG_PRESS };

    ButtonHandler(int p, unsigned long debounce = 35, unsigned long longPress = 800)
        : pin(p), debounceMs(debounce), longPressMs(longPress),
          lastRawState(HIGH), stableState(HIGH),
          lastDebounceTime(0), pressStartTime(0), longPressTriggered(false) {}

    void init() {
        pinMode(pin, INPUT_PULLUP);
    }

    Event update() {
        int raw = digitalRead(pin);
        unsigned long now = millis();

        if (raw != lastRawState) {
            lastDebounceTime = now;
            lastRawState = raw;
        }

        Event evt = NONE;

        if ((now - lastDebounceTime) > debounceMs) {
            if (raw != stableState) {
                stableState = raw;

                if (stableState == LOW) {
                    pressStartTime = now;
                    longPressTriggered = false;
                } else {
                    if (!longPressTriggered && (now - pressStartTime < longPressMs)) {
                        evt = CLICK;
                    }
                }
            }
        }

        if (stableState == LOW && !longPressTriggered) {
            if ((now - pressStartTime) >= longPressMs) {
                longPressTriggered = true;
                evt = LONG_PRESS;
            }
        }

        return evt;
    }
};

ButtonHandler knobButton(PIN_ENCODER_SW, 35, 450);
ButtonHandler tallyButton(PIN_TALLY_BUTTON);
#ifdef PIN_SESSIONS_BUTTON
ButtonHandler sessionsButton(PIN_SESSIONS_BUTTON);
#endif

// --------------------------------------------------------------------------
// External SMD LEDs (GPIO 6 = Focus Engine, GPIO 7 = Bluetooth / Break / Tally)
// --------------------------------------------------------------------------
unsigned long statusLedFlashUntil = 0;

void triggerStatusLedFlash(unsigned long durationMs = 100) {
    statusLedFlashUntil = millis() + durationMs;
}

void updateExternalLeds() {
    if (tracker.state == STATE_STRESS_BUSTER) {
        digitalWrite(PIN_LED_RED, LOW);
        // Serene blue breathing pulse
        digitalWrite(PIN_LED_BLUE, (millis() / 350) % 2 == 0 ? HIGH : LOW);
        return;
    }

    // 🔴 RED LED (PIN_LED_RED - GPIO 6): Focus / Deep Work "On Air" Indicator
    if (tracker.state == STATE_TRACKING) {
        // In 50/10 session, check if in 10-minute recovery break:
        bool isBreak = (tracker.currentSessionSeconds % 3600) >= 3000;
        if (isBreak) {
            digitalWrite(PIN_LED_RED, LOW); // Rest during recovery
        } else {
            digitalWrite(PIN_LED_RED, HIGH); // Solid Focus Red Glow
        }
    } else if (tracker.state == STATE_PAUSED) {
        // Slow gentle pulse when paused (1Hz)
        digitalWrite(PIN_LED_RED, (millis() / 500) % 2 == 0 ? HIGH : LOW);
    } else {
        digitalWrite(PIN_LED_RED, LOW);
    }

    // 🔵 BLUE LED (PIN_LED_BLUE - GPIO 10): Bluetooth Link, Break Recovery, & Tally Flash
    if (millis() < statusLedFlashUntil) {
        digitalWrite(PIN_LED_BLUE, HIGH); // Instant visual burst on button / tally click
    } else if (tracker.state == STATE_TRACKING && (tracker.currentSessionSeconds % 3600) >= 3000) {
        // Active 10M Break Recovery phase: relaxing blue breathing blink (2Hz)
        digitalWrite(PIN_LED_BLUE, (millis() / 250) % 2 == 0 ? HIGH : LOW);
    } else if (bleManager.isConnected) {
        // Solid Blue glow when paired and connected to phone / companion app
        digitalWrite(PIN_LED_BLUE, HIGH);
    } else {
        // Subtle 30ms beacon pulse every 2s to indicate Bluetooth is advertising & ready to pair
        digitalWrite(PIN_LED_BLUE, (millis() % 2000 < 30) ? HIGH : LOW);
    }
}

// --------------------------------------------------------------------------
// Haptic Convenience Helpers (Delegated to HapticManager)
// --------------------------------------------------------------------------
void triggerHaptic(int durationMs = 35) {
    HapticManager::trigger(durationMs);
}

void triggerHapticPattern(int pulses, int onMs = 60, int gapMs = 80) {
    HapticManager::triggerPattern(pulses, onMs, gapMs);
}

// --------------------------------------------------------------------------
// Rotary Encoder ISR
// --------------------------------------------------------------------------
void IRAM_ATTR checkEncoderPosition() {
    encoder.tick();
}

void handleEncoderInput() {
    int newPos = encoder.getPosition();
    static int lastPos = 0;

    if (newPos != lastPos) {
        TrackerLock lock;
        if (tracker.isDimmed) {
            u8g2.setPowerSave(0);
            u8g2.setContrast(tracker.activeBrightness);
            tracker.isDimmed = false;
            needsRedraw = true;
        }
        tracker.recordUserActivity();

        int diff = newPos - lastPos;
        lastPos = newPos;

        if (tracker.isShowingWellnessAlert) {
            tracker.dismissWellnessAlert();
            needsRedraw = true;
            return;
        }

        if (tracker.state == STATE_STRESS_BUSTER) {
            // Calm breathing: ignore rotation to avoid accidental disruption
            return;
        }

        if (tracker.state == STATE_SELECT_CLIENT) {
            int totalItems = tracker.clients.size() + 8;
            if (diff > 0) {
                tracker.menuIndex = (tracker.menuIndex + 1) % totalItems;
            } else if (diff < 0) {
                tracker.menuIndex = (tracker.menuIndex - 1 + totalItems) % totalItems;
            }
            needsRedraw = true;
        } else if (tracker.state == STATE_CONFIG_WELLNESS) {
            if (tracker.wellnessConfigField == 0) {
                tracker.wellnessEnabled = !tracker.wellnessEnabled;
            } else if (tracker.wellnessConfigField == 1) {
                int newInt = (int)tracker.wellnessIntervalMinutes + (diff * 5);
                if (newInt < 15) newInt = 15;
                if (newInt > 120) newInt = 120;
                tracker.wellnessIntervalMinutes = (uint16_t)newInt;
            } else if (tracker.wellnessConfigField == 2) {
                if (diff > 0) {
                    tracker.wellnessMode = (tracker.wellnessMode + 1) % 3;
                } else if (diff < 0) {
                    tracker.wellnessMode = (tracker.wellnessMode + 2) % 3;
                }
            }
            tracker.lastWellnessAlertMillis = millis();
            needsRedraw = true;
        } else if (tracker.state == STATE_SET_BRIGHTNESS) {
            int b = (int)tracker.activeBrightness + (diff * 15);
            if (b < 10) b = 10;
            if (b > 255) b = 255;
            tracker.activeBrightness = (uint8_t)b;
            u8g2.setContrast(tracker.activeBrightness);
            needsRedraw = true;
        } else if (tracker.state == STATE_VIEW_TASKS) {
            if (!tracker.tasks.empty()) {
                if (diff > 0) {
                    tracker.taskScrollIndex = (tracker.taskScrollIndex + 1) % tracker.tasks.size();
                } else if (diff < 0) {
                    tracker.taskScrollIndex = (tracker.taskScrollIndex - 1 + tracker.tasks.size()) % tracker.tasks.size();
                }
            }
            needsRedraw = true;
        } else if (tracker.state == STATE_VIEW_REMINDERS) {
            if (!tracker.reminders.empty()) {
                if (diff > 0) {
                    tracker.reminderScrollIndex = (tracker.reminderScrollIndex + 1) % tracker.reminders.size();
                } else if (diff < 0) {
                    tracker.reminderScrollIndex = (tracker.reminderScrollIndex - 1 + tracker.reminders.size()) % tracker.reminders.size();
                }
            }
            needsRedraw = true;
        } else if (tracker.state == STATE_VIEW_LOGS) {
            int totalLogs = 0;
            for (size_t c = 0; c < tracker.clients.size(); c++) {
                const auto& cl = tracker.clients[c];
                unsigned long s = cl.totalSecondsToday;
                if ((tracker.state == STATE_TRACKING || tracker.state == STATE_PAUSED) && (int)c == tracker.activeClientIndex) {
                    s += tracker.currentSessionSeconds;
                }
                if (s > 0 || cl.tallyCount > 0) totalLogs++;
                totalLogs += cl.history.size();
            }
            if (totalLogs > 0) {
                if (diff > 0) {
                    tracker.logScrollIndex = (tracker.logScrollIndex + 1) % totalLogs;
                } else if (diff < 0) {
                    tracker.logScrollIndex = (tracker.logScrollIndex - 1 + totalLogs) % totalLogs;
                }
            }
            needsRedraw = true;
        } else if (tracker.state == STATE_VIEW_SUMMARY) {
            int totalItems = tracker.clients.size();
            if (diff > 0) {
                tracker.summaryIndex = (tracker.summaryIndex + 1) % totalItems;
            } else if (diff < 0) {
                tracker.summaryIndex = (tracker.summaryIndex - 1 + totalItems) % totalItems;
            }
            needsRedraw = true;
        } else if (tracker.state == STATE_VIEW_QR) {
            tracker.state = STATE_SELECT_CLIENT;
            needsRedraw = true;
        } else if (tracker.state == STATE_TRACKING || tracker.state == STATE_PAUSED) {
            if (diff > 0) {
                trackingPageView = (trackingPageView + 1) % 3;
                slideOffset = 8;
            } else if (diff < 0) {
                trackingPageView = (trackingPageView - 1 + 3) % 3;
                slideOffset = -8;
            }
            needsRedraw = true;
        }
    }
}

void handleButtons() {
    ButtonHandler::Event knobEvt = knobButton.update();
    ButtonHandler::Event tallyEvt = tallyButton.update();
    #ifdef PIN_SESSIONS_BUTTON
    ButtonHandler::Event sessEvt = sessionsButton.update();
    #else
    ButtonHandler::Event sessEvt = ButtonHandler::NONE;
    #endif

    static TrackerState previousStateBeforeGlance = STATE_SELECT_CLIENT;

    // Wake-Up is handled cleanly by debounced button and encoder events below
    if (knobEvt != ButtonHandler::NONE || tallyEvt != ButtonHandler::NONE || sessEvt != ButtonHandler::NONE) {
        TrackerLock lock;
        if (tracker.isDimmed) {
            u8g2.setPowerSave(0);
            u8g2.setContrast(tracker.activeBrightness);
            tracker.isDimmed = false;
            needsRedraw = true;
        }
        tracker.recordUserActivity();

        if (tracker.isShowingWellnessAlert) {
            tracker.dismissWellnessAlert();
            needsRedraw = true;
            return;
        }

        // 1. Quick-Glance Tasks & Sessions Button (GPIO 20)
        if (sessEvt == ButtonHandler::CLICK) {
            triggerStatusLedFlash(100);
            HapticManager::pulseTap();
            if (tracker.state == STATE_VIEW_REMINDERS) {
                // If viewing notes/reminders, short click returns to previous screen
                tracker.state = (previousStateBeforeGlance != STATE_VIEW_REMINDERS) ? previousStateBeforeGlance : STATE_SELECT_CLIENT;
                if (tracker.state == STATE_SELECT_CLIENT) {
                    tracker.menuIndex = tracker.activeClientIndex;
                }
            } else if (tracker.state != STATE_VIEW_TASKS) {
                // Save current state so we can return to it seamlessly
                previousStateBeforeGlance = tracker.state;
                tracker.state = STATE_VIEW_TASKS;
                tracker.taskScrollIndex = 0;
            } else {
                // Toggle back to the state we were in before glancing!
                tracker.state = (previousStateBeforeGlance != STATE_VIEW_TASKS) ? previousStateBeforeGlance : STATE_SELECT_CLIENT;
                if (tracker.state == STATE_SELECT_CLIENT) {
                    tracker.menuIndex = tracker.activeClientIndex;
                }
            }
            needsRedraw = true;
        } else if (sessEvt == ButtonHandler::LONG_PRESS) {
            // Long Press GPIO 20: Toggle Daily Reminders & Habit Notes (without ticks)
            triggerStatusLedFlash(200);
            HapticManager::pulseTap();
            if (tracker.state != STATE_VIEW_REMINDERS) {
                previousStateBeforeGlance = tracker.state;
                tracker.state = STATE_VIEW_REMINDERS;
                tracker.reminderScrollIndex = 0;
            } else {
                tracker.state = (previousStateBeforeGlance != STATE_VIEW_REMINDERS) ? previousStateBeforeGlance : STATE_SELECT_CLIENT;
                if (tracker.state == STATE_SELECT_CLIENT) {
                    tracker.menuIndex = tracker.activeClientIndex;
                }
            }
            needsRedraw = true;
        }

        // 2. Knob Click: Select / Toggle Pause / Return to Menu
        if (knobEvt == ButtonHandler::CLICK) {
            triggerStatusLedFlash(80);
            if (tracker.state == STATE_STRESS_BUSTER) {
                HapticManager::pulseTap();
                tracker.cancelStressBuster();
            } else if (tracker.state == STATE_SELECT_CLIENT) {
                int totalClients = tracker.clients.size();
                if (tracker.menuIndex == totalClients) {
                    HapticManager::pulseTap();
                    previousStateBeforeGlance = tracker.state;
                    tracker.state = STATE_VIEW_TASKS;
                    tracker.taskScrollIndex = 0;
                } else if (tracker.menuIndex == totalClients + 1) {
                    HapticManager::pulseTap();
                    previousStateBeforeGlance = tracker.state;
                    tracker.state = STATE_VIEW_REMINDERS;
                    tracker.reminderScrollIndex = 0;
                } else if (tracker.menuIndex == totalClients + 2) {
                    HapticManager::pulseTap();
                    previousStateBeforeGlance = tracker.state;
                    tracker.state = STATE_VIEW_LOGS;
                    tracker.logScrollIndex = 0;
                } else if (tracker.menuIndex == totalClients + 3) {
                    HapticManager::pulseTap();
                    previousStateBeforeGlance = tracker.state;
                    tracker.state = STATE_VIEW_SUMMARY;
                    tracker.summaryIndex = 0;
                } else if (tracker.menuIndex == totalClients + 4) {
                    HapticManager::pulseTap();
                    tracker.state = STATE_SET_BRIGHTNESS;
                } else if (tracker.menuIndex == totalClients + 5) {
                    HapticManager::pulseTap();
                    tracker.state = STATE_CONFIG_WELLNESS;
                    tracker.wellnessConfigField = 0;
                } else if (tracker.menuIndex == totalClients + 6) {
                    HapticManager::pulseTap();
                    tracker.state = STATE_VIEW_QR;
                } else if (tracker.menuIndex == totalClients + 7) {
                    PowerManager::keepAliveEnabled = !PowerManager::keepAliveEnabled;
                    HapticManager::pulseTap();
                    triggerStatusLedFlash(100);
                    StorageManager::saveTrackerData(tracker);
                    bleManager.broadcastStatus();
                } else {
                    tracker.activeClientIndex = tracker.menuIndex;
                    trackingPageView = 0;
                    tracker.startTracking();
                    HapticManager::pulseStart(); // Double buzz on focus start!
                }
            } else if (tracker.state == STATE_CONFIG_WELLNESS) {
                HapticManager::pulseTap();
                tracker.wellnessConfigField = (tracker.wellnessConfigField + 1) % 3;
            } else if (tracker.state == STATE_VIEW_TASKS) {
                if (!tracker.tasks.empty()) {
                    tracker.toggleTask(tracker.tasks[tracker.taskScrollIndex].id);
                    HapticManager::pulseTally();
                    triggerStatusLedFlash(120);
                    StorageManager::saveTrackerData(tracker);
                }
            } else if (tracker.state == STATE_VIEW_REMINDERS) {
                HapticManager::pulseTap();
                tracker.state = (previousStateBeforeGlance != STATE_VIEW_REMINDERS) ? previousStateBeforeGlance : STATE_SELECT_CLIENT;
                if (tracker.state == STATE_SELECT_CLIENT) {
                    tracker.menuIndex = tracker.activeClientIndex;
                }
            } else if (tracker.state == STATE_SET_BRIGHTNESS) {
                HapticManager::pulseTap();
                StorageManager::saveTrackerData(tracker);
                tracker.state = STATE_SELECT_CLIENT;
                tracker.menuIndex = tracker.activeClientIndex;
            } else if (tracker.state == STATE_VIEW_LOGS) {
                HapticManager::pulseTap();
                tracker.state = (previousStateBeforeGlance != STATE_VIEW_LOGS) ? previousStateBeforeGlance : STATE_SELECT_CLIENT;
                if (tracker.state == STATE_SELECT_CLIENT) {
                    tracker.menuIndex = tracker.activeClientIndex;
                }
            } else if (tracker.state == STATE_VIEW_SUMMARY) {
                HapticManager::pulseTap();
                tracker.state = (previousStateBeforeGlance != STATE_VIEW_SUMMARY) ? previousStateBeforeGlance : STATE_SELECT_CLIENT;
                if (tracker.state == STATE_SELECT_CLIENT) {
                    tracker.menuIndex = tracker.activeClientIndex;
                }
            } else if (tracker.state == STATE_VIEW_QR) {
                HapticManager::pulseTap();
                tracker.state = STATE_SELECT_CLIENT;
                tracker.menuIndex = tracker.activeClientIndex;
            } else if (tracker.state == STATE_TRACKING || tracker.state == STATE_PAUSED) {
                tracker.togglePause();
                if (tracker.state == STATE_TRACKING) {
                    HapticManager::pulseResume();
                } else {
                    HapticManager::pulsePause();
                }
            }
            needsRedraw = true;
        }

        // 3. Knob Long Press: Universal Return to Main Menu / Stop Tracking
        if (knobEvt == ButtonHandler::LONG_PRESS) {
            triggerStatusLedFlash(200);
            HapticManager::pulseTap();
            if (tracker.state == STATE_STRESS_BUSTER) {
                tracker.cancelStressBuster();
            } else if (tracker.state == STATE_TRACKING || tracker.state == STATE_PAUSED) {
                HapticManager::pulseStop(); // Distinct stop buzz!
                tracker.stopAndSave();
                StorageManager::saveTrackerData(tracker);
                tracker.state = STATE_SELECT_CLIENT;
                tracker.menuIndex = tracker.activeClientIndex;
                previousStateBeforeGlance = STATE_SELECT_CLIENT;
            } else if (tracker.state == STATE_SELECT_CLIENT) {
                if (tracker.menuIndex != tracker.activeClientIndex) {
                    tracker.menuIndex = tracker.activeClientIndex; // Snap back to active client
                } else {
                    tracker.state = STATE_VIEW_QR; // Quick jump to QR
                }
            } else {
                // From ANY sub-screen (Tasks, Logs, Summary, Brightness, QR, Wellness): Return directly to Main Page!
                if (tracker.state == STATE_SET_BRIGHTNESS || tracker.state == STATE_CONFIG_WELLNESS) {
                    StorageManager::saveTrackerData(tracker);
                }
                tracker.state = STATE_SELECT_CLIENT;
                tracker.menuIndex = tracker.activeClientIndex;
                previousStateBeforeGlance = STATE_SELECT_CLIENT;
            }
            needsRedraw = true;
        }

        // Tally Button (GPIO 21):
        // STRICT SPECIFICATION:
        // ONLY during active Tracking / Paused sessions does the counter feature operate!
        // In ALL OTHER PLACES / SCREENS, GPIO 21 triggers the 10-Second Guided Stress Buster!
        if (tracker.state == STATE_TRACKING || tracker.state == STATE_PAUSED) {
            if (trackingPageView == 1) {
                // Page 2 (Tactical Mastery / Today Focus & LVL):
                // Counter button triggers the Guided Breathing Stress Buster routine!
                if (tallyEvt == ButtonHandler::CLICK || tallyEvt == ButtonHandler::LONG_PRESS) {
                    tracker.startStressBuster();
                    HapticManager::pulseStressBusterInhale();
                    triggerStatusLedFlash(150);
                    needsRedraw = true;
                }
            } else {
                // Repetition / Tally Counter Mode (Screen 1 Chronograph & Screen 3 Intervals):
                if (tallyEvt == ButtonHandler::CLICK) {
                    triggerStatusLedFlash(120);
                    HapticManager::pulseTally(); // Satisfying tactile rep click
                    tracker.incrementTally();
                    StorageManager::saveTrackerData(tracker);
                    needsRedraw = true;
                } else if (tallyEvt == ButtonHandler::LONG_PRESS) {
                    triggerStatusLedFlash(250);
                    HapticManager::pulseTallyMinus();
                    tracker.decrementTally();
                    StorageManager::saveTrackerData(tracker);
                    needsRedraw = true;
                }
            }
        } else if (tracker.state == STATE_STRESS_BUSTER) {
            // While in Stress Buster: Any click or press cancels early and returns
            if (tallyEvt == ButtonHandler::CLICK || tallyEvt == ButtonHandler::LONG_PRESS) {
                HapticManager::pulseTap();
                tracker.cancelStressBuster();
                needsRedraw = true;
            }
        } else if (tracker.state == STATE_SELECT_CLIENT && tracker.menuIndex < (int)tracker.clients.size()) {
            // Tally Button while highlighting a section in Main Menu:
            // Toggles section between DEEP WORK and TIME SINK!
            if (tallyEvt == ButtonHandler::CLICK) {
                tracker.clients[tracker.menuIndex].isNegative = !tracker.clients[tracker.menuIndex].isNegative;
                StorageManager::saveTrackerData(tracker);
                bleManager.requestImmediateBroadcast();
                HapticManager::pulseTap();
                triggerStatusLedFlash(120);
                needsRedraw = true;
            } else if (tallyEvt == ButtonHandler::LONG_PRESS) {
                tracker.startStressBuster();
                HapticManager::pulseStressBusterInhale();
                triggerStatusLedFlash(150);
                needsRedraw = true;
            }
        } else {
            // ALL OTHER PLACES (Tasks, Reminders, Logs, Summary, Brightness, QR):
            // Triggers the 10-Second Guided Breathing Stress Buster Routine!
            if (tallyEvt == ButtonHandler::CLICK || tallyEvt == ButtonHandler::LONG_PRESS) {
                tracker.startStressBuster();
                HapticManager::pulseStressBusterInhale();
                triggerStatusLedFlash(150);
                needsRedraw = true;
            }
        }
    }
}

// --------------------------------------------------------------------------
// Setup & Main Loop
// --------------------------------------------------------------------------
void setup() {
    Serial.begin(115200);
    Serial.println("\n=========================================");
    Serial.println("     CRANIUM X1 · TACTICAL COCKPIT       ");
    Serial.println("=========================================");

    trackerMutex = xSemaphoreCreateRecursiveMutex();
    esp_task_wdt_init(5, true); // 5-Second Hardware Task Watchdog Timer
    esp_task_wdt_add(NULL);     // Subscribe main loopTask to WDT

    StorageManager::init();
    StorageManager::loadTrackerData(tracker);
    HapticManager::init();

    pinMode(PIN_BOARD_LED, OUTPUT);
    digitalWrite(PIN_BOARD_LED, LOW);

    pinMode(PIN_LED_RED, OUTPUT);
    pinMode(PIN_LED_BLUE, OUTPUT);
    pinMode(PIN_HAPTIC_MOTOR, OUTPUT);
    digitalWrite(PIN_LED_RED, LOW);
    digitalWrite(PIN_LED_BLUE, LOW);
    digitalWrite(PIN_HAPTIC_MOTOR, LOW);

    // Startup Hardware Handshake: 2 rapid pulses to confirm LEDs & Haptic Motor
    digitalWrite(PIN_LED_RED, HIGH);
    digitalWrite(PIN_LED_BLUE, HIGH);
    digitalWrite(PIN_HAPTIC_MOTOR, HIGH);
    delay(120);
    digitalWrite(PIN_LED_RED, LOW);
    digitalWrite(PIN_LED_BLUE, LOW);
    digitalWrite(PIN_HAPTIC_MOTOR, LOW);
    delay(100);
    digitalWrite(PIN_LED_RED, HIGH);
    digitalWrite(PIN_LED_BLUE, HIGH);
    digitalWrite(PIN_HAPTIC_MOTOR, HIGH);
    delay(120);
    digitalWrite(PIN_LED_RED, LOW);
    digitalWrite(PIN_LED_BLUE, LOW);
    digitalWrite(PIN_HAPTIC_MOTOR, LOW);

    knobButton.init();
    tallyButton.init();
    #ifdef PIN_SESSIONS_BUTTON
    sessionsButton.init();
    #endif

    attachInterrupt(digitalPinToInterrupt(PIN_ENCODER_CLK), checkEncoderPosition, CHANGE);
    attachInterrupt(digitalPinToInterrupt(PIN_ENCODER_DT), checkEncoderPosition, CHANGE);

    Serial.println("[INIT] Initializing U8g2 Hardware I2C (400kHz)...");
    Wire.setTimeOut(50); // 50ms I2C Hardware Bus Hang Protection
    u8g2.begin();
    u8g2.setBusClock(OLED_I2C_CLOCK_SPEED);
    u8g2.setContrast(tracker.activeBrightness);

#if FEATURE_WIFI
    OledUI::renderBootSplash("CRANIUM X1", "Connecting WiFi...");
    webServer.init();
    String mdnsUrl = "http://" + String(MDNS_HOSTNAME) + ".local";
    OledUI::renderReadySplash("CRANIUM X1", webServer.currentIP, mdnsUrl.c_str());
#else
    OledUI::renderBootSplash("CRANIUM X1", "BLE 5.0 Active");
    webServer.init(); // Empty stub
    OledUI::renderReadySplash("CRANIUM X1", "BLE: CRANIUM-X1", "PAIR COMPANION APP");
#endif

    #if PIN_BOARD_LED != PIN_HAPTIC_MOTOR
    digitalWrite(PIN_BOARD_LED, HIGH);
    #endif
    bleManager.init(&tracker);
    PowerManager::init();
    delay(400);

    tracker.state = STATE_SELECT_CLIENT;
    tracker.menuIndex = 0;
    tracker.recordUserActivity();
    needsRedraw = true;

#if FEATURE_WIFI
    Serial.printf("[READY] Ready! Web dashboard live at %s\n", mdnsUrl.c_str());
#else
    Serial.println("[READY] Ready in Pure-BLE Mode! Connect companion app via Bluetooth.");
#endif
}

void loop() {
    esp_task_wdt_reset(); // Feed hardware Task Watchdog Timer

    // 1. Process Hardware Inputs
    handleEncoderInput();
    handleButtons();

    // 2. OLED Screen Saver (Idle Timeout Dimming)
    // Keep display steady at configured brightness during tracking, breathing, or menu adjustments
    bool canDim = (tracker.state != STATE_TRACKING && 
                   tracker.state != STATE_STRESS_BUSTER && 
                   tracker.state != STATE_SET_BRIGHTNESS);

    if (canDim && !tracker.isDimmed && (millis() - tracker.lastActivityMillis >= IDLE_DIM_TIMEOUT_MS)) {
        // Dim proportionally, but NEVER exceed or increase above activeBrightness
        uint8_t dimmedVal = (tracker.activeBrightness > 30) ? (tracker.activeBrightness / 3) : 10;
        if (dimmedVal > tracker.activeBrightness) {
            dimmedVal = tracker.activeBrightness;
        }
        if (dimmedVal < tracker.activeBrightness) {
            u8g2.setContrast(dimmedVal);
        }
        tracker.isDimmed = true;
    } else if (!canDim && tracker.isDimmed) {
        // Session actively running or breathing: restore steady user-configured contrast
        u8g2.setPowerSave(0);
        u8g2.setContrast(tracker.activeBrightness);
        tracker.isDimmed = false;
        needsRedraw = true;
    }

    // Micro-slide smooth transition
    if (slideOffset != 0) {
        if (slideOffset > 0) {
            slideOffset -= 4;
            if (slideOffset < 0) slideOffset = 0;
        } else {
            slideOffset += 4;
            if (slideOffset > 0) slideOffset = 0;
        }
        needsRedraw = true;
    }

    // 2. Midnight Auto-Rollover Check & Streak Calculation
    static unsigned long lastMidnightPoll = 0;
    if (millis() - lastMidnightPoll >= 10000) {
        lastMidnightPoll = millis();
        if (tracker.checkMidnightRollover()) {
            StorageManager::saveTrackerData(tracker);
            needsRedraw = true;
        }
    }

    // 3. Periodic Auto-Flush (Power-Loss Protection)
    if (tracker.state == STATE_TRACKING && (millis() - tracker.lastAutoSaveMillis >= AUTO_SAVE_INTERVAL_MS)) {
        tracker.lastAutoSaveMillis = millis();
        StorageManager::saveTrackerData(tracker);
    }

    // 4. Update timer tick & live refresh + 50/10 Break Haptic Alarm & Daily Goal Milestone
    static unsigned long lastSecondTick = 0;
    static bool wasInBreak = false;
    static bool goalAchievedAnnounced = false;
    if (tracker.state == STATE_TRACKING) {
        tracker.update();
        bool isInBreak = (tracker.currentSessionSeconds % 3600) >= 3000;
        if (isInBreak && !wasInBreak) {
            // 50m Focus session completed! 3 distinct rhythmic alert pulses
            HapticManager::pulseBreakAlert();
        } else if (!isInBreak && wasInBreak) {
            // 10m Break recovery completed! 2 energizing pulses alert back to focus
            HapticManager::pulseFocusAlert();
        }
        wasInBreak = isInBreak;

        // 10.0 Hours Daily Deep Work Milestone Check
        unsigned long currentDwToday = tracker.getGlobalDeepWorkSecondsToday() + tracker.currentSessionSeconds;
        if (currentDwToday >= tracker.globalDeepWorkGoalSeconds && !goalAchievedAnnounced) {
            goalAchievedAnnounced = true;
            HapticManager::pulseGoalAchieved();
            Serial.println("[ACHIEVEMENT] 10.0 Hours Daily Deep Work Milestone Reached! 🏆");
        } else if (currentDwToday < tracker.globalDeepWorkGoalSeconds) {
            goalAchievedAnnounced = false;
        }

        if (millis() - lastSecondTick >= 500) {
            lastSecondTick = millis();
            needsRedraw = true;
        }
    } else {
        wasInBreak = false;
    }

    // 4b. 2-Minute Guided Breathing Zen Reset Engine — 6 cycles × 20s each
    if (tracker.state == STATE_STRESS_BUSTER) {
        unsigned long elapsed = millis() - tracker.stressBusterStartMillis;
        if (elapsed >= 120000) {
            HapticManager::pulseStressBusterComplete();
            tracker.cancelStressBuster();
            needsRedraw = true;
            Serial.println("[ZEN RESET] Completed 2-minute Guided Breathing (6 cycles)! ✨");
        } else {
            // Each cycle is 20s: 6s Inhale, 4s Hold, 10s Exhale
            unsigned long cycleElapsed = elapsed % 20000;

            // Tactile feedback synchronized with breathing phases per cycle:
            // Phase 1 (0 to 6s: INHALE) — gentle rising pulses every ~1.5s
            if (cycleElapsed < 6000) {
                unsigned long phaseElapsed = cycleElapsed;
                if (tracker.lastBreathHapticMillis == 0 ||
                    (elapsed - tracker.lastBreathHapticMillis >= 1500)) {
                    HapticManager::pulseStressBusterInhale();
                    tracker.lastBreathHapticMillis = elapsed;
                }
            }
            // Phase 2 (6s to 10s: HOLD) — peaceful stillness (no vibration)
            // Phase 3 (10s to 20s: EXHALE) — soft releasing pulses every ~2s
            else if (cycleElapsed >= 10000 && cycleElapsed < 19500) {
                if (tracker.lastBreathHapticMillis == 0 ||
                    (elapsed - tracker.lastBreathHapticMillis >= 2000)) {
                    HapticManager::pulseStressBusterExhale();
                    tracker.lastBreathHapticMillis = elapsed;
                }
            }

            // Smooth ~30 FPS visual refresh for lotus rotation and fluid progress gauge
            static unsigned long lastAnimFrame = 0;
            if (millis() - lastAnimFrame >= 33) {
                lastAnimFrame = millis();
                needsRedraw = true;
            }
        }
    }

    // 4c. Hydration & Stand/Stretch Wellness Reminder Monitor
    if (tracker.wellnessEnabled && !tracker.isShowingWellnessAlert && tracker.state != STATE_STRESS_BUSTER) {
        unsigned long intervalMs = (unsigned long)tracker.wellnessIntervalMinutes * 60000UL;
        if (tracker.lastWellnessAlertMillis == 0) {
            tracker.lastWellnessAlertMillis = millis();
        } else if (millis() - tracker.lastWellnessAlertMillis >= intervalMs) {
            uint8_t kind = 0;
            if (tracker.wellnessMode == 0) { // Alternating
                kind = tracker.wellnessCycleCount % 2;
                tracker.wellnessCycleCount++;
            } else if (tracker.wellnessMode == 1) { // Water only
                kind = 0;
            } else { // Stretch only
                kind = 1;
            }
            tracker.triggerWellnessAlert(kind);
            HapticManager::pulseWellness();
            triggerStatusLedFlash(150);
            needsRedraw = true;
        }
    }

    // Auto-dismiss wellness alert after 5000ms
    if (tracker.isShowingWellnessAlert) {
        unsigned long alertElapsed = millis() - tracker.wellnessAlertStartMillis;
        if (alertElapsed >= 5000) {
            tracker.dismissWellnessAlert();
            needsRedraw = true;
        } else {
            // Smooth ~30 FPS visual refresh for rippling water / kinetic stretching animation
            static unsigned long lastWellnessAnimFrame = 0;
            if (millis() - lastWellnessAnimFrame >= 33) {
                lastWellnessAnimFrame = millis();
                needsRedraw = true;
            }
        }
    }

    // 5. Onboard LED Indicator (Active LOW on SuperMini, if not shared with Haptic Motor)
    #if PIN_BOARD_LED != PIN_HAPTIC_MOTOR
    if (tracker.isRunawaySession()) {
        digitalWrite(PIN_BOARD_LED, (millis() / 200) % 2 == 0 ? LOW : HIGH);
    } else {
        digitalWrite(PIN_BOARD_LED, tracker.state == STATE_TRACKING ? LOW : HIGH);
    }
    #endif

    // 6. Redraw display
    if (needsRedraw) {
        needsRedraw = false;
        TrackerLock lock;
        if (!tracker.isDimmed) {
            u8g2.setContrast(tracker.activeBrightness);
        }
        if (tracker.isShowingWellnessAlert) {
            OledUI::renderWellnessAlertScreen(tracker.currentWellnessAlertKind, millis() - tracker.wellnessAlertStartMillis);
        } else if (tracker.state == STATE_CONFIG_WELLNESS) {
            OledUI::renderWellnessConfigScreen();
        } else if (tracker.state == STATE_SELECT_CLIENT) {
            OledUI::renderClientSelectScreen();
        } else if (tracker.state == STATE_STRESS_BUSTER) {
            OledUI::renderStressBusterScreen(millis() - tracker.stressBusterStartMillis);
        } else if (tracker.state == STATE_VIEW_TASKS) {
            OledUI::renderTaskListScreen();
        } else if (tracker.state == STATE_VIEW_REMINDERS) {
            OledUI::renderRemindersScreen();
        } else if (tracker.state == STATE_SET_BRIGHTNESS) {
            OledUI::renderBrightnessScreen();
        } else if (tracker.state == STATE_VIEW_LOGS) {
            OledUI::renderSessionLogsScreen();
        } else if (tracker.state == STATE_VIEW_SUMMARY) {
            OledUI::renderSummaryScreen();
        } else if (tracker.state == STATE_VIEW_QR) {
#if FEATURE_WIFI
            String qUrl = "http://" + (webServer.currentIP.length() > 0 ? webServer.currentIP : "192.168.0.210");
            OledUI::renderQrCodeScreen(qUrl, webServer.currentIP);
#else
            String qUrl = "https://github.com/Boxerworksharder/cranium-x1/releases/download/v1.4/cranium_x1.apk";
            OledUI::renderQrCodeScreen(qUrl, "APK DOWNLOAD");
#endif
        } else {
            if (trackingPageView == 0) {
                OledUI::renderTrackingScreen();
            } else if (trackingPageView == 1) {
                OledUI::renderActivityHistoryScreen();
            } else {
                OledUI::renderIntervalSessionScreen();
            }
        }
    }

    // 7. Update External Indicators, Haptics & Bluetooth
    updateExternalLeds();
    HapticManager::update();
    bleManager.update();

    // 8. Power Bank Anti-Sleep Keep-Alive Active Current Pulse
    // Draws a silent 120ms active current burst every 10s unconditionally to prevent power bank sleep
    PowerManager::update();

    delay(2);
}
