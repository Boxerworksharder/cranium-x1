#pragma once
#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <ArduinoJson.h>
#include "config.h"
#include "tracker_state.h"
#include "storage_manager.h"
#include "haptic_manager.h"
#include "power_manager.h"

#define SERVICE_UUID           "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHAR_TELEMETRY_UUID    "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define CHAR_COMMAND_UUID      "6e400002-b5a3-f393-e0a9-e50e24dcca9e"

#include <BLESecurity.h>
#include <U8g2lib.h>

extern U8G2_SH1106_128X64_NONAME_F_HW_I2C u8g2;
extern bool needsRedraw;

class BLEManager;

class CraniumSecurityCallbacks : public BLESecurityCallbacks {
public:
    uint32_t onPassKeyRequest() override {
        Serial.println("[BLE SEC] PassKey Request");
        return 123456;
    }
    void onPassKeyNotify(uint32_t pass_key) override {
        Serial.printf("[BLE SEC] PassKey Notify: %d\n", pass_key);
    }
    bool onSecurityRequest() override {
        Serial.println("[BLE SEC] Security Request -> Auto-Accepted");
        return true;
    }
    void onAuthenticationComplete(esp_ble_auth_cmpl_t cmpl) override {
        if (cmpl.success) {
            Serial.println("[BLE SEC] >> Phone Pairing & Bonding SUCCESSFUL! 🎉");
        } else {
            Serial.printf("[BLE SEC] Authentication Failed: 0x%x -> Auto-clearing stale bond info\n", cmpl.fail_reason);
            esp_ble_remove_bond_device(cmpl.bd_addr);
        }
    }
    bool onConfirmPIN(uint32_t pin) override {
        Serial.printf("[BLE SEC] Confirm PIN: %d -> Auto-Confirm\n", pin);
        return true;
    }
};

class ServerCallbacks : public BLEServerCallbacks {
public:
    bool* connectedPtr;
    bool* restartAdvPtr;
    unsigned long* disconnectMillisPtr;
    ServerCallbacks(bool* conn, bool* restartAdv, unsigned long* discMillis) 
        : connectedPtr(conn), restartAdvPtr(restartAdv), disconnectMillisPtr(discMillis) {}

    void onConnect(BLEServer* pServer, esp_ble_gatts_cb_param_t *param) override {
        *connectedPtr = true;
        *restartAdvPtr = false;
        if (disconnectMillisPtr) *disconnectMillisPtr = 0;
        if (param) {
            uint8_t* bda = param->connect.remote_bda;
            Serial.printf("[BLE] >> Client Connected from %02X:%02X:%02X:%02X:%02X:%02X (conn_id: %d)\n",
                bda[0], bda[1], bda[2], bda[3], bda[4], bda[5], param->connect.conn_id);
        } else {
            Serial.println("[BLE] >> Client Connected via Phone / Companion App!");
        }
        HapticManager::trigger(40);
    }

    void onDisconnect(BLEServer* pServer, esp_ble_gatts_cb_param_t *param) override {
        *connectedPtr = false;
        *restartAdvPtr = true;
        if (param) {
            Serial.printf("[BLE] << Client Disconnected (reason: 0x%02X). Scheduling advertising restart...\n", param->disconnect.reason);
        } else {
            Serial.println("[BLE] << Client Disconnected. Scheduling advertising restart...");
        }
    }
};

class CommandCallbacks : public BLECharacteristicCallbacks {
public:
    TrackerManager* tracker;
    BLEManager* bleMgr;
    CommandCallbacks(TrackerManager* t, BLEManager* b) : tracker(t), bleMgr(b) {}

    void onWrite(BLECharacteristic* pCharacteristic) override;
};

class BLEManager {
public:
    TrackerManager* tracker = nullptr;
    BLEServer* pServer = nullptr;
    BLECharacteristic* pTelemetryChar = nullptr;
    BLECharacteristic* pCommandChar = nullptr;
    BLECharacteristic* pBatteryLevelChar = nullptr;
    bool isConnected = false;
    bool restartAdvRequested = false;
    unsigned long disconnectMillis = 0;
    unsigned long lastNotifyMillis = 0;
    unsigned long lastAdvWatchdogMillis = 0;

    void init(TrackerManager* t) {
        tracker = t;
        Serial.printf("[BLE] Initializing Bluetooth Low Energy (%s)...\n", BLE_DEVICE_NAME);

        BLEDevice::init(BLE_DEVICE_NAME);
        BLEDevice::setMTU(512);

        // 1. Setup Standard BLE Security: Just Works with Auto-Accept & Bonding
        BLEDevice::setSecurityCallbacks(new CraniumSecurityCallbacks());
        BLESecurity *pSecurity = new BLESecurity();
        pSecurity->setAuthenticationMode(ESP_LE_AUTH_REQ_SC_BOND);
        pSecurity->setCapability(ESP_IO_CAP_NONE); // Just Works: No display or keyboard required
        pSecurity->setInitEncryptionKey(ESP_BLE_ENC_KEY_MASK | ESP_BLE_ID_KEY_MASK);
        pSecurity->setRespEncryptionKey(ESP_BLE_ENC_KEY_MASK | ESP_BLE_ID_KEY_MASK);
        pSecurity->setKeySize(16);

        pServer = BLEDevice::createServer();
        pServer->setCallbacks(new ServerCallbacks(&isConnected, &restartAdvRequested, &disconnectMillis));

        // 2. Tactical Focus Engine Primary Service
        BLEService* pService = pServer->createService(SERVICE_UUID);

        pTelemetryChar = pService->createCharacteristic(
            CHAR_TELEMETRY_UUID,
            BLECharacteristic::PROPERTY_READ |
            BLECharacteristic::PROPERTY_NOTIFY
        );
        pTelemetryChar->addDescriptor(new BLE2902());

        pCommandChar = pService->createCharacteristic(
            CHAR_COMMAND_UUID,
            BLECharacteristic::PROPERTY_WRITE |
            BLECharacteristic::PROPERTY_WRITE_NR
        );
        pCommandChar->setCallbacks(new CommandCallbacks(tracker, this));
        pService->start();

        // 3. Device Information Service (0x180A)
        BLEService* pDevInfoService = pServer->createService(BLEUUID((uint16_t)0x180A));
        BLECharacteristic* pMfrChar = pDevInfoService->createCharacteristic(
            BLEUUID((uint16_t)0x2A29), BLECharacteristic::PROPERTY_READ
        );
        pMfrChar->setValue("Cranium");
        BLECharacteristic* pModelChar = pDevInfoService->createCharacteristic(
            BLEUUID((uint16_t)0x2A24), BLECharacteristic::PROPERTY_READ
        );
        pModelChar->setValue("X1 Tactical");
        BLECharacteristic* pFwChar = pDevInfoService->createCharacteristic(
            BLEUUID((uint16_t)0x2A26), BLECharacteristic::PROPERTY_READ
        );
        pFwChar->setValue("1.0.0");
        pDevInfoService->start();

        // 4. Battery Service (0x180F) - Displays Battery Status on Phone
        BLEService* pBatteryService = pServer->createService(BLEUUID((uint16_t)0x180F));
        pBatteryLevelChar = pBatteryService->createCharacteristic(
            BLEUUID((uint16_t)0x2A19),
            BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
        );
        pBatteryLevelChar->addDescriptor(new BLE2902());
        uint8_t batteryLevel = 100;
        pBatteryLevelChar->setValue(&batteryLevel, 1);
        pBatteryService->start();

        // 5. Bluetooth SIG Split-Packet Advertisement
        BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
        pAdvertising->addServiceUUID(pBatteryService->getUUID());
        pAdvertising->addServiceUUID(pService->getUUID());

        BLEAdvertisementData advData;
        advData.setFlags(0x06); // General Discoverable + BR/EDR not supported
        advData.setName(BLE_DEVICE_NAME);
        advData.setCompleteServices(BLEUUID((uint16_t)0x180F)); // Battery Service in primary packet
        pAdvertising->setAdvertisementData(advData);

        BLEAdvertisementData scanResponseData;
        scanResponseData.setCompleteServices(BLEUUID(SERVICE_UUID)); // Tactical service in scan response
        pAdvertising->setScanResponseData(scanResponseData);

        pAdvertising->setScanResponse(true);
        pAdvertising->setMinPreferred(0x06); // 7.5ms
        pAdvertising->setMaxPreferred(0x12); // 22.5ms
        pAdvertising->setMinInterval(0x20);  // 20ms advertisement interval
        pAdvertising->setMaxInterval(0x40);  // 40ms advertisement interval
        BLEDevice::startAdvertising();

        Serial.printf("[BLE] >> Bluetooth Low Energy Advertising started as '%s' (MTU: 512)!\n", BLE_DEVICE_NAME);
    }

    volatile bool immediateBroadcastRequested = false;
    bool isBroadcasting = false;

    void requestImmediateBroadcast() {
        immediateBroadcastRequested = true;
    }

    void broadcastStatus() {
        if (!isConnected || !pTelemetryChar || !tracker || isBroadcasting) return;
        if (pServer && pServer->getConnectedCount() == 0) {
            isConnected = false;
            return;
        }
        isBroadcasting = true;

        unsigned long totalDwSecs = 0;
        int pct = 0;
        const char* stateStr = "IDLE";
        int streak = 0;
        unsigned long goal = 36000;
        unsigned long sessionSecs = 0;
        int activeId = 1;
        String activeName = "Deep Coding";
        unsigned long activeTodaySecs = 0;
        int activeReps = 0;

        unsigned long totalWasteSecs = 0;
        int focusPurity = 100;
        bool activeIsNegative = false;

        {
            TrackerLock lock;
            totalDwSecs = tracker->getGlobalDeepWorkSecondsToday();
            totalWasteSecs = tracker->getGlobalWasteSecondsToday();
            focusPurity = tracker->getFocusPurityPct();
            goal = tracker->globalDeepWorkGoalSeconds > 0 ? tracker->globalDeepWorkGoalSeconds : 36000;
            pct = (totalDwSecs * 100) / goal;
            if (tracker->state == STATE_TRACKING) stateStr = "TRACKING";
            else if (tracker->state == STATE_PAUSED) stateStr = "PAUSED";
            else if (tracker->state == STATE_STRESS_BUSTER) stateStr = "STRESS_BUSTER";
            streak = tracker->currentStreakDays;
            sessionSecs = tracker->currentSessionSeconds;
            ClientInfo& c = tracker->getActiveClient();
            activeId = c.id;
            activeName = c.name;
            activeTodaySecs = c.totalSecondsToday;
            activeReps = c.tallyCount;
            activeIsNegative = c.isNegative;
        }

        JsonDocument doc;
        doc["state"] = stateStr;
        doc["dwSecs"] = totalDwSecs;
        doc["wasteSecs"] = totalWasteSecs;
        doc["focusPurityPct"] = focusPurity;
        doc["pct"] = pct;
        doc["streak"] = streak;
        doc["goal"] = goal;
        doc["sessionSecs"] = sessionSecs;
        doc["client"] = activeName;
        doc["clientId"] = activeId;
        doc["isNegative"] = activeIsNegative;
        doc["todaySecs"] = activeTodaySecs;
        doc["reps"] = activeReps;
        doc["brightness"] = tracker->activeBrightness;
        doc["powerbank"] = PowerManager::keepAliveEnabled;

        // Compact client list for companion app synchronization
        JsonArray cArr = doc["clients"].to<JsonArray>();
        size_t maxClients = tracker->clients.size() > 16 ? 16 : tracker->clients.size();
        for (size_t i = 0; i < maxClients; i++) {
            JsonObject o = cArr.add<JsonObject>();
            o["id"] = tracker->clients[i].id;
            o["name"] = tracker->clients[i].name;
            o["todaySecs"] = tracker->clients[i].totalSecondsToday;
            o["reps"] = tracker->clients[i].tallyCount;
            o["isNegative"] = tracker->clients[i].isNegative;
        }

        // Tasks list for companion app synchronization
        JsonArray taskArr = doc["tasks"].to<JsonArray>();
        size_t maxTasks = tracker->tasks.size() > 16 ? 16 : tracker->tasks.size();
        for (size_t i = 0; i < maxTasks; i++) {
            JsonObject tObj = taskArr.add<JsonObject>();
            tObj["id"] = tracker->tasks[i].id;
            tObj["text"] = tracker->tasks[i].text;
            tObj["stars"] = tracker->tasks[i].stars;
            tObj["done"] = tracker->tasks[i].done;
            tObj["created"] = tracker->tasks[i].createdAt;
        }

        // Reminders list for companion app synchronization
        JsonArray remArr = doc["reminders"].to<JsonArray>();
        size_t maxReminders = tracker->reminders.size() > 16 ? 16 : tracker->reminders.size();
        for (size_t i = 0; i < maxReminders; i++) {
            JsonObject rObj = remArr.add<JsonObject>();
            rObj["id"] = tracker->reminders[i].id;
            rObj["text"] = tracker->reminders[i].text;
            rObj["created"] = tracker->reminders[i].createdAt;
        }

        JsonArray checklistArr = doc["checklist"].to<JsonArray>();
        size_t maxChecklist = tracker->checklist.size() > 20 ? 20 : tracker->checklist.size();
        for (size_t i = 0; i < maxChecklist; i++) {
            JsonObject cObj = checklistArr.add<JsonObject>();
            cObj["id"] = tracker->checklist[i].id;
            cObj["text"] = tracker->checklist[i].text;
            cObj["done"] = tracker->checklist[i].done;
        }
        String payload;
        serializeJson(doc, payload);

        // Safe chunking: ESP32 BLE characteristic buffer cannot exceed 512/600 bytes.
        // Chunking at 180 bytes guarantees every notification packet fits standard ATT MTU
        // and completely eliminates BTC_TASK stack overflows.
        const size_t MAX_BLE_CHUNK = 180;
        size_t totalLen = payload.length();
        if (totalLen <= MAX_BLE_CHUNK) {
            pTelemetryChar->setValue((uint8_t*)payload.c_str(), totalLen);
            pTelemetryChar->notify();
        } else {
            size_t offset = 0;
            while (offset < totalLen && isConnected) {
                if (pServer && pServer->getConnectedCount() == 0) {
                    isConnected = false;
                    break;
                }
                size_t len = (totalLen - offset > MAX_BLE_CHUNK) ? MAX_BLE_CHUNK : (totalLen - offset);
                pTelemetryChar->setValue((uint8_t*)(payload.c_str() + offset), len);
                pTelemetryChar->notify();
                offset += len;
                if (offset < totalLen) {
                    vTaskDelay(pdMS_TO_TICKS(15));
                }
            }
        }
        isBroadcasting = false;
    }

    void update() {
        unsigned long now = millis();

        // 1. Safe, non-blocking advertising restart after disconnect
        if (!isConnected && restartAdvRequested) {
            restartAdvRequested = false;
            disconnectMillis = now;
        }

        // Allow FreeRTOS BLE stack 150ms to cleanly free socket before re-starting advertising
        if (!isConnected && disconnectMillis > 0 && (now - disconnectMillis >= 150)) {
            disconnectMillis = 0;
            if (pServer) {
                pServer->startAdvertising();
                Serial.println("[BLE] >> Advertising restarted cleanly!");
            }
        }

        // 2. Continuous Advertising Watchdog: Ensure device is ALWAYS discoverable when idle
        if (!isConnected && (now - lastAdvWatchdogMillis >= 4000)) {
            lastAdvWatchdogMillis = now;
            BLEDevice::startAdvertising();
        }

        // 3. Periodic Telemetry Stream (1Hz) or Immediate Command Echo when client is actively connected
        if (isConnected && (immediateBroadcastRequested || (now - lastNotifyMillis >= 1000))) {
            immediateBroadcastRequested = false;
            lastNotifyMillis = now;
            broadcastStatus();
        }
    }
};

inline void CommandCallbacks::onWrite(BLECharacteristic* pCharacteristic) {
    String rxValue = pCharacteristic->getValue().c_str();
    if (rxValue.length() == 0) return;

    if (rxValue.length() > 2048) {
        Serial.println("[BLE SEC] Payload rejected: Exceeds maximum limit!");
        return;
    }

    Serial.printf("[BLE CMD] Received: %s\n", rxValue.c_str());

    JsonDocument doc;
    DeserializationError error = deserializeJson(doc, rxValue);
    if (error) {
        Serial.printf("[BLE CMD] JSON error: %s\n", error.c_str());
        return;
    }

    {
        TrackerLock lock;
        tracker->recordUserActivity();
        const char* action = doc["action"] | "";

        if (strcmp(action, "start") == 0) {
            int clientIndex = doc["index"] | -1;
            int targetId = doc["id"] | -1;
            if (targetId >= 0) {
                for (size_t i = 0; i < tracker->clients.size(); i++) {
                    if (tracker->clients[i].id == targetId) {
                        clientIndex = (int)i;
                        break;
                    }
                }
            }
            if (clientIndex < 0) clientIndex = tracker->activeClientIndex;
            if (clientIndex >= 0 && clientIndex < (int)tracker->clients.size()) {
                tracker->activeClientIndex = clientIndex;
                if (tracker->state == STATE_PAUSED) {
                    tracker->togglePause();
                    HapticManager::pulseResume();
                } else if (tracker->state != STATE_TRACKING) {
                    tracker->startTracking();
                    HapticManager::pulseStart();
                }
                needsRedraw = true;
            }
        } else if (strcmp(action, "select") == 0 || strcmp(action, "select_client") == 0) {
            int targetId = doc["id"] | -1;
            int idx = doc["index"] | -1;
            if (targetId >= 0) {
                for (size_t i = 0; i < tracker->clients.size(); i++) {
                    if (tracker->clients[i].id == targetId) {
                        tracker->activeClientIndex = (int)i;
                        tracker->menuIndex = (int)i;
                        HapticManager::pulseTap();
                        needsRedraw = true;
                        break;
                    }
                }
            } else if (idx >= 0 && idx < (int)tracker->clients.size()) {
                tracker->activeClientIndex = idx;
                tracker->menuIndex = idx;
                HapticManager::pulseTap();
                needsRedraw = true;
            }
        } else if (strcmp(action, "pause") == 0) {
            if (tracker->state == STATE_TRACKING) {
                tracker->togglePause();
                HapticManager::pulsePause();
                needsRedraw = true;
            }
        } else if (strcmp(action, "resume") == 0) {
            if (tracker->state == STATE_PAUSED) {
                tracker->togglePause();
                HapticManager::pulseResume();
                needsRedraw = true;
            }
        } else if (strcmp(action, "toggle") == 0) {
            tracker->togglePause();
            if (tracker->state == STATE_TRACKING) HapticManager::pulseResume();
            else HapticManager::pulsePause();
            needsRedraw = true;
        } else if (strcmp(action, "stop") == 0) {
            tracker->stopAndSave();
            tracker->markDirty();
            HapticManager::pulseStop();
            needsRedraw = true;
        } else if (strcmp(action, "rep_plus") == 0 || strcmp(action, "tally_plus") == 0) {
            tracker->incrementTally();
            tracker->markDirty();
            HapticManager::pulseTally();
            needsRedraw = true;
        } else if (strcmp(action, "rep_minus") == 0 || strcmp(action, "tally_minus") == 0) {
            tracker->decrementTally();
            tracker->markDirty();
            HapticManager::pulseTallyMinus();
            needsRedraw = true;
        } else if (strcmp(action, "goal") == 0) {
            unsigned long newGoal = doc["value"] | 36000;
            if (newGoal >= 1800 && newGoal <= 86400) {
                tracker->globalDeepWorkGoalSeconds = newGoal;
                tracker->markDirty();
                needsRedraw = true;
            }
        } else if (strcmp(action, "reset_all") == 0) {
            tracker->resetAllData();
            StorageManager::saveTrackerData(*tracker);
            HapticManager::pulseStop();
            needsRedraw = true;
        } else if (strcmp(action, "set_brightness") == 0 || strcmp(action, "brightness") == 0) {
            int b = doc["level"] | (doc["value"] | -1);
            if (b >= 10 && b <= 255) {
                tracker->setBrightness((uint8_t)b);
                tracker->markDirty();
                HapticManager::pulseTap();
                needsRedraw = true;
            }
        } else if (strcmp(action, "stress_buster") == 0) {
            if (tracker->state == STATE_STRESS_BUSTER) {
                tracker->cancelStressBuster();
                HapticManager::pulseTap();
            } else {
                tracker->startStressBuster();
                HapticManager::pulseStressBusterInhale();
            }
            needsRedraw = true;
        } else if (strcmp(action, "sync_time") == 0) {
            time_t epoch = doc["epoch"] | 0;
            int tz_offset = doc["tz_offset"] | 19800;
            if (epoch > 1700000000) {
                configTime(tz_offset, 0, "pool.ntp.org", "time.nist.gov");
                struct timeval tv = { .tv_sec = epoch, .tv_usec = 0 };
                settimeofday(&tv, nullptr);
                Serial.printf("[RTC] Synced real-world time from phone: %ld (TZ: %d)\n", (long)epoch, tz_offset);
                HapticManager::pulseTap();
            }
        } else if (strcmp(action, "powerbank") == 0) {
            if (!doc["enabled"].isNull()) {
                PowerManager::setEnabled(doc["enabled"].as<bool>());
                tracker->markDirty();
                HapticManager::pulseTap();
            }
        } else if (strcmp(action, "add_section") == 0 || strcmp(action, "add_client") == 0) {
            const char* name = doc["name"] | "New Section";
            bool isNegative = doc["isNegative"] | false;
            tracker->addClient(name, isNegative);
            tracker->markDirty();
            HapticManager::pulseTap();
            needsRedraw = true;
        } else if (strcmp(action, "toggle_negative") == 0 || strcmp(action, "toggle_section_negative") == 0) {
            int targetId = doc["id"] | -1;
            int isNeg = -1;
            if (!doc["isNegative"].isNull()) {
                isNeg = doc["isNegative"].as<bool>() ? 1 : 0;
            }
            for (auto& cl : tracker->clients) {
                if (cl.id == targetId) {
                    if (isNeg >= 0) cl.isNegative = (isNeg == 1);
                    else cl.isNegative = !cl.isNegative;
                    tracker->markDirty();
                    HapticManager::pulseTap();
                    needsRedraw = true;
                    break;
                }
            }
        } else if (strcmp(action, "update_section") == 0) {
            int targetId = doc["id"] | -1;
            String name = doc["name"] | "";
            int reps = doc["reps"] | -1;
            long totalSecs = doc["todaySecs"] | (doc["totalSecs"] | -1);
            int isNeg = -1;
            if (!doc["isNegative"].isNull()) {
                isNeg = doc["isNegative"].as<bool>() ? 1 : 0;
            }
            if (targetId >= 0) {
                tracker->updateClient(targetId, name, reps, totalSecs, isNeg);
                tracker->markDirty();
                HapticManager::pulseTap();
                needsRedraw = true;
            }
        } else if (strcmp(action, "delete_section") == 0) {
            int targetId = doc["id"] | -1;
            if (targetId >= 0 && tracker->clients.size() > 1) {
                tracker->removeClient(targetId);
                tracker->markDirty();
                HapticManager::pulseTap();
                needsRedraw = true;
            }
        } else if (strcmp(action, "wellness") == 0) {
            if (!doc["enabled"].isNull()) {
                tracker->wellnessEnabled = doc["enabled"].as<bool>();
            }
            if (!doc["interval"].isNull()) {
                tracker->setWellnessInterval(doc["interval"].as<int>());
            }
            if (!doc["mode"].isNull()) {
                tracker->wellnessMode = doc["mode"].as<int>() % 3;
            }
            tracker->markDirty();
            HapticManager::pulseTap();
            needsRedraw = true;
        } else if (strcmp(action, "test_wellness") == 0) {
            int kind = doc["kind"] | 0;
            tracker->triggerWellnessAlert((uint8_t)kind);
            HapticManager::pulseTap();
            needsRedraw = true;
        } else if (strcmp(action, "add_task") == 0) {
            const char* text = doc["text"] | "";
            int stars = doc["stars"] | 1;
            tracker->addTask(text, stars);
            tracker->markDirty();
            HapticManager::pulseTap();
            needsRedraw = true;
        } else if (strcmp(action, "toggle_task") == 0) {
            int id = doc["id"] | -1;
            if (id >= 0) tracker->toggleTask(id);
            tracker->markDirty();
            HapticManager::pulseTap();
            needsRedraw = true;
        } else if (strcmp(action, "delete_task") == 0) {
            int id = doc["id"] | -1;
            if (id >= 0) tracker->deleteTask(id);
            tracker->markDirty();
            HapticManager::pulseTap();
            needsRedraw = true;
        } else if (strcmp(action, "add_reminder") == 0) {
            const char* text = doc["text"] | "";
            tracker->addReminder(text);
            tracker->markDirty();
            HapticManager::pulseTap();
            needsRedraw = true;
        } else if (strcmp(action, "update_task") == 0) {
            int id = doc["id"] | -1;
            String text = doc["text"] | "";
            int stars = doc["stars"] | -1;
            int done = -1;
            if (!doc["done"].isNull()) {
                done = doc["done"].as<bool>() ? 1 : 0;
            }
            if (id >= 0) tracker->updateTask(id, text, stars, done);
            tracker->markDirty();
            HapticManager::pulseTap();
            needsRedraw = true;
        } else if (strcmp(action, "delete_reminder") == 0) {
            int id = doc["id"] | -1;
            if (id >= 0) tracker->deleteReminder(id);
            tracker->markDirty();
            HapticManager::pulseTap();
            needsRedraw = true;
        } else if (strcmp(action, "save_checklist") == 0) {
            if (doc["items"].is<JsonArray>()) {
                tracker->checklist.clear();
                JsonArray arr = doc["items"].as<JsonArray>();
                for (JsonObject c : arr) {
                    ChecklistItem item;
                    item.id = c["id"] | (int)(tracker->checklist.size() + 1);
                    item.text = c["text"] | "Item";
                    item.done = c["done"] | false;
                    tracker->checklist.push_back(item);
                }
                tracker->checklistScrollIndex = 0;
                tracker->markDirty();
                needsRedraw = true;
            }
        } else if (strcmp(action, "update_reminder") == 0) {
            int id = doc["id"] | -1;
            String text = doc["text"] | "";
            if (id >= 0) tracker->updateReminder(id, text);
            tracker->markDirty();
            HapticManager::pulseTap();
            needsRedraw = true;
        }
    }

    if (bleMgr) {
        bleMgr->requestImmediateBroadcast();
    }
}
