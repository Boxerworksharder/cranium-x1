#pragma once
#include <Arduino.h>
#include "config.h"

#if FEATURE_WIFI
#include <WiFi.h>
#include <WebServer.h>
#include <DNSServer.h>
#include <ESPmDNS.h>
#include <ArduinoJson.h>
#include <time.h>
#include "tracker_state.h"
#include "storage_manager.h"
#include "web_assets.h"
#include "haptic_manager.h"
#include <U8g2lib.h>
#include <esp_wifi.h>
#include "power_manager.h"

extern U8G2_SH1106_128X64_NONAME_F_HW_I2C u8g2;
extern bool needsRedraw;
void triggerStatusLedFlash(unsigned long durationMs);

class DeskTrackerWebServer {
public:
    WebServer server{80};
    DNSServer dnsServer;
    String currentIP = "192.168.0.104";
    bool wifiConnected = false;
    bool isAwayMode = false;

    void init() {
        setupWiFi();
        setupRoutes();
        server.begin();
        Serial.println("[HTTP] Web server started on port 80");

        xTaskCreate(
            webServerTask,
            "WebWorkerTask",
            6144,
            this,
            1,
            nullptr
        );
        Serial.println("[FreeRTOS] Web Server isolated in background thread.");
    }

    void handle() {
        if (!wifiConnected) {
            dnsServer.processNextRequest();
        }
        server.handleClient();
    }

    void sendChunked(int code, const char* contentType, const String& content) {
        server.setContentLength(content.length());
        server.send(code, contentType, "");
        const size_t chunkSize = 1436;
        size_t total = content.length();
        size_t sent = 0;
        while (sent < total) {
            size_t toSend = total - sent;
            if (toSend > chunkSize) toSend = chunkSize;
            server.sendContent(content.c_str() + sent, toSend);
            sent += toSend;
            vTaskDelay(pdMS_TO_TICKS(1));
        }
    }

    void sendChunked_P(int code, const char* contentType, const uint8_t* data, size_t dataLen) {
        server.setContentLength(dataLen);
        server.send(code, contentType, "");
        const size_t chunkSize = 1436;
        size_t sent = 0;
        while (sent < dataLen) {
            size_t toSend = dataLen - sent;
            if (toSend > chunkSize) toSend = chunkSize;
            server.sendContent_P((PGM_P)(data + sent), toSend);
            sent += toSend;
            vTaskDelay(pdMS_TO_TICKS(1));
        }
    }

private:
    static void webServerTask(void* param) {
        DeskTrackerWebServer* self = static_cast<DeskTrackerWebServer*>(param);
        while (true) {
            self->handle();
            vTaskDelay(pdMS_TO_TICKS(4));
        }
    }

    void setupWiFi() {
        Serial.printf("\n[WIFI] Initializing Station Mode for: '%s'...\n", WIFI_SSID);
        WiFi.disconnect(true);
        delay(100);
        WiFi.persistent(false);
        WiFi.setAutoReconnect(true);
        WiFi.mode(WIFI_STA);
        WiFi.setTxPower(WIFI_POWER_11dBm);
        esp_wifi_set_protocol(WIFI_IF_STA, WIFI_PROTOCOL_11B | WIFI_PROTOCOL_11G | WIFI_PROTOCOL_11N);
        
        WiFi.onEvent([this](WiFiEvent_t event, WiFiEventInfo_t info) {
            if (event == ARDUINO_EVENT_WIFI_STA_GOT_IP) {
                currentIP = WiFi.localIP().toString();
                wifiConnected = true;
                Serial.printf("\n[WIFI EVENT] >>> GOT IP: %s\n", currentIP.c_str());
                configTime(NTP_GMT_OFFSET_SEC, NTP_DAYLIGHT_OFFSET_SEC, NTP_SERVER_PRIMARY, NTP_SERVER_SECONDARY);
                Serial.println("[NTP] Real-World Clock Sync Initiated");
            } else if (event == ARDUINO_EVENT_WIFI_STA_DISCONNECTED) {
                wifiConnected = false;
                Serial.printf("\n[WIFI EVENT] Disconnected (%d).\n", info.wifi_sta_disconnected.reason);
            }
        });

        WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

        unsigned long start = millis();
        while (WiFi.status() != WL_CONNECTED && millis() - start < WIFI_CONNECT_TIMEOUT_MS) {
            delay(400);
            Serial.print(".");
        }
        Serial.println();

        if (WiFi.status() == WL_CONNECTED) {
            wifiConnected = true;
            isAwayMode = false;
            currentIP = WiFi.localIP().toString();
            configTime(NTP_GMT_OFFSET_SEC, NTP_DAYLIGHT_OFFSET_SEC, NTP_SERVER_PRIMARY, NTP_SERVER_SECONDARY);
            Serial.printf("[WIFI] >>> CONNECTED! IP: %s\n", currentIP.c_str());
        } else {
            wifiConnected = false;
            isAwayMode = true;
            Serial.printf("[WIFI] Home WiFi timeout. Activating Away-Mode SoftAP '%s'...\n", SOFTAP_SSID);
            WiFi.mode(WIFI_AP_STA);
            WiFi.setTxPower(WIFI_POWER_19_5dBm);
            IPAddress apIP = SOFTAP_IP;
            IPAddress netMsk(255, 255, 255, 0);
            WiFi.softAPConfig(apIP, apIP, netMsk);
            WiFi.softAP(SOFTAP_SSID, SOFTAP_PASSWORD, 6, 0, 4);
            currentIP = WiFi.softAPIP().toString();
            dnsServer.start(53, "*", apIP);
            Serial.printf("[WIFI] SoftAP Active: '%s' | IP: %s\n", SOFTAP_SSID, currentIP.c_str());
        }

        if (MDNS.begin(MDNS_HOSTNAME)) {
            MDNS.addService("http", "tcp", 80);
            Serial.printf("[mDNS] Responder started: http://%s.local\n", MDNS_HOSTNAME);
        }
    }

    void sendCORS() {
        server.sendHeader("Access-Control-Allow-Origin", "*");
        server.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
        server.sendHeader("Access-Control-Allow-Headers", "Content-Type");
    }

    void registerOptions(const char* uri) {
        server.on(uri, HTTP_OPTIONS, [this]() {
            sendCORS();
            server.send(204);
        });
    }

    void setupRoutes() {
        registerOptions("/api/status");
        registerOptions("/api/quick");
        registerOptions("/api/goal");
        registerOptions("/api/action");
        registerOptions("/api/reset");
        registerOptions("/api/sections/add");
        registerOptions("/api/sections/update");
        registerOptions("/api/sections/delete");
        registerOptions("/api/section/add");
        registerOptions("/api/section/delete");
        registerOptions("/api/client/add");
        registerOptions("/api/client/delete");
        registerOptions("/api/history/add");
        registerOptions("/api/history/delete");
        registerOptions("/api/tasks");
        registerOptions("/api/tasks/add");
        registerOptions("/api/tasks/toggle");
        registerOptions("/api/tasks/delete");
        registerOptions("/api/tasks/update");
        registerOptions("/api/reminders");
        registerOptions("/api/reminders/add");
        registerOptions("/api/reminders/delete");
        registerOptions("/api/export/sessions.csv");
        registerOptions("/api/export/summary.csv");
        registerOptions("/api/backup.json");
        registerOptions("/api/restore.json");
        registerOptions("/api/stress_buster");
        registerOptions("/api/brightness");
        registerOptions("/api/wellness");
        registerOptions("/api/wellness/test");
        registerOptions("/api/powerbank");
        auto sendDashboard = [this]() {
            server.sendHeader("Content-Encoding", "gzip");
            server.sendHeader("Cache-Control", "no-cache, no-store, must-revalidate");
            server.sendHeader("Pragma", "no-cache");
            server.sendHeader("Expires", "0");
            sendChunked_P(200, "text/html", DASHBOARD_HTML_GZ, DASHBOARD_HTML_GZ_LEN);
        };
        server.on("/", HTTP_GET, sendDashboard);
        server.on("/index.html", HTTP_GET, sendDashboard);

        server.on("/manifest.json", HTTP_GET, [this]() {
            const char manifest[] PROGMEM = "{\"name\":\"CRANIUM X1 Focus Engine\",\"short_name\":\"Cranium X1\",\"start_url\":\"/\",\"display\":\"standalone\",\"background_color\":\"#0B0C10\",\"theme_color\":\"#FF5500\",\"icons\":[{\"src\":\"/icon.svg\",\"sizes\":\"192x192 512x512\",\"type\":\"image/svg+xml\",\"purpose\":\"any maskable\"}]}";
            server.send(200, "application/manifest+json", manifest);
        });

        server.on("/sw.js", HTTP_GET, [this]() {
            const char sw[] PROGMEM = "self.addEventListener('install',e=>self.skipWaiting());self.addEventListener('activate',e=>{caches.keys().then(k=>Promise.all(k.map(c=>caches.delete(c))));self.clients.claim();});";
            server.send(200, "application/javascript", sw);
        });

        server.on("/icon.svg", HTTP_GET, [this]() {
            const char iconSvg[] PROGMEM = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 512 512'><rect width='512' height='512' rx='100' fill='#F1EDE2'/><line x1='170' y1='140' x2='230' y2='200' stroke='#C66846' stroke-width='7' stroke-linecap='round'/><line x1='290' y1='100' x2='230' y2='200' stroke='#C66846' stroke-width='7' stroke-linecap='round'/><line x1='180' y1='280' x2='230' y2='200' stroke='#C66846' stroke-width='7' stroke-linecap='round'/><line x1='230' y1='200' x2='330' y2='170' stroke='#C66846' stroke-width='7' stroke-linecap='round'/><line x1='230' y1='200' x2='290' y2='290' stroke='#C66846' stroke-width='7' stroke-linecap='round'/><circle cx='170' cy='140' r='22' fill='#C66846'/><circle cx='290' cy='100' r='20' fill='#C66846'/><circle cx='230' cy='200' r='24' fill='#C66846'/><circle cx='180' cy='280' r='20' fill='#C66846'/><circle cx='290' cy='290' r='22' fill='#C66846'/><circle cx='330' cy='170' r='26' fill='#C66846'/><path d='M340 90 C390 110 400 170 370 220 C340 240 400 290 360 370 C350 400 330 430 320 440' fill='none' stroke='#15181E' stroke-width='12' stroke-linecap='round'/><path d='M240 440 C230 370 240 310 270 270 C280 260 290 280 300 340' fill='none' stroke='#15181E' stroke-width='10' stroke-linecap='round'/></svg>";
            server.send(200, "image/svg+xml", iconSvg);
        });

        server.on("/api/status", HTTP_GET, [this]() {
            sendCORS();
            String res;
            {
                TrackerLock lock;
                JsonDocument doc;
                if (tracker.state == STATE_TRACKING) {
                    doc["state"] = "TRACKING";
                } else if (tracker.state == STATE_PAUSED) {
                    doc["state"] = "PAUSED";
                } else if (tracker.state == STATE_STRESS_BUSTER) {
                    doc["state"] = "STRESS_BUSTER";
                } else {
                    doc["state"] = "IDLE";
                }

                doc["currentStreak"] = tracker.currentStreakDays;
                doc["longestStreak"] = tracker.longestStreakDays;

                doc["activeClientId"] = tracker.getActiveClient().id;
                doc["sessionSeconds"] = tracker.currentSessionSeconds;
                doc["globalDeepWorkSecondsToday"] = tracker.getGlobalDeepWorkSecondsToday();
                doc["globalWasteSecondsToday"] = tracker.getGlobalWasteSecondsToday();
                doc["focusPurityPct"] = tracker.getFocusPurityPct();
                doc["globalGoal"] = tracker.globalDeepWorkGoalSeconds;
                doc["systemTimestamp"] = getSystemTimestamp();
                doc["systemDate"] = getSystemDate();
                doc["isRunaway"] = tracker.isRunawaySession();
                doc["brightness"] = tracker.activeBrightness;
                doc["brightnessPct"] = (tracker.activeBrightness * 100) / 255;
                doc["wellnessEnabled"] = tracker.wellnessEnabled;
                doc["wellnessIntervalMinutes"] = tracker.wellnessIntervalMinutes;
                doc["wellnessMode"] = tracker.wellnessMode;
                doc["powerbankKeepAlive"] = PowerManager::keepAliveEnabled;
                doc["awayMode"] = isAwayMode;

                JsonArray clientArr = doc["clients"].to<JsonArray>();
                for (const auto& c : tracker.clients) {
                    JsonObject cObj = clientArr.add<JsonObject>();
                    cObj["id"] = c.id;
                    cObj["name"] = c.name;
                    cObj["totalSecsToday"] = c.totalSecondsToday;
                    
                    unsigned long totalAllTime = c.totalSecondsToday;
                    for (const auto& h : c.history) totalAllTime += h.seconds;
                    if ((tracker.state == STATE_TRACKING || tracker.state == STATE_PAUSED) && c.id == tracker.getActiveClient().id) {
                        totalAllTime += tracker.currentSessionSeconds;
                    }
                    cObj["totalAccumulatedSecs"] = totalAllTime;
                    cObj["reps"] = c.tallyCount;
                    cObj["isNegative"] = c.isNegative;

                    JsonArray histArr = cObj["history"].to<JsonArray>();
                    size_t count = 0;
                    for (const auto& h : c.history) {
                        if (++count > 15) break; // Keep telemetry payload compact and sub-millisecond fast
                        JsonObject hObj = histArr.add<JsonObject>();
                        hObj["timestamp"] = h.timestamp;
                        hObj["date"] = h.dateLabel;
                        hObj["secs"] = h.seconds;
                        hObj["reps"] = h.reps;
                    }
                }

                JsonArray taskArr = doc["tasks"].to<JsonArray>();
                for (const auto& t : tracker.tasks) {
                    JsonObject tObj = taskArr.add<JsonObject>();
                    tObj["id"] = t.id;
                    tObj["text"] = t.text;
                    tObj["stars"] = t.stars;
                    tObj["done"] = t.done;
                    tObj["created"] = t.createdAt;
                }

                JsonArray remArr = doc["reminders"].to<JsonArray>();
                for (const auto& r : tracker.reminders) {
                    JsonObject rObj = remArr.add<JsonObject>();
                    rObj["id"] = r.id;
                    rObj["text"] = r.text;
                    rObj["created"] = r.createdAt;
                }

                serializeJson(doc, res);
            }
            sendChunked(200, "application/json", res);
        });

        // #13 — Lightweight Quick Stats for Widgets
        server.on("/api/quick", HTTP_GET, [this]() {
            sendCORS();
            char jsonBuf[320];
            {
                TrackerLock lock;
                unsigned long dwSecs = tracker.getGlobalDeepWorkSecondsToday();
                int pct = (dwSecs * 100) / tracker.globalDeepWorkGoalSeconds;
                if (pct > 100) pct = 100;

                unsigned int h = dwSecs / 3600;
                unsigned int m = (dwSecs % 3600) / 60;
                char dwBuf[16];
                snprintf(dwBuf, sizeof(dwBuf), "%uh %02um", h, m);

                unsigned long sessSecs = tracker.currentSessionSeconds;
                char sessBuf[12];
                snprintf(sessBuf, sizeof(sessBuf), "%02lu:%02lu:%02lu", sessSecs/3600, (sessSecs%3600)/60, sessSecs%60);

                const char* st = "IDLE";
                if (tracker.state == STATE_TRACKING) st = "TRACKING";
                else if (tracker.state == STATE_PAUSED) st = "PAUSED";

                snprintf(jsonBuf, sizeof(jsonBuf),
                    "{\"dw\":\"%s\",\"pct\":%d,\"streak\":%d,\"state\":\"%s\",\"session\":\"%s\",\"goal\":%lu,\"brightness\":%d,\"brightnessPct\":%d}",
                    dwBuf, pct, tracker.currentStreakDays, st, sessBuf, tracker.globalDeepWorkGoalSeconds,
                    tracker.activeBrightness, (tracker.activeBrightness * 100) / 255);
            }
            server.send(200, "application/json", jsonBuf);
        });

        // Instant Dynamic SVG QR Code Endpoint (Deprecated / Disabled)
        server.on("/api/qrcode", HTTP_GET, [this]() {
            sendCORS();
            server.send(404, "text/plain", "QR code feature disabled");
        });

        server.on("/qrcode.svg", HTTP_GET, [this]() {
            sendCORS();
            server.send(404, "text/plain", "QR code feature disabled");
        });

        // #15 — Update Daily Deep Work Goal
        server.on("/api/goal", HTTP_POST, [this]() {
            sendCORS();
            TrackerLock lock;
            if (!server.hasArg("plain")) {
                server.send(400, "application/json", "{\"error\":\"Missing body\"}");
                return;
            }
            JsonDocument doc;
            deserializeJson(doc, server.arg("plain"));
            unsigned long newGoal = doc["goal"] | 0;
            if (newGoal >= 1800 && newGoal <= 86400) { // 30min to 24h
                tracker.globalDeepWorkGoalSeconds = newGoal;
                StorageManager::saveTrackerData(tracker);
                needsRedraw = true;
                char resp[64];
                snprintf(resp, sizeof(resp), "{\"status\":\"goal_updated\",\"goal\":%lu}", newGoal);
                server.send(200, "application/json", resp);
            } else {
                server.send(400, "application/json", "{\"error\":\"Goal must be between 1800 and 86400 seconds\"}");
            }
        });

        server.on("/api/action", HTTP_POST, [this]() {
            sendCORS();
            TrackerLock lock;
            if (!server.hasArg("plain")) {
                server.send(400, "application/json", "{\"error\":\"Missing body\"}");
                return;
            }
            JsonDocument doc;
            DeserializationError err = deserializeJson(doc, server.arg("plain"));
            if (err) {
                server.send(400, "application/json", "{\"error\":\"Invalid JSON\"}");
                return;
            }

            String act = doc["action"] | "";
            if (act == "start") {
                if (tracker.state == STATE_STRESS_BUSTER) {
                    tracker.cancelStressBuster();
                }
                int targetId = doc["id"] | -1;
                int idx = doc["index"] | -1;
                if (targetId >= 0) {
                    for (size_t i = 0; i < tracker.clients.size(); i++) {
                        if (tracker.clients[i].id == targetId) {
                            tracker.activeClientIndex = i;
                            tracker.menuIndex = i;
                            break;
                        }
                    }
                } else if (idx >= 0 && idx < (int)tracker.clients.size()) {
                    tracker.activeClientIndex = idx;
                    tracker.menuIndex = idx;
                }
                if (tracker.state == STATE_PAUSED) {
                    tracker.togglePause();
                    HapticManager::pulseResume();
                } else if (tracker.state != STATE_TRACKING) {
                    tracker.startTracking();
                    HapticManager::pulseStart();
                }
            } else if (act == "pause") {
                if (tracker.state == STATE_TRACKING) {
                    tracker.togglePause();
                    HapticManager::pulsePause();
                }
            } else if (act == "resume") {
                if (tracker.state == STATE_PAUSED) {
                    tracker.togglePause();
                    HapticManager::pulseResume();
                }
            } else if (act == "stop") {
                if (tracker.state == STATE_STRESS_BUSTER) {
                    tracker.cancelStressBuster();
                    needsRedraw = true;
                }
                String customTimestamp = doc["timestamp"] | "";
                String customDate = doc["date"] | "";
                tracker.stopAndSave(customTimestamp, customDate);
                StorageManager::saveTrackerData(tracker);
                HapticManager::pulseStop();
            } else if (act == "rep_plus") {
                tracker.incrementTally();
                StorageManager::saveTrackerData(tracker);
                HapticManager::pulseTally();
            } else if (act == "rep_minus") {
                tracker.decrementTally();
                StorageManager::saveTrackerData(tracker);
                HapticManager::pulseTallyMinus();
            } else if (act == "select" || act == "select_client") {
                int targetId = doc["id"] | -1;
                int idx = doc["index"] | -1;
                if (targetId >= 0) {
                    for (size_t i = 0; i < tracker.clients.size(); i++) {
                        if (tracker.clients[i].id == targetId) {
                            tracker.activeClientIndex = i;
                            tracker.menuIndex = i;
                            HapticManager::pulseTap();
                            break;
                        }
                    }
                } else if (idx >= 0 && idx < (int)tracker.clients.size()) {
                    tracker.activeClientIndex = idx;
                    tracker.menuIndex = idx;
                    HapticManager::pulseTap();
                }
            } else if (act == "reset_all") {
                tracker.resetAllData();
                StorageManager::saveTrackerData(tracker);
                HapticManager::pulseStop();
                needsRedraw = true;
            } else if (act == "set_brightness" || act == "brightness") {
                int level = doc["level"] | (doc["value"] | -1);
                if (level >= 10 && level <= 255) {
                    tracker.setBrightness((uint8_t)level);
                    u8g2.setContrast(tracker.activeBrightness);
                    StorageManager::saveTrackerData(tracker);
                    HapticManager::pulseTap();
                }
            } else if (act == "stress_buster") {
                if (tracker.state == STATE_STRESS_BUSTER) {
                    tracker.cancelStressBuster();
                    HapticManager::pulseTap();
                } else {
                    tracker.startStressBuster();
                    HapticManager::pulseStressBusterInhale();
                }
            } else if (act == "add_section" || act == "add_client") {
                String name = doc["name"] | "Focus Section";
                int newId = 0;
                {
                    TrackerLock lock;
                    newId = tracker.addClient(name);
                    StorageManager::saveTrackerData(tracker);
                    needsRedraw = true;
                }
                HapticManager::pulseTap();
                char resBuf[96];
                snprintf(resBuf, sizeof(resBuf), "{\"status\":\"ok\",\"id\":%d}", newId);
                server.send(200, "application/json", resBuf);
                return;
            } else if (act == "delete_section" || act == "delete_client") {
                int targetId = doc["id"] | -1;
                bool ok = false;
                {
                    TrackerLock lock;
                    ok = tracker.removeClient(targetId);
                    if (ok) {
                        StorageManager::saveTrackerData(tracker);
                        needsRedraw = true;
                    }
                }
                if (ok) HapticManager::pulseTap();
                server.send(ok ? 200 : 400, "application/json", ok ? "{\"status\":\"ok\"}" : "{\"status\":\"error\",\"message\":\"Cannot delete\"}");
                return;
            }
            needsRedraw = true;
            server.send(200, "application/json", "{\"status\":\"ok\"}");
        });

        // Dedicated 10-Second Stress Buster Endpoint
        server.on("/api/stress_buster", HTTP_POST, [this]() {
            sendCORS();
            String stateStr = "IDLE";
            {
                TrackerLock lock;
                if (tracker.state == STATE_STRESS_BUSTER) {
                    tracker.cancelStressBuster();
                    HapticManager::pulseTap();
                    stateStr = "IDLE";
                } else {
                    tracker.startStressBuster();
                    HapticManager::pulseStressBusterInhale();
                    stateStr = "STRESS_BUSTER";
                }
                needsRedraw = true;
            }
            char resBuf[96];
            snprintf(resBuf, sizeof(resBuf), "{\"status\":\"ok\",\"state\":\"%s\"}", stateStr.c_str());
            server.send(200, "application/json", resBuf);
        });

        server.on("/api/stress_buster", HTTP_GET, [this]() {
            sendCORS();
            bool active = false;
            unsigned long remMs = 0;
            {
                TrackerLock lock;
                active = (tracker.state == STATE_STRESS_BUSTER);
                if (active) {
                    unsigned long el = millis() - tracker.stressBusterStartMillis;
                    remMs = (el < 120000) ? (120000 - el) : 0;
                }
            }
            char resBuf[96];
            snprintf(resBuf, sizeof(resBuf), "{\"active\":%s,\"remainingMs\":%lu}", active ? "true" : "false", remMs);
            server.send(200, "application/json", resBuf);
        });

        // Dedicated OLED Display Brightness Endpoint
        server.on("/api/brightness", HTTP_GET, [this]() {
            sendCORS();
            char buf[96];
            {
                TrackerLock lock;
                snprintf(buf, sizeof(buf), "{\"brightness\":%d,\"brightnessPct\":%d}",
                    tracker.activeBrightness, (tracker.activeBrightness * 100) / 255);
            }
            server.send(200, "application/json", buf);
        });

        server.on("/api/brightness", HTTP_POST, [this]() {
            sendCORS();
            if (!server.hasArg("plain")) {
                server.send(400, "application/json", "{\"error\":\"Missing body\"}");
                return;
            }
            JsonDocument doc;
            DeserializationError err = deserializeJson(doc, server.arg("plain"));
            if (err) {
                server.send(400, "application/json", "{\"error\":\"Invalid JSON\"}");
                return;
            }
            int level = doc["level"] | (doc["value"] | -1);
            if (level < 10 || level > 255) {
                server.send(400, "application/json", "{\"error\":\"Brightness must be 10-255\"}");
                return;
            }
            {
                TrackerLock lock;
                tracker.setBrightness((uint8_t)level);
                u8g2.setContrast(tracker.activeBrightness);
                StorageManager::saveTrackerData(tracker);
                HapticManager::pulseTap();
                needsRedraw = true;
            }
            char okBuf[64];
            snprintf(okBuf, sizeof(okBuf), "{\"status\":\"ok\",\"brightness\":%d}", tracker.activeBrightness);
            server.send(200, "application/json", okBuf);
        });

        // Dedicated Wellness Endpoints
        server.on("/api/wellness", HTTP_GET, [this]() {
            sendCORS();
            char buf[128];
            {
                TrackerLock lock;
                snprintf(buf, sizeof(buf), "{\"enabled\":%s,\"interval\":%d,\"mode\":%d}",
                    tracker.wellnessEnabled ? "true" : "false",
                    tracker.wellnessIntervalMinutes,
                    tracker.wellnessMode);
            }
            server.send(200, "application/json", buf);
        });

        server.on("/api/wellness", HTTP_POST, [this]() {
            sendCORS();
            if (!server.hasArg("plain")) {
                server.send(400, "application/json", "{\"error\":\"Missing body\"}");
                return;
            }
            JsonDocument doc;
            DeserializationError err = deserializeJson(doc, server.arg("plain"));
            if (err) {
                server.send(400, "application/json", "{\"error\":\"Invalid JSON\"}");
                return;
            }
            {
                TrackerLock lock;
                if (!doc["enabled"].isNull()) {
                    tracker.wellnessEnabled = doc["enabled"].as<bool>();
                }
                if (!doc["interval"].isNull()) {
                    tracker.setWellnessInterval(doc["interval"].as<uint16_t>());
                }
                if (!doc["mode"].isNull()) {
                    tracker.wellnessMode = doc["mode"].as<uint8_t>() % 3;
                }
                StorageManager::saveTrackerData(tracker);
                HapticManager::pulseTap();
                needsRedraw = true;
            }
            char buf[128];
            snprintf(buf, sizeof(buf), "{\"status\":\"ok\",\"enabled\":%s,\"interval\":%d,\"mode\":%d}",
                tracker.wellnessEnabled ? "true" : "false",
                tracker.wellnessIntervalMinutes,
                tracker.wellnessMode);
            server.send(200, "application/json", buf);
        });

        server.on("/api/wellness/test", HTTP_POST, [this]() {
            sendCORS();
            uint8_t kind = 0;
            if (server.hasArg("plain")) {
                JsonDocument doc;
                deserializeJson(doc, server.arg("plain"));
                if (!doc["kind"].isNull()) {
                    kind = doc["kind"].as<uint8_t>() % 2;
                }
            }
            {
                TrackerLock lock;
                tracker.triggerWellnessAlert(kind);
                HapticManager::pulseWellness();
                triggerStatusLedFlash(150);
                needsRedraw = true;
            }
            server.send(200, "application/json", "{\"status\":\"alert_triggered\"}");
        });

        server.on("/api/powerbank", HTTP_GET, [this]() {
            sendCORS();
            char buf[96];
            snprintf(buf, sizeof(buf), "{\"status\":\"ok\",\"enabled\":%s,\"interval\":%d}",
                PowerManager::keepAliveEnabled ? "true" : "false",
                POWERBANK_PULSE_INTERVAL_MS);
            server.send(200, "application/json", buf);
        });

        server.on("/api/powerbank", HTTP_POST, [this]() {
            sendCORS();
            if (server.hasArg("plain")) {
                JsonDocument doc;
                DeserializationError err = deserializeJson(doc, server.arg("plain"));
                if (!err && !doc["enabled"].isNull()) {
                    PowerManager::setEnabled(doc["enabled"].as<bool>());
                    StorageManager::saveTrackerData(tracker);
                    HapticManager::pulseTap();
                }
            }
            char buf[96];
            snprintf(buf, sizeof(buf), "{\"status\":\"ok\",\"enabled\":%s}",
                PowerManager::keepAliveEnabled ? "true" : "false");
            server.send(200, "application/json", buf);
        });

        server.on("/api/reset", HTTP_POST, [this]() {
            sendCORS();
            TrackerLock lock;
            tracker.resetAllData();
            StorageManager::saveTrackerData(tracker);
            HapticManager::pulseStop();
            needsRedraw = true;
            server.send(200, "application/json", "{\"status\":\"reset_complete\"}");
        });

        auto handleAddSection = [this]() {
            sendCORS();
            TrackerLock lock;
            if (!server.hasArg("plain")) {
                server.send(400, "application/json", "{\"error\":\"Missing body\"}");
                return;
            }
            JsonDocument doc;
            deserializeJson(doc, server.arg("plain"));
            String name = doc["name"] | "";
            bool isNegative = doc["isNegative"] | false;
            if (name.length() > 0) {
                int newId = tracker.addClient(name, isNegative);
                StorageManager::saveTrackerData(tracker);
                needsRedraw = true;
                char buf[96];
                snprintf(buf, sizeof(buf), "{\"status\":\"created\",\"id\":%d}", newId);
                server.send(200, "application/json", buf);
            } else {
                server.send(400, "application/json", "{\"error\":\"Empty name\"}");
            }
        };
        server.on("/api/sections/add", HTTP_POST, handleAddSection);
        server.on("/api/section/add", HTTP_POST, handleAddSection);
        server.on("/api/client/add", HTTP_POST, handleAddSection);

        server.on("/api/sections/update", HTTP_POST, [this]() {
            sendCORS();
            TrackerLock lock;
            if (!server.hasArg("plain")) {
                server.send(400, "application/json", "{\"error\":\"Missing body\"}");
                return;
            }
            JsonDocument doc;
            deserializeJson(doc, server.arg("plain"));
            int id = doc["id"] | -1;
            String name = doc["name"] | "";
            int reps = doc["reps"] | -1;
            long totalSecs = doc["totalSecs"] | -1;
            int isNegative = -1;
            if (!doc["isNegative"].isNull()) {
                isNegative = doc["isNegative"].as<bool>() ? 1 : 0;
            }

            if (id >= 0 && tracker.updateClient(id, name, reps, totalSecs, isNegative)) {
                StorageManager::saveTrackerData(tracker);
                needsRedraw = true;
                server.send(200, "application/json", "{\"status\":\"updated\"}");
            } else {
                server.send(400, "application/json", "{\"error\":\"Update failed\"}");
            }
        });

        auto handleDeleteSection = [this]() {
            sendCORS();
            TrackerLock lock;
            if (!server.hasArg("plain")) {
                server.send(400, "application/json", "{\"error\":\"Missing body\"}");
                return;
            }
            JsonDocument doc;
            deserializeJson(doc, server.arg("plain"));
            int id = doc["id"] | -1;
            if (id >= 0 && tracker.removeClient(id)) {
                StorageManager::saveTrackerData(tracker);
                needsRedraw = true;
                server.send(200, "application/json", "{\"status\":\"deleted\"}");
            } else {
                server.send(400, "application/json", "{\"error\":\"Cannot delete or not found\"}");
            }
        };
        server.on("/api/sections/delete", HTTP_POST, handleDeleteSection);
        server.on("/api/section/delete", HTTP_POST, handleDeleteSection);
        server.on("/api/client/delete", HTTP_POST, handleDeleteSection);

        server.on("/api/history/add", HTTP_POST, [this]() {
            sendCORS();
            TrackerLock lock;
            if (!server.hasArg("plain")) {
                server.send(400, "application/json", "{\"error\":\"Missing body\"}");
                return;
            }
            JsonDocument doc;
            deserializeJson(doc, server.arg("plain"));
            int id = doc["id"] | -1;
            String timestamp = doc["timestamp"] | getSystemTimestamp();
            String date = doc["date"] | getSystemDate();
            unsigned long secs = doc["secs"] | 0;
            int reps = doc["reps"] | 0;

            if (id >= 0 && tracker.addHistoryRecord(id, timestamp, date, secs, reps)) {
                StorageManager::saveTrackerData(tracker);
                server.send(200, "application/json", "{\"status\":\"history_added\"}");
            } else {
                server.send(400, "application/json", "{\"error\":\"History add failed\"}");
            }
        });

        server.on("/api/history/delete", HTTP_POST, [this]() {
            sendCORS();
            TrackerLock lock;
            if (!server.hasArg("plain")) {
                server.send(400, "application/json", "{\"error\":\"Missing body\"}");
                return;
            }
            JsonDocument doc;
            deserializeJson(doc, server.arg("plain"));
            int id = doc["id"] | -1;
            int idx = doc["index"] | -1;

            if (id >= 0 && idx >= 0 && tracker.deleteHistoryRecord(id, idx)) {
                StorageManager::saveTrackerData(tracker);
                server.send(200, "application/json", "{\"status\":\"history_deleted\"}");
            } else {
                server.send(400, "application/json", "{\"error\":\"History delete failed\"}");
            }
        });

        // --- TASK LIST REST API (PHONE & PC WITH STARS & PRIORITY) ---
        server.on("/api/tasks", HTTP_GET, [this]() {
            sendCORS();
            String res;
            {
                TrackerLock lock;
                JsonDocument doc;
                JsonArray taskArr = doc.to<JsonArray>();
                for (const auto& t : tracker.tasks) {
                    JsonObject tObj = taskArr.add<JsonObject>();
                    tObj["id"] = t.id;
                    tObj["text"] = t.text;
                    tObj["stars"] = t.stars;
                    tObj["done"] = t.done;
                    tObj["created"] = t.createdAt;
                }
                serializeJson(doc, res);
            }
            sendChunked(200, "application/json", res);
        });

        server.on("/api/tasks/add", HTTP_POST, [this]() {
            sendCORS();
            TrackerLock lock;
            if (!server.hasArg("plain")) {
                server.send(400, "application/json", "{\"error\":\"Missing body\"}");
                return;
            }
            JsonDocument doc;
            deserializeJson(doc, server.arg("plain"));
            String text = doc["text"] | "";
            int stars = doc["stars"] | 1;
            if (stars < 1) stars = 1;
            if (stars > 3) stars = 3;
            if (text.length() > 0) {
                int id = tracker.addTask(text, stars);
                StorageManager::saveTrackerData(tracker);
                HapticManager::pulseTap();
                needsRedraw = true;
                char resp[64];
                snprintf(resp, sizeof(resp), "{\"status\":\"created\",\"id\":%d}", id);
                server.send(200, "application/json", resp);
            } else {
                server.send(400, "application/json", "{\"error\":\"Task text cannot be empty\"}");
            }
        });

        server.on("/api/tasks/toggle", HTTP_POST, [this]() {
            sendCORS();
            TrackerLock lock;
            if (!server.hasArg("plain")) {
                server.send(400, "application/json", "{\"error\":\"Missing body\"}");
                return;
            }
            JsonDocument doc;
            deserializeJson(doc, server.arg("plain"));
            int id = doc["id"] | -1;
            if (id >= 0 && tracker.toggleTask(id)) {
                StorageManager::saveTrackerData(tracker);
                HapticManager::pulseTally();
                needsRedraw = true;
                server.send(200, "application/json", "{\"status\":\"toggled\"}");
            } else {
                server.send(400, "application/json", "{\"error\":\"Task not found\"}");
            }
        });

        server.on("/api/tasks/delete", HTTP_POST, [this]() {
            sendCORS();
            TrackerLock lock;
            if (!server.hasArg("plain")) {
                server.send(400, "application/json", "{\"error\":\"Missing body\"}");
                return;
            }
            JsonDocument doc;
            deserializeJson(doc, server.arg("plain"));
            int id = doc["id"] | -1;
            if (id >= 0 && tracker.deleteTask(id)) {
                StorageManager::saveTrackerData(tracker);
                needsRedraw = true;
                server.send(200, "application/json", "{\"status\":\"deleted\"}");
            } else {
                server.send(400, "application/json", "{\"error\":\"Cannot delete or not found\"}");
            }
        });

        server.on("/api/tasks/update", HTTP_POST, [this]() {
            sendCORS();
            TrackerLock lock;
            if (!server.hasArg("plain")) {
                server.send(400, "application/json", "{\"error\":\"Missing body\"}");
                return;
            }
            JsonDocument doc;
            deserializeJson(doc, server.arg("plain"));
            int id = doc["id"] | -1;
            String text = doc["text"] | "";
            int stars = doc["stars"] | -1;
            int done = !doc["done"].isNull() ? (doc["done"].as<bool>() ? 1 : 0) : -1;
            if (id >= 0 && tracker.updateTask(id, text, stars, done)) {
                StorageManager::saveTrackerData(tracker);
                needsRedraw = true;
                server.send(200, "application/json", "{\"status\":\"updated\"}");
            } else {
                server.send(400, "application/json", "{\"error\":\"Update failed\"}");
            }
        });

        // --- DAILY REMINDERS & HABIT NOTES REST API ---
        server.on("/api/reminders", HTTP_GET, [this]() {
            sendCORS();
            String res;
            {
                TrackerLock lock;
                JsonDocument doc;
                JsonArray remArr = doc.to<JsonArray>();
                for (const auto& r : tracker.reminders) {
                    JsonObject rObj = remArr.add<JsonObject>();
                    rObj["id"] = r.id;
                    rObj["text"] = r.text;
                    rObj["created"] = r.createdAt;
                }
                serializeJson(doc, res);
            }
            sendChunked(200, "application/json", res);
        });

        server.on("/api/reminders/add", HTTP_POST, [this]() {
            sendCORS();
            TrackerLock lock;
            if (!server.hasArg("plain")) {
                server.send(400, "application/json", "{\"error\":\"Missing body\"}");
                return;
            }
            JsonDocument doc;
            deserializeJson(doc, server.arg("plain"));
            String text = doc["text"] | "";
            if (text.length() > 0) {
                int id = tracker.addReminder(text);
                StorageManager::saveTrackerData(tracker);
                HapticManager::pulseTap();
                needsRedraw = true;
                char resp[64];
                snprintf(resp, sizeof(resp), "{\"status\":\"created\",\"id\":%d}", id);
                server.send(200, "application/json", resp);
            } else {
                server.send(400, "application/json", "{\"error\":\"Reminder text cannot be empty\"}");
            }
        });

        server.on("/api/reminders/delete", HTTP_POST, [this]() {
            sendCORS();
            TrackerLock lock;
            if (!server.hasArg("plain")) {
                server.send(400, "application/json", "{\"error\":\"Missing body\"}");
                return;
            }
            JsonDocument doc;
            deserializeJson(doc, server.arg("plain"));
            int id = doc["id"] | -1;
            if (id >= 0 && tracker.deleteReminder(id)) {
                StorageManager::saveTrackerData(tracker);
                needsRedraw = true;
                server.send(200, "application/json", "{\"status\":\"deleted\"}");
            } else {
                server.send(400, "application/json", "{\"error\":\"Cannot delete or not found\"}");
            }
        });

        server.on("/api/reminders/update", HTTP_POST, [this]() {
            sendCORS();
            TrackerLock lock;
            if (!server.hasArg("plain")) {
                server.send(400, "application/json", "{\"error\":\"Missing body\"}");
                return;
            }
            JsonDocument doc;
            deserializeJson(doc, server.arg("plain"));
            int id = doc["id"] | -1;
            String text = doc["text"] | "";
            if (id >= 0 && tracker.updateReminder(id, text)) {
                StorageManager::saveTrackerData(tracker);
                needsRedraw = true;
                server.send(200, "application/json", "{\"status\":\"updated\"}");
            } else {
                server.send(400, "application/json", "{\"error\":\"Update failed\"}");
            }
        });

        server.on("/api/export/sessions.csv", HTTP_GET, [this]() {
            sendCORS();
            TrackerLock lock;
            String csv = "Full_Timestamp,Date,Focus_Section,Duration_Formatted,Duration_Seconds,Reps_Completed,Mastery_Level\r\n";
            for (const auto& c : tracker.clients) {
                if (c.totalSecondsToday > 0 || c.tallyCount > 0) {
                    float hrs = (float)c.totalSecondsToday / 3600.0f;
                    String lvl = "LEVEL 0";
                    if (hrs >= 20.0f) lvl = "LEVEL 5 (MAX)";
                    else if (hrs >= 15.0f) lvl = "LEVEL 4";
                    else if (hrs >= 10.0f) lvl = "LEVEL 3";
                    else if (hrs >= 5.0f) lvl = "LEVEL 2";
                    else if (hrs >= 2.0f) lvl = "LEVEL 1";

                    unsigned long h = c.totalSecondsToday / 3600;
                    unsigned long m = (c.totalSecondsToday % 3600) / 60;
                    unsigned long s = c.totalSecondsToday % 60;
                    char durBuf[32];
                    snprintf(durBuf, sizeof(durBuf), "%luh %lum %lus", h, m, s);

                    csv += "\"" + getSystemTimestamp() + "\",\"" + getSystemDate() + " (TODAY)\",\"" + c.name + "\",\"" + String(durBuf) + "\"," + String(c.totalSecondsToday) + "," + String(c.tallyCount) + ",\"" + lvl + "\"\r\n";
                }

                for (const auto& hist : c.history) {
                    float hrs = (float)hist.seconds / 3600.0f;
                    String lvl = "LEVEL 0";
                    if (hrs >= 20.0f) lvl = "LEVEL 5 (MAX)";
                    else if (hrs >= 15.0f) lvl = "LEVEL 4";
                    else if (hrs >= 10.0f) lvl = "LEVEL 3";
                    else if (hrs >= 5.0f) lvl = "LEVEL 2";
                    else if (hrs >= 2.0f) lvl = "LEVEL 1";

                    unsigned long h = hist.seconds / 3600;
                    unsigned long m = (hist.seconds % 3600) / 60;
                    unsigned long s = hist.seconds % 60;
                    char durBuf[32];
                    snprintf(durBuf, sizeof(durBuf), "%luh %lum %lus", h, m, s);

                    csv += "\"" + hist.timestamp + "\",\"" + hist.dateLabel + "\",\"" + c.name + "\",\"" + String(durBuf) + "\"," + String(hist.seconds) + "," + String(hist.reps) + ",\"" + lvl + "\"\r\n";
                }
            }
            server.sendHeader("Content-Disposition", "attachment; filename=cranium_sessions_log.csv");
            sendChunked(200, "text/csv", csv);
        });

        server.on("/api/export/summary.csv", HTTP_GET, [this]() {
            sendCORS();
            TrackerLock lock;
            String csv = "Section_ID,Section_Name,Today_Seconds,Today_Hours,AllTime_Total_Seconds,AllTime_Hours,Reps_Logged,Mastery_Level,Current_Streak_Days,Longest_Streak_Days,Last_Updated\r\n";
            for (const auto& c : tracker.clients) {
                unsigned long totalAllTime = c.totalSecondsToday;
                for (const auto& h : c.history) totalAllTime += h.seconds;
                
                float allTimeHrs = (float)totalAllTime / 3600.0f;
                float todayHrs = (float)c.totalSecondsToday / 3600.0f;
                String lvl = "LEVEL 0";
                if (allTimeHrs >= 20.0f) lvl = "LEVEL 5 (MAX)";
                else if (allTimeHrs >= 15.0f) lvl = "LEVEL 4";
                else if (allTimeHrs >= 10.0f) lvl = "LEVEL 3";
                else if (allTimeHrs >= 5.0f) lvl = "LEVEL 2";
                else if (allTimeHrs >= 2.0f) lvl = "LEVEL 1";

                csv += String(c.id) + ",\"" + c.name + "\"," + String(c.totalSecondsToday) + "," + String(todayHrs, 2) + "," + String(totalAllTime) + "," + String(allTimeHrs, 2) + "," + String(c.tallyCount) + ",\"" + lvl + "\"," + String(tracker.currentStreakDays) + "," + String(tracker.longestStreakDays) + ",\"" + getSystemTimestamp() + "\"\r\n";
            }
            server.sendHeader("Content-Disposition", "attachment; filename=cranium_section_summary.csv");
            sendChunked(200, "text/csv", csv);
        });

        server.on("/api/backup.json", HTTP_GET, [this]() {
            sendCORS();
            TrackerLock lock;
            if (LittleFS.exists("/tracker_data.json")) {
                File file = LittleFS.open("/tracker_data.json", "r");
                server.sendHeader("Content-Disposition", "attachment; filename=cranium_backup.json");
                server.streamFile(file, "application/json");
                file.close();
            } else {
                server.send(404, "application/json", "{\"error\":\"No backup file found\"}");
            }
        });

        server.on("/api/restore.json", HTTP_POST, [this]() {
            sendCORS();
            if (!server.hasArg("plain")) {
                server.send(400, "application/json", "{\"error\":\"Missing body\"}");
                return;
            }
            String rawJson = server.arg("plain");
            if (rawJson.length() < 10) {
                server.send(400, "application/json", "{\"error\":\"Payload too small\"}");
                return;
            }
            JsonDocument testDoc;
            DeserializationError err = deserializeJson(testDoc, rawJson);
            if (err) {
                server.send(400, "application/json", "{\"error\":\"Invalid JSON format\"}");
                return;
            }
            if (!testDoc.is<JsonObject>() || (!testDoc["clients"].is<JsonArray>() && !testDoc["sections"].is<JsonArray>())) {
                server.send(400, "application/json", "{\"error\":\"Invalid database schema: missing clients/sections\"}");
                return;
            }

            File file = LittleFS.open("/tracker_data.tmp", "w");
            if (!file) {
                server.send(500, "application/json", "{\"error\":\"Failed to open file for write\"}");
                return;
            }
            file.print(rawJson);
            file.close();

            {
                TrackerLock lock;
                if (LittleFS.exists("/tracker_data.json")) {
                    LittleFS.remove("/tracker_data.json");
                }
                LittleFS.rename("/tracker_data.tmp", "/tracker_data.json");

                StorageManager::loadTrackerData(tracker);
                needsRedraw = true;
            }
            server.send(200, "application/json", "{\"status\":\"restored\"}");
        });
    }
};
#else
class DeskTrackerWebServer {
public:
    String currentIP = "";
    bool wifiConnected = false;
    bool isAwayMode = false;
    void init() {}
    void handle() {}
};
#endif