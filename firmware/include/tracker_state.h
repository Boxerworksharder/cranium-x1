#pragma once
#include <Arduino.h>
#include <vector>
#include <time.h>

// FreeRTOS Recursive Mutex for thread-safe concurrent & re-entrant tracker access
extern SemaphoreHandle_t trackerMutex;

class TrackerLock {
public:
    TrackerLock() {
        if (trackerMutex) {
            xSemaphoreTakeRecursive(trackerMutex, portMAX_DELAY);
        }
    }
    ~TrackerLock() {
        if (trackerMutex) {
            xSemaphoreGiveRecursive(trackerMutex);
        }
    }
};

enum TrackerState {
    STATE_SELECT_CLIENT,  // Browsing / picking client from the menu
    STATE_TRACKING,       // Actively tracking time (timer incrementing)
    STATE_PAUSED,         // Tracking paused (timer frozen)
    STATE_VIEW_SUMMARY,   // Detailed scrollable breakdown report of all projects/activities
    STATE_VIEW_LOGS,      // Browse timestamped session logs on OLED display
    STATE_SET_BRIGHTNESS, // OLED display brightness adjustment screen
    STATE_VIEW_TASKS,     // Priority Task List with stars (accessed via GPIO 20 click)
    STATE_VIEW_REMINDERS, // Daily Reminders & Notes without ticks (accessed via GPIO 20 hold)
    STATE_STRESS_BUSTER,  // 10-Second Stress Buster Breathing & Relaxation Animation
    STATE_CONFIG_WELLNESS // Hydration & Stand/Stretch Wellness configuration screen
};

inline String getSystemTimestamp() {
    struct tm timeinfo;
    if (getLocalTime(&timeinfo, 50)) {
        char buf[64];
        strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", &timeinfo);
        return String(buf);
    }
    return "2026-09-02 07:30:00";
}

inline String getSystemDate() {
    struct tm timeinfo;
    if (getLocalTime(&timeinfo, 50)) {
        char buf[32];
        strftime(buf, sizeof(buf), "%d %b %Y", &timeinfo);
        return String(buf);
    }
    return "02 Sep 2026";
}

struct ReminderItem {
    int id;
    String text;
    String createdAt;
};

struct TaskItem {
    int id;
    String text;
    int stars; // Priority stars: 1 to 3
    bool done;
    String createdAt;
};

struct DateRecord {
    String timestamp;
    String dateLabel;
    unsigned long seconds;
    int reps;
};

struct ClientInfo {
    int id;
    String name;
    unsigned long totalSecondsToday;
    int tallyCount;
    std::vector<DateRecord> history;
    bool isNegative;

    ClientInfo() : id(0), name(""), totalSecondsToday(0), tallyCount(0), isNegative(false) {}
    ClientInfo(int _id, String _name, unsigned long _totalSecs = 0, int _reps = 0, std::vector<DateRecord> _hist = {}, bool _isNeg = false)
        : id(_id), name(_name), totalSecondsToday(_totalSecs), tallyCount(_reps), history(_hist), isNegative(_isNeg) {}
};

class TrackerManager {
public:
    TrackerState state = STATE_SELECT_CLIENT;
    
    std::vector<ClientInfo> clients;
    std::vector<TaskItem> tasks;
    std::vector<ReminderItem> reminders;
    int activeClientIndex = 0;
    int menuIndex = 0;
    int summaryIndex = 0;
    int logScrollIndex = 0;
    int taskScrollIndex = 0;
    int reminderScrollIndex = 0;
    
    unsigned long sessionStartMillis = 0;
    unsigned long currentSessionSeconds = 0;
    unsigned long lastTickMillis = 0;
    unsigned long globalDeepWorkGoalSeconds = 36000;

    // Daily Streak Engine
    int currentStreakDays = 0;
    int longestStreakDays = 0;
    String lastActiveDate = "02 Sep 2026";
    unsigned long dailyStreakThresholdSeconds = 3600;

    // Robustness State
    unsigned long lastActivityMillis = 0;
    unsigned long lastAutoSaveMillis = 0;
    int lastMidnightCheckDay = -1;
    bool isDimmed = false;
    uint8_t activeBrightness = 255; // 10 to 255 (OLED SSD1306 contrast)

    // Debounced Flash Persistence State
    volatile bool isDirty = false;
    unsigned long lastDirtyMillis = 0;

    void markDirty() {
        isDirty = true;
        lastDirtyMillis = millis();
    }

    // 20-Second Guided Breathing Zen Reset State
    unsigned long stressBusterStartMillis = 0;
    unsigned long lastBreathHapticMillis = 0;
    TrackerState returnStateAfterStressBuster = STATE_SELECT_CLIENT;

    void startStressBuster() {
        recordUserActivity();
        if (state != STATE_STRESS_BUSTER) {
            returnStateAfterStressBuster = state;
        }
        stressBusterStartMillis = millis();
        lastBreathHapticMillis = 0;
        state = STATE_STRESS_BUSTER;
    }

    void cancelStressBuster() {
        recordUserActivity();
        state = (returnStateAfterStressBuster != STATE_STRESS_BUSTER) ? returnStateAfterStressBuster : STATE_SELECT_CLIENT;
        stressBusterStartMillis = 0;
        lastBreathHapticMillis = 0;
    }

    void setBrightness(uint8_t b) {
        if (b < 10) b = 10;
        if (b > 255) b = 255;
        activeBrightness = b;
    }

    // Hydration & Stand / Stretch Wellness Reminder Engine
    bool wellnessEnabled = true;
    uint16_t wellnessIntervalMinutes = 45; // 15 to 180 minutes
    uint8_t wellnessMode = 0;              // 0 = Alternating (Water -> Stretch), 1 = Water only, 2 = Stretch only
    unsigned long lastWellnessAlertMillis = 0;
    bool isShowingWellnessAlert = false;
    unsigned long wellnessAlertStartMillis = 0;
    uint8_t currentWellnessAlertKind = 0;  // 0 = Hydrate, 1 = Stand & Stretch
    uint8_t wellnessCycleCount = 0;        // for alternating
    uint8_t wellnessConfigField = 0;       // 0 = Toggle, 1 = Interval, 2 = Mode

    void triggerWellnessAlert(uint8_t kind) {
        currentWellnessAlertKind = kind;
        isShowingWellnessAlert = true;
        wellnessAlertStartMillis = millis();
        lastWellnessAlertMillis = millis();
    }

    void dismissWellnessAlert() {
        isShowingWellnessAlert = false;
        wellnessAlertStartMillis = 0;
    }

    void toggleWellness() {
        recordUserActivity();
        wellnessEnabled = !wellnessEnabled;
        lastWellnessAlertMillis = millis();
    }

    void setWellnessInterval(uint16_t mins) {
        recordUserActivity();
        if (mins < 15) mins = 15;
        if (mins > 180) mins = 180;
        wellnessIntervalMinutes = mins;
        lastWellnessAlertMillis = millis();
    }

    void sortTasks() {
        // Pending tasks first, then by priority stars descending (3 > 2 > 1), then ID
        std::stable_sort(tasks.begin(), tasks.end(), [](const TaskItem& a, const TaskItem& b) {
            if (a.done != b.done) {
                return !a.done;
            }
            if (a.stars != b.stars) {
                return a.stars > b.stars;
            }
            return a.id < b.id;
        });
    }

    int addTask(String text, int stars = 1) {
        recordUserActivity();
        int maxId = 0;
        for (const auto& t : tasks) {
            if (t.id > maxId) maxId = t.id;
        }
        TaskItem item;
        item.id = maxId + 1;
        if (text.length() > 128) text = text.substring(0, 128);
        item.text = text.length() > 0 ? text : "Focus Task";
        if (stars < 1) stars = 1;
        if (stars > 3) stars = 3;
        item.stars = stars;
        item.done = false;
        item.createdAt = getSystemTimestamp();
        tasks.push_back(item);
        sortTasks();
        return item.id;
    }

    bool toggleTask(int id) {
        recordUserActivity();
        for (auto& t : tasks) {
            if (t.id == id) {
                t.done = !t.done;
                sortTasks();
                return true;
            }
        }
        return false;
    }

    bool deleteTask(int id) {
        recordUserActivity();
        for (auto it = tasks.begin(); it != tasks.end(); ++it) {
            if (it->id == id) {
                tasks.erase(it);
                if (taskScrollIndex >= (int)tasks.size() && !tasks.empty()) {
                    taskScrollIndex = (int)tasks.size() - 1;
                }
                return true;
            }
        }
        return false;
    }

    bool updateTask(int id, String text, int stars = -1, int done = -1) {
        recordUserActivity();
        for (auto& t : tasks) {
            if (t.id == id) {
                if (text.length() > 128) text = text.substring(0, 128);
                if (text.length() > 0) t.text = text;
                if (stars >= 1 && stars <= 3) t.stars = stars;
                if (done == 0) t.done = false;
                else if (done == 1) t.done = true;
                sortTasks();
                return true;
            }
        }
        return false;
    }

    int addReminder(String text) {
        recordUserActivity();
        int maxId = 0;
        for (const auto& r : reminders) {
            if (r.id > maxId) maxId = r.id;
        }
        ReminderItem item;
        item.id = maxId + 1;
        if (text.length() > 128) text = text.substring(0, 128);
        item.text = text.length() > 0 ? text : "Daily Reminder";
        item.createdAt = getSystemTimestamp();
        reminders.push_back(item);
        return item.id;
    }

    bool deleteReminder(int id) {
        recordUserActivity();
        for (auto it = reminders.begin(); it != reminders.end(); ++it) {
            if (it->id == id) {
                reminders.erase(it);
                if (reminderScrollIndex >= (int)reminders.size() && !reminders.empty()) {
                    reminderScrollIndex = (int)reminders.size() - 1;
                }
                return true;
            }
        }
        return false;
    }

    bool updateReminder(int id, String text) {
        recordUserActivity();
        for (auto& r : reminders) {
            if (r.id == id) {
                if (text.length() > 128) text = text.substring(0, 128);
                if (text.length() > 0) r.text = text;
                return true;
            }
        }
        return false;
    }

    unsigned long getTotalAccumulatedSecondsForActiveClient() {
        ClientInfo& c = getActiveClient();
        unsigned long total = c.totalSecondsToday;
        for (const auto& r : c.history) {
            total += r.seconds;
        }
        if (state == STATE_TRACKING || state == STATE_PAUSED) {
            total += currentSessionSeconds;
        }
        return total;
    }

    void recordUserActivity() {
        lastActivityMillis = millis();
    }

    bool isRunawaySession() const {
        return (state == STATE_TRACKING && currentSessionSeconds >= 12600);
    }

    void initDefaults() {
        clients.clear();
        clients.push_back({ 1, "Deep Coding", 0, 0, {}, false });
        clients.push_back({ 2, "System Design", 0, 0, {}, false });
        clients.push_back({ 3, "DSA LeetCode", 0, 0, {}, false });
        clients.push_back({ 4, "Hardware Labs", 0, 0, {}, false });
        clients.push_back({ 5, "YouTube & Reels", 0, 0, {}, true });

        // --- DEMO DATA: Pre-populated sessions for GPIO 20 glance ---
        // Today's progress (simulated partial day)
        clients[0].totalSecondsToday = 5400;   // Deep Coding: 1h 30m today
        clients[0].tallyCount = 3;
        clients[1].totalSecondsToday = 3600;   // System Design: 1h 00m today
        clients[1].tallyCount = 2;
        clients[2].totalSecondsToday = 2700;   // DSA LeetCode: 45m today
        clients[2].tallyCount = 8;
        clients[3].totalSecondsToday = 1800;   // Hardware Labs: 30m today
        clients[3].tallyCount = 1;

        // Yesterday's sessions
        clients[0].history.push_back({"2026-09-10 22:15:00", "10 Sep 2026", 7200, 5});   // 2h Deep Coding
        clients[1].history.push_back({"2026-09-10 18:30:00", "10 Sep 2026", 5400, 3});   // 1h 30m System Design
        clients[2].history.push_back({"2026-09-10 16:00:00", "10 Sep 2026", 3600, 12});  // 1h DSA
        clients[3].history.push_back({"2026-09-10 14:00:00", "10 Sep 2026", 2400, 2});   // 40m Hardware

        // 2 days ago
        clients[0].history.push_back({"2026-09-09 21:00:00", "09 Sep 2026", 10800, 7}); // 3h Deep Coding
        clients[2].history.push_back({"2026-09-09 17:30:00", "09 Sep 2026", 5400, 15}); // 1h 30m DSA

        // 3 days ago
        clients[0].history.push_back({"2026-09-08 20:00:00", "08 Sep 2026", 9000, 4});  // 2h 30m Deep Coding
        clients[1].history.push_back({"2026-09-08 15:00:00", "08 Sep 2026", 7200, 6});  // 2h System Design
        clients[3].history.push_back({"2026-09-08 12:00:00", "08 Sep 2026", 3600, 3});  // 1h Hardware

        // Pre-populated Starred Task List for GPIO 20
        tasks.clear();
        tasks.push_back({ 1, "Review Firmware PR #4", 3, false, "2026-09-11 09:00:00" });
        tasks.push_back({ 2, "Test GPIO 20 Task Glance", 3, false, "2026-09-11 09:30:00" });
        tasks.push_back({ 3, "Finish LeetCode Graph", 2, false, "2026-09-11 11:00:00" });
        tasks.push_back({ 4, "Calibrate Desk Haptics", 1, true, "2026-09-11 08:30:00" });
        sortTasks();

        // Daily Reminders & Habit Notes (without ticks)
        reminders.clear();
        reminders.push_back({ 1, "Drink 3L water daily", "2026-09-11 08:00:00" });
        reminders.push_back({ 2, "Read 30 mins before sleep", "2026-09-11 08:00:00" });
        reminders.push_back({ 3, "Plan tomorrow's priorities", "2026-09-11 08:00:00" });
        reminders.push_back({ 4, "Posture & hourly stretch", "2026-09-11 08:00:00" });

        currentStreakDays = 3;
        longestStreakDays = 3;
        lastActiveDate = getSystemDate();
        recordUserActivity();
    }

    void resetAllData() {
        for (auto& c : clients) {
            c.totalSecondsToday = 0;
            c.tallyCount = 0;
            c.history.clear();
        }
        tasks.clear();
        tasks.push_back({ 1, "Review Firmware PR #4", 3, false, getSystemTimestamp() });
        tasks.push_back({ 2, "Test GPIO 20 Task Glance", 3, false, getSystemTimestamp() });
        tasks.push_back({ 3, "Finish LeetCode Graph", 2, false, getSystemTimestamp() });
        tasks.push_back({ 4, "Calibrate Desk Haptics", 1, true, getSystemTimestamp() });
        sortTasks();

        reminders.clear();
        reminders.push_back({ 1, "Drink 3L water daily", getSystemTimestamp() });
        reminders.push_back({ 2, "Read 30 mins before sleep", getSystemTimestamp() });
        reminders.push_back({ 3, "Plan tomorrow's priorities", getSystemTimestamp() });
        reminders.push_back({ 4, "Posture & hourly stretch", getSystemTimestamp() });

        currentSessionSeconds = 0;
        currentStreakDays = 0;
        longestStreakDays = 0;
        lastActiveDate = getSystemDate();
        state = STATE_SELECT_CLIENT;
        recordUserActivity();
    }

    int addClient(String name, bool isNegative = false) {
        recordUserActivity();
        int maxId = 0;
        for (const auto& c : clients) {
            if (c.id > maxId) maxId = c.id;
        }
        ClientInfo newClient;
        newClient.id = maxId + 1;
        if (name.length() > 32) name = name.substring(0, 32);
        newClient.name = name.length() > 0 ? name : "Focus Section";
        newClient.totalSecondsToday = 0;
        newClient.tallyCount = 0;
        newClient.isNegative = isNegative;
        clients.push_back(newClient);
        return newClient.id;
    }

    bool removeClient(int id) {
        recordUserActivity();
        if (clients.size() <= 1) return false;
        for (auto it = clients.begin(); it != clients.end(); ++it) {
            if (it->id == id) {
                clients.erase(it);
                if (activeClientIndex >= (int)clients.size()) {
                    activeClientIndex = clients.size() - 1;
                }
                if (menuIndex >= (int)clients.size() + 1) {
                    menuIndex = 0;
                }
                return true;
            }
        }
        return false;
    }

    bool updateClient(int id, String name, int reps = -1, long totalSecs = -1, int isNegative = -1) {
        recordUserActivity();
        for (auto& c : clients) {
            if (c.id == id) {
                if (name.length() > 32) name = name.substring(0, 32);
                if (name.length() > 0) c.name = name;
                if (reps >= 0) c.tallyCount = reps;
                if (totalSecs >= 0) c.totalSecondsToday = totalSecs;
                if (isNegative == 0) c.isNegative = false;
                else if (isNegative == 1) c.isNegative = true;
                return true;
            }
        }
        return false;
    }

    bool addHistoryRecord(int id, String timestamp, String dateLabel, unsigned long seconds, int reps) {
        recordUserActivity();
        for (auto& c : clients) {
            if (c.id == id) {
                DateRecord r;
                r.timestamp = timestamp.length() > 0 ? timestamp : getSystemTimestamp();
                r.dateLabel = dateLabel.length() > 0 ? dateLabel : getSystemDate();
                r.seconds = seconds;
                r.reps = reps;
                c.history.insert(c.history.begin(), r);
                if (c.history.size() > 50) {
                    c.history.resize(50);
                }
                return true;
            }
        }
        return false;
    }

    bool deleteHistoryRecord(int id, int historyIndex) {
        recordUserActivity();
        for (auto& c : clients) {
            if (c.id == id) {
                if (historyIndex >= 0 && historyIndex < (int)c.history.size()) {
                    c.history.erase(c.history.begin() + historyIndex);
                    return true;
                }
            }
        }
        return false;
    }

    ClientInfo& getActiveClient() {
        if (clients.empty()) {
            clients.push_back({1, "Deep Work", 0, 0, {}, false});
        }
        if (activeClientIndex < 0) activeClientIndex = 0;
        if (activeClientIndex >= (int)clients.size()) activeClientIndex = (int)clients.size() - 1;
        return clients[activeClientIndex];
    }

    unsigned long getGlobalDeepWorkSecondsToday() {
        unsigned long total = 0;
        for (const auto& c : clients) {
            if (!c.isNegative) {
                total += c.totalSecondsToday;
            }
        }
        if ((state == STATE_TRACKING || state == STATE_PAUSED) && !getActiveClient().isNegative) {
            total += currentSessionSeconds;
        }
        return total;
    }

    unsigned long getGlobalWasteSecondsToday() {
        unsigned long total = 0;
        for (const auto& c : clients) {
            if (c.isNegative) {
                total += c.totalSecondsToday;
            }
        }
        if ((state == STATE_TRACKING || state == STATE_PAUSED) && getActiveClient().isNegative) {
            total += currentSessionSeconds;
        }
        return total;
    }

    int getFocusPurityPct() {
        unsigned long dw = getGlobalDeepWorkSecondsToday();
        unsigned long waste = getGlobalWasteSecondsToday();
        unsigned long total = dw + waste;
        if (total == 0) return 100;
        return (int)((dw * 100UL) / total);
    }

    int getGlobalTotalTalliesToday() {
        int total = 0;
        for (const auto& c : clients) {
            total += c.tallyCount;
        }
        return total;
    }

    void incrementTally() {
        recordUserActivity();
        getActiveClient().tallyCount++;
    }

    void decrementTally() {
        recordUserActivity();
        if (getActiveClient().tallyCount > 0) {
            getActiveClient().tallyCount--;
        }
    }

    void nextClient() {
        recordUserActivity();
        if (state == STATE_SELECT_CLIENT) {
            int total = (int)clients.size() + 4;
            menuIndex = (menuIndex + 1) % total;
        }
    }

    void prevClient() {
        recordUserActivity();
        if (state == STATE_SELECT_CLIENT) {
            int total = (int)clients.size() + 4;
            menuIndex = (menuIndex - 1 + total) % total;
        }
    }

    void startTracking() {
        recordUserActivity();
        state = STATE_TRACKING;
        sessionStartMillis = millis();
        lastTickMillis = millis();
        lastAutoSaveMillis = millis();
    }

    void togglePause() {
        recordUserActivity();
        if (state == STATE_TRACKING) {
            state = STATE_PAUSED;
        } else if (state == STATE_PAUSED) {
            state = STATE_TRACKING;
            lastTickMillis = millis();
            lastAutoSaveMillis = millis();
        }
    }

    void stopAndSave(String customTimestamp = "", String customDate = "") {
        recordUserActivity();
        if (state == STATE_TRACKING || state == STATE_PAUSED) {
            if (currentSessionSeconds > 0) {
                ClientInfo& active = getActiveClient();
                active.totalSecondsToday += currentSessionSeconds;

                // Only record session in history ledger if >= 60s (1 minute) to eliminate clutter
                if (currentSessionSeconds >= 60) {
                    DateRecord rec;
                    rec.timestamp = customTimestamp.length() > 0 ? customTimestamp : getSystemTimestamp();
                    rec.dateLabel = customDate.length() > 0 ? customDate : getSystemDate();
                    rec.seconds = currentSessionSeconds;
                    rec.reps = active.tallyCount;
                    active.history.insert(active.history.begin(), rec);
                    if (active.history.size() > 50) {
                        active.history.resize(50);
                    }
                }
            }
            currentSessionSeconds = 0;
            state = STATE_SELECT_CLIENT;
            menuIndex = activeClientIndex;
        }
    }

    bool update() {
        unsigned long now = millis();
        if (state == STATE_TRACKING) {
            if (now - lastTickMillis >= 1000) {
                unsigned long secondsPassed = (now - lastTickMillis) / 1000;
                currentSessionSeconds += secondsPassed;
                lastTickMillis += (secondsPassed * 1000);
            }
        }
        return false;
    }

    bool checkMidnightRollover() {
        struct tm timeinfo;
        if (!getLocalTime(&timeinfo, 30)) return false;

        int currentDay = timeinfo.tm_mday;
        if (lastMidnightCheckDay == -1) {
            lastMidnightCheckDay = currentDay;
            return false;
        }

        if (currentDay != lastMidnightCheckDay) {
            time_t now = time(nullptr) - 86400;
            struct tm yinfo;
            localtime_r(&now, &yinfo);
            char yDateBuf[32];
            strftime(yDateBuf, sizeof(yDateBuf), "%d %b %Y", &yinfo);
            String yesterdayStr = String(yDateBuf);

            // Active tracking straddle: credit pre-midnight seconds to yesterday
            if ((state == STATE_TRACKING || state == STATE_PAUSED) && currentSessionSeconds > 0) {
                getActiveClient().totalSecondsToday += currentSessionSeconds;
                currentSessionSeconds = 0;
                lastTickMillis = millis();
            }

            unsigned long yesterdayGlobalSeconds = 0;
            for (auto& c : clients) {
                if (c.totalSecondsToday > 0 || c.tallyCount > 0) {
                    if (!c.isNegative) {
                        yesterdayGlobalSeconds += c.totalSecondsToday;
                    }
                    DateRecord rec;
                    rec.timestamp = yesterdayStr + " 23:59:59";
                    rec.dateLabel = yesterdayStr;
                    rec.seconds = c.totalSecondsToday;
                    rec.reps = c.tallyCount;
                    c.history.insert(c.history.begin(), rec);
                    if (c.history.size() > 50) {
                        c.history.resize(50);
                    }
                    
                    c.totalSecondsToday = 0;
                    c.tallyCount = 0;
                }
            }

            if (yesterdayGlobalSeconds >= dailyStreakThresholdSeconds) {
                currentStreakDays++;
                if (currentStreakDays > longestStreakDays) {
                    longestStreakDays = currentStreakDays;
                }
            } else {
                currentStreakDays = 0;
            }

            lastMidnightCheckDay = currentDay;
            lastActiveDate = getSystemDate();
            return true;
        }
        return false;
    }
};

extern TrackerManager tracker;
