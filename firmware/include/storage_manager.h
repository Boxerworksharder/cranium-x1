#pragma once
#include <Arduino.h>
#include <LittleFS.h>
#include <ArduinoJson.h>
#include "tracker_state.h"
#include "power_manager.h"

class StorageManager {
public:
    static bool init() {
        if (!LittleFS.begin(true)) {
            Serial.println("[STORAGE] LittleFS Mount Failed!");
            return false;
        }
        Serial.println("[STORAGE] LittleFS Mounted Successfully.");
        return true;
    }

    static bool loadTrackerData(TrackerManager& mgr) {
        bool loaded = false;
        if (LittleFS.exists("/tracker_data.json")) {
            loaded = parseFile("/tracker_data.json", mgr);
        }

        if (!loaded && LittleFS.exists("/tracker_data.tmp")) {
            Serial.println("[STORAGE] Emergency recovery from /tracker_data.tmp...");
            loaded = parseFile("/tracker_data.tmp", mgr);
            if (loaded) {
                saveTrackerData(mgr);
            }
        }

        if (!loaded || mgr.clients.empty()) {
            Serial.println("[STORAGE] Initializing baseline default database.");
            mgr.initDefaults();
            saveTrackerData(mgr);
        } else {
            // Ensure at least one negative (Time Sink) section exists so user can track time sinks out-of-the-box
            bool hasNegative = false;
            for (const auto& c : mgr.clients) {
                if (c.isNegative) {
                    hasNegative = true;
                    break;
                }
            }
            if (!hasNegative) {
                int maxId = 0;
                for (const auto& c : mgr.clients) {
                    if (c.id > maxId) maxId = c.id;
                }
                mgr.clients.push_back({ maxId + 1, "YouTube & Reels", 0, 0, {}, true });
                saveTrackerData(mgr);
                Serial.println("[STORAGE] Seeded baseline Time Sink section 'YouTube & Reels'.");
            }
        }

        Serial.printf("[STORAGE] Active dataset: %d focus sections loaded.\n", (int)mgr.clients.size());
        return true;
    }

    static bool saveTrackerData(const TrackerManager& mgr) {
        if (mgr.clients.empty()) {
            return false;
        }

        JsonDocument doc;
        doc["globalGoal"] = mgr.globalDeepWorkGoalSeconds;
        doc["brightness"] = mgr.activeBrightness;
        doc["savedAt"] = getSystemTimestamp();
        doc["currentStreak"] = mgr.currentStreakDays;
        doc["longestStreak"] = mgr.longestStreakDays;
        doc["lastActiveDate"] = mgr.lastActiveDate;
        doc["wellness_enabled"] = mgr.wellnessEnabled;
        doc["wellness_interval_min"] = mgr.wellnessIntervalMinutes;
        doc["wellness_mode"] = mgr.wellnessMode;
        doc["powerbank_keepalive"] = PowerManager::keepAliveEnabled;

        JsonArray clientArr = doc["clients"].to<JsonArray>();
        for (const auto& client : mgr.clients) {
            JsonObject c = clientArr.add<JsonObject>();
            c["id"] = client.id;
            c["name"] = client.name;
            c["totalSecsToday"] = client.totalSecondsToday;
            c["reps"] = client.tallyCount;
            c["isNegative"] = client.isNegative;

            JsonArray histArr = c["history"].to<JsonArray>();
            size_t count = 0;
            for (const auto& h : client.history) {
                if (h.seconds < 60) continue; // Exclude sessions < 1 minute from persistence
                if (++count > 50) break; // Cap to 50 items per client
                JsonObject hObj = histArr.add<JsonObject>();
                hObj["timestamp"] = h.timestamp;
                hObj["date"] = h.dateLabel;
                hObj["secs"] = h.seconds;
                hObj["reps"] = h.reps;
            }
        }

        JsonArray taskArr = doc["tasks"].to<JsonArray>();
        for (const auto& t : mgr.tasks) {
            JsonObject tObj = taskArr.add<JsonObject>();
            tObj["id"] = t.id;
            tObj["text"] = t.text;
            tObj["stars"] = t.stars;
            tObj["done"] = t.done;
            tObj["created"] = t.createdAt;
        }

        JsonArray reminderArr = doc["reminders"].to<JsonArray>();
        for (const auto& r : mgr.reminders) {
            JsonObject rObj = reminderArr.add<JsonObject>();
            rObj["id"] = r.id;
            rObj["text"] = r.text;
            rObj["created"] = r.createdAt;
        }

        File tmpFile = LittleFS.open("/tracker_data.tmp", "w");
        if (!tmpFile) {
            Serial.println("[STORAGE] Error: Cannot open /tracker_data.tmp for writing.");
            return false;
        }
        serializeJson(doc, tmpFile);
        tmpFile.close();

        // Integrity verification check
        File verifyFile = LittleFS.open("/tracker_data.tmp", "r");
        if (!verifyFile || verifyFile.size() < 10) {
            if (verifyFile) verifyFile.close();
            Serial.println("[STORAGE] Error: Temp write validation failed (too small).");
            return false;
        }

        // Verify that the file ends with '}'
        verifyFile.seek(verifyFile.size() - 1);
        char lastChar = verifyFile.read();
        verifyFile.close();

        if (lastChar != '}' && lastChar != '\n' && lastChar != ' ') {
            Serial.println("[STORAGE] Error: Temp file incomplete (missing closing brace).");
            return false;
        }

        if (LittleFS.exists("/tracker_data.json")) {
            LittleFS.remove("/tracker_data.json");
        }
        LittleFS.rename("/tracker_data.tmp", "/tracker_data.json");
        return true;
    }

private:
    static bool parseFile(const char* path, TrackerManager& mgr) {
        File file = LittleFS.open(path, "r");
        if (!file) return false;

        JsonDocument doc;
        DeserializationError error = deserializeJson(doc, file);
        file.close();

        if (error) {
            Serial.printf("[STORAGE] Parse error in %s: %s\n", path, error.c_str());
            return false;
        }

        mgr.clients.clear();
        mgr.globalDeepWorkGoalSeconds = doc["globalGoal"] | 36000;
        if (mgr.globalDeepWorkGoalSeconds == 28800) {
            mgr.globalDeepWorkGoalSeconds = 36000; // Auto-migrate legacy 8h to 10h standard
        }
        int bVal = doc["brightness"] | 255;
        if (bVal < 10) bVal = 10;
        if (bVal > 255) bVal = 255;
        mgr.activeBrightness = (uint8_t)bVal;

        mgr.currentStreakDays = doc["currentStreak"] | 0;
        mgr.longestStreakDays = doc["longestStreak"] | 0;
        mgr.lastActiveDate = doc["lastActiveDate"] | getSystemDate();
        mgr.wellnessEnabled = !doc["wellness_enabled"].isNull() ? doc["wellness_enabled"].as<bool>() : true;
        mgr.wellnessIntervalMinutes = doc["wellness_interval_min"] | 45;
        mgr.wellnessMode = doc["wellness_mode"] | 0;
        if (!doc["powerbank_keepalive"].isNull()) {
            PowerManager::keepAliveEnabled = doc["powerbank_keepalive"].as<bool>();
        }
        
        JsonArray clientArr = doc["clients"].as<JsonArray>();
        for (JsonObject c : clientArr) {
            ClientInfo client;
            client.id = c["id"] | (int)(mgr.clients.size() + 1);
            client.name = c["name"] | "Focus Section";
            client.totalSecondsToday = c["totalSecsToday"] | (c["totalSecondsToday"] | 0);
            client.tallyCount = c["reps"] | (c["tallyCount"] | 0);
            client.isNegative = c["isNegative"] | false;

            if (c["history"].is<JsonArray>()) {
                JsonArray histArr = c["history"].as<JsonArray>();
                size_t count = 0;
                for (JsonObject h : histArr) {
                    unsigned long s = h["secs"] | (h["seconds"] | 0);
                    if (s < 60) continue; // Prune legacy sub-minute sessions (< 1 min)
                    if (++count > 50) break;
                    DateRecord rec;
                    rec.timestamp = h["timestamp"] | (h["date"] | "2026-09-02 07:00:00");
                    rec.dateLabel = h["date"] | "Past";
                    rec.seconds = s;
                    rec.reps = h["reps"] | (h["tallyCount"] | 0);
                    client.history.push_back(rec);
                }
            }
            mgr.clients.push_back(client);
        }

        mgr.tasks.clear();
        if (doc["tasks"].is<JsonArray>()) {
            JsonArray taskArr = doc["tasks"].as<JsonArray>();
            for (JsonObject t : taskArr) {
                TaskItem item;
                item.id = t["id"] | (int)(mgr.tasks.size() + 1);
                item.text = t["text"] | "Focus Task";
                item.stars = t["stars"] | 1;
                item.done = t["done"] | false;
                item.createdAt = t["created"] | (t["createdAt"] | getSystemTimestamp());
                mgr.tasks.push_back(item);
            }
            mgr.sortTasks();
        }

        if (mgr.tasks.empty()) {
            mgr.tasks.push_back({ 1, "Review Firmware PR #4", 3, false, getSystemTimestamp() });
            mgr.tasks.push_back({ 2, "Test GPIO 20 Task Glance", 3, false, getSystemTimestamp() });
            mgr.tasks.push_back({ 3, "Finish LeetCode Graph", 2, false, getSystemTimestamp() });
            mgr.tasks.push_back({ 4, "Calibrate Desk Haptics", 1, true, getSystemTimestamp() });
            mgr.sortTasks();
        }

        mgr.reminders.clear();
        if (doc["reminders"].is<JsonArray>()) {
            JsonArray reminderArr = doc["reminders"].as<JsonArray>();
            for (JsonObject r : reminderArr) {
                ReminderItem item;
                item.id = r["id"] | (int)(mgr.reminders.size() + 1);
                item.text = r["text"] | "Daily Reminder";
                item.createdAt = r["created"] | (r["createdAt"] | getSystemTimestamp());
                mgr.reminders.push_back(item);
            }
        }

        if (mgr.reminders.empty()) {
            mgr.reminders.push_back({ 1, "Drink 3L water daily", getSystemTimestamp() });
            mgr.reminders.push_back({ 2, "Read 30 mins before sleep", getSystemTimestamp() });
            mgr.reminders.push_back({ 3, "Plan tomorrow's priorities", getSystemTimestamp() });
            mgr.reminders.push_back({ 4, "Posture & hourly stretch", getSystemTimestamp() });
        }

        if (mgr.clients.empty()) {
            mgr.initDefaults();
        }

        return true;
    }
};
