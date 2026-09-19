#pragma once
#include <Arduino.h>
#include <U8g2lib.h>
#include "pin_config.h"
#include "tracker_state.h"
#include "ble_manager.h"
#include "power_manager.h"

extern U8G2_SH1106_128X64_NONAME_F_HW_I2C u8g2;
extern TrackerManager tracker;
extern BLEManager bleManager;
extern int slideOffset;
extern int trackingPageView;

namespace OledUI {

inline String fitStringToWidth(const String& str, int maxWidthPx) {
    if (u8g2.getStrWidth(str.c_str()) <= maxWidthPx) return str;
    String s = str;
    while (s.length() > 2 && u8g2.getStrWidth((s + ".").c_str()) > maxWidthPx) {
        s = s.substring(0, s.length() - 1);
    }
    return s + ".";
}

inline String formatTime(unsigned long totalSeconds) {
    unsigned long hrs = totalSeconds / 3600;
    unsigned long mins = (totalSeconds % 3600) / 60;
    unsigned long secs = totalSeconds % 60;
    char buf[16];
    snprintf(buf, sizeof(buf), "%02lu:%02lu:%02lu", hrs, mins, secs);
    return String(buf);
}

inline String formatMMSS(unsigned long totalSeconds) {
    unsigned long mins = totalSeconds / 60;
    unsigned long secs = totalSeconds % 60;
    char buf[16];
    snprintf(buf, sizeof(buf), "%02lu:%02lu", mins, secs);
    return String(buf);
}

inline String formatShortTime(unsigned long totalSeconds) {
    unsigned long hrs = totalSeconds / 3600;
    unsigned long mins = (totalSeconds % 3600) / 60;
    char buf[16];
    snprintf(buf, sizeof(buf), "%luh %02lum", hrs, mins);
    return String(buf);
}

inline void renderBootSplash(const char* title, const char* statusMsg) {
    u8g2.clearBuffer();
    u8g2.setFont(u8g2_font_helvB08_tf);
    int tW = u8g2.getStrWidth(title);
    u8g2.drawStr((128 - tW) / 2, 22, title);
    u8g2.setFont(u8g2_font_6x10_tf);
    u8g2.drawStr(12, 42, statusMsg);
    u8g2.sendBuffer();
}

inline void renderReadySplash(const char* title, const String& line1, const char* line2) {
    u8g2.clearBuffer();
    
    // Header
    u8g2.setFont(u8g2_font_helvB08_tf);
    int tW = u8g2.getStrWidth(title);
    u8g2.drawStr((128 - tW) / 2, 16, title);
    u8g2.drawHLine(8, 20, 112);

    // Status Pill / Badge
    u8g2.setFont(u8g2_font_6x10_tf);
    u8g2.drawStr(12, 34, "STATUS: READY");

    // Line 1 (BLE name or IP)
    u8g2.setFont(u8g2_font_5x8_tf);
    u8g2.drawStr(12, 46, line1.c_str());

    // Line 2 (Action hint or mDNS)
    u8g2.setFont(u8g2_font_5x7_tf);
    u8g2.drawStr(12, 58, line2);

    u8g2.sendBuffer();
}

inline void renderGlobalDeepWorkHeader(bool isTrackingScreen) {
    if (isTrackingScreen && tracker.getActiveClient().isNegative) {
        unsigned long wasteSecs = tracker.getGlobalWasteSecondsToday();
        String sinkStr = "[!] SINK " + formatShortTime(wasteSecs);
        u8g2.setFont(u8g2_font_5x8_tf);
        u8g2.drawStr(2, 8, sinkStr.c_str());

        int purity = tracker.getFocusPurityPct();
        char purBuf[16];
        snprintf(purBuf, sizeof(purBuf), "%d%% PURITY", purity);
        u8g2.setFont(u8g2_font_5x7_tf);
        int pW = u8g2.getStrWidth(purBuf);
        u8g2.drawStr(126 - pW, 8, purBuf);
        u8g2.drawHLine(0, 10, 128);
        return;
    }

    unsigned long dwSeconds = tracker.getGlobalDeepWorkSecondsToday();
    String dwStr = "DW " + formatShortTime(dwSeconds);
    
    // Left: DW Total with hours and minutes (e.g. "DW 0h 00m", "DW 1h 30m")
    u8g2.setFont(u8g2_font_5x8_tf);
    u8g2.drawStr(2, 8, dwStr.c_str());
    int dwW = u8g2.getStrWidth(dwStr.c_str());
    int leftEnd = 2 + dwW;

    // Calculate Goal Progress %
    unsigned long goal = tracker.globalDeepWorkGoalSeconds > 0 ? tracker.globalDeepWorkGoalSeconds : 36000;
    int pct = (dwSeconds * 100) / goal;
    if (pct > 100) pct = 100;

    // Right: Percentage Readout
    char pctBuf[8];
    snprintf(pctBuf, sizeof(pctBuf), "%d%%", pct);
    u8g2.setFont(u8g2_font_5x7_tf);
    int pW = u8g2.getStrWidth(pctBuf);
    int pctX = 116 - pW;
    u8g2.drawStr(pctX, 8, pctBuf);

    // Center: Extended Progress Bar Capsule with Equalized Spacing
    int availableSpace = pctX - leftEnd;
    int gap = (availableSpace >= 50) ? 5 : ((availableSpace >= 42) ? 4 : 3);
    int barX = leftEnd + gap;
    int barW = (pctX - gap) - barX;
    if (barW < 32) barW = 32;

    u8g2.drawRFrame(barX, 2, barW, 6, 2);
    
    int fillW = (pct * (barW - 4)) / 100;
    if (fillW > (barW - 4)) fillW = (barW - 4);
    if (fillW > 0) {
        u8g2.drawBox(barX + 2, 3, fillW, 4);
    }

    // Far Right: Status & Bluetooth Link Indicator
    if (bleManager.isConnected) {
        // High-contrast Bluetooth connected glyph (solid target dot)
        u8g2.drawDisc(122, 5, 2);
        u8g2.setDrawColor(0);
        u8g2.drawPixel(122, 5);
        u8g2.setDrawColor(1);
    } else if (isTrackingScreen) {
        if (tracker.state == STATE_TRACKING) {
            if ((millis() / 500) % 2 == 0) {
                u8g2.drawDisc(122, 5, 2);
            } else {
                u8g2.drawCircle(122, 5, 2);
            }
        } else if (tracker.state == STATE_PAUSED) {
            u8g2.drawCircle(122, 5, 2);
        }
    } else {
        u8g2.drawCircle(122, 5, 2);
    }

    u8g2.drawHLine(0, 10, 128);
}

inline void renderClientSelectScreen() {
    u8g2.clearBuffer();
    renderGlobalDeepWorkHeader(false);

    int totalClients = tracker.clients.size();
    int totalItems = totalClients + 8;
    int selected = tracker.menuIndex;
    if (selected >= totalItems) selected = 0;

    int startIdx = selected - 1;
    if (startIdx < 0) startIdx = 0;
    if (startIdx + 2 >= totalItems && totalItems >= 3) startIdx = totalItems - 3;

    int y = 24;
    for (int i = startIdx; i < startIdx + 3 && i < totalItems; i++) {
        if (i < totalClients) {
            char repsBuf[16];
            if (tracker.clients[i].isNegative) {
                snprintf(repsBuf, sizeof(repsBuf), "SINK %02d", tracker.clients[i].tallyCount);
            } else {
                snprintf(repsBuf, sizeof(repsBuf), "%02d REPS", tracker.clients[i].tallyCount);
            }

            u8g2.setFont(u8g2_font_helvB08_tf);
            String rawName = tracker.clients[i].isNegative ? ("[!] " + tracker.clients[i].name) : tracker.clients[i].name;
            String cName = fitStringToWidth(rawName, 74);

            if (i == selected) {
                u8g2.drawRBox(0, y - 9, 128, 12, 2);
                u8g2.setDrawColor(0);
                u8g2.setFont(u8g2_font_helvB08_tf);
                u8g2.drawStr(4, y, cName.c_str());
                u8g2.setFont(u8g2_font_5x8_tf);
                int rw = u8g2.getStrWidth(repsBuf);
                u8g2.drawStr(126 - rw, y - 1, repsBuf);
                u8g2.setDrawColor(1);
            } else {
                u8g2.setFont(u8g2_font_6x10_tf);
                u8g2.drawStr(6, y, cName.c_str());
                u8g2.setFont(u8g2_font_5x8_tf);
                int rw = u8g2.getStrWidth(repsBuf);
                u8g2.drawStr(126 - rw, y - 1, repsBuf);
            }
        } else if (i == totalClients) {
            // [ ⭐ Task List ]
            int doneC = 0;
            for (const auto& t : tracker.tasks) if (t.done) doneC++;
            char taskBuf[32];
            snprintf(taskBuf, sizeof(taskBuf), "%s TASK LIST (%d/%d) %s", 
                (i == selected ? ">>" : "["), doneC, (int)tracker.tasks.size(), (i == selected ? "<<" : "]"));
            if (i == selected) {
                u8g2.drawRBox(0, y - 9, 128, 12, 2);
                u8g2.setDrawColor(0);
                u8g2.setFont(u8g2_font_helvB08_tf);
                int rW = u8g2.getStrWidth(taskBuf);
                u8g2.drawStr((128 - rW) / 2, y, taskBuf);
                u8g2.setDrawColor(1);
            } else {
                u8g2.setFont(u8g2_font_6x10_tf);
                int rW = u8g2.getStrWidth(taskBuf);
                u8g2.drawStr((128 - rW) / 2, y, taskBuf);
            }
        } else if (i == totalClients + 1) {
            // [ 📝 Daily Notes / Reminders ]
            char noteBuf[32];
            snprintf(noteBuf, sizeof(noteBuf), "%s DAILY NOTES (%d) %s",
                (i == selected ? ">>" : "["), (int)tracker.reminders.size(), (i == selected ? "<<" : "]"));
            if (i == selected) {
                u8g2.drawRBox(0, y - 9, 128, 12, 2);
                u8g2.setDrawColor(0);
                u8g2.setFont(u8g2_font_helvB08_tf);
                int rW = u8g2.getStrWidth(noteBuf);
                u8g2.drawStr((128 - rW) / 2, y, noteBuf);
                u8g2.setDrawColor(1);
            } else {
                u8g2.setFont(u8g2_font_6x10_tf);
                int rW = u8g2.getStrWidth(noteBuf);
                u8g2.drawStr((128 - rW) / 2, y, noteBuf);
            }
        } else if (i == totalClients + 2) {
            // [ Session Logs ]
            if (i == selected) {
                u8g2.drawRBox(0, y - 9, 128, 12, 2);
                u8g2.setDrawColor(0);
                u8g2.setFont(u8g2_font_helvB08_tf);
                int rW = u8g2.getStrWidth(">> SESSION LOGS <<");
                u8g2.drawStr((128 - rW) / 2, y, ">> SESSION LOGS <<");
                u8g2.setDrawColor(1);
            } else {
                u8g2.setFont(u8g2_font_6x10_tf);
                int rW = u8g2.getStrWidth("[ Session Logs ]");
                u8g2.drawStr((128 - rW) / 2, y, "[ Session Logs ]");
            }
        } else if (i == totalClients + 3) {
            // [ Total Summary ]
            if (i == selected) {
                u8g2.drawRBox(0, y - 9, 128, 12, 2);
                u8g2.setDrawColor(0);
                u8g2.setFont(u8g2_font_helvB08_tf);
                int rW = u8g2.getStrWidth(">> TOTAL SUMMARY <<");
                u8g2.drawStr((128 - rW) / 2, y, ">> TOTAL SUMMARY <<");
                u8g2.setDrawColor(1);
            } else {
                u8g2.setFont(u8g2_font_6x10_tf);
                int rW = u8g2.getStrWidth("[ Total Summary ]");
                u8g2.drawStr((128 - rW) / 2, y, "[ Total Summary ]");
            }
        } else if (i == totalClients + 4) {
            // [ Brightness: X% ]
            int pct = (tracker.activeBrightness * 100) / 255;
            char bBuf[32];
            if (i == selected) {
                snprintf(bBuf, sizeof(bBuf), ">> BRIGHTNESS: %d%% <<", pct);
                u8g2.drawRBox(0, y - 9, 128, 12, 2);
                u8g2.setDrawColor(0);
                u8g2.setFont(u8g2_font_helvB08_tf);
                int rW = u8g2.getStrWidth(bBuf);
                u8g2.drawStr((128 - rW) / 2, y, bBuf);
                u8g2.setDrawColor(1);
            } else {
                snprintf(bBuf, sizeof(bBuf), "[ Brightness: %d%% ]", pct);
                u8g2.setFont(u8g2_font_6x10_tf);
                int rW = u8g2.getStrWidth(bBuf);
                u8g2.drawStr((128 - rW) / 2, y, bBuf);
            }
        } else if (i == totalClients + 5) {
            // [ 💧 Wellness Alerts ]
            char wBuf[32];
            if (tracker.wellnessEnabled) {
                snprintf(wBuf, sizeof(wBuf), "%s WELLNESS: %dm ON %s",
                    (i == selected ? ">>" : "["), tracker.wellnessIntervalMinutes, (i == selected ? "<<" : "]"));
            } else {
                snprintf(wBuf, sizeof(wBuf), "%s WELLNESS: OFF %s",
                    (i == selected ? ">>" : "["), (i == selected ? "<<" : "]"));
            }
            if (i == selected) {
                u8g2.drawRBox(0, y - 9, 128, 12, 2);
                u8g2.setDrawColor(0);
                u8g2.setFont(u8g2_font_helvB08_tf);
                int rW = u8g2.getStrWidth(wBuf);
                u8g2.drawStr((128 - rW) / 2, y, wBuf);
                u8g2.setDrawColor(1);
            } else {
                u8g2.setFont(u8g2_font_6x10_tf);
                int rW = u8g2.getStrWidth(wBuf);
                u8g2.drawStr((128 - rW) / 2, y, wBuf);
            }
        } else if (i == totalClients + 6) {
            // [ ⚡ PB KeepAlive: ON / OFF ]
            char pbBuf[32];
            snprintf(pbBuf, sizeof(pbBuf), "%s PB KEEPALIVE: %s %s",
                (i == selected ? ">>" : "["), PowerManager::keepAliveEnabled ? "ON" : "OFF", (i == selected ? "<<" : "]"));
            if (i == selected) {
                u8g2.drawRBox(0, y - 9, 128, 12, 2);
                u8g2.setDrawColor(0);
                u8g2.setFont(u8g2_font_helvB08_tf);
                int rW = u8g2.getStrWidth(pbBuf);
                u8g2.drawStr((128 - rW) / 2, y, pbBuf);
                u8g2.setDrawColor(1);
            } else {
                u8g2.setFont(u8g2_font_6x10_tf);
                int rW = u8g2.getStrWidth(pbBuf);
                u8g2.drawStr((128 - rW) / 2, y, pbBuf);
            }
        } else {
            // [ Hard Reset ]
            if (i == selected) {
                u8g2.drawRBox(0, y - 9, 128, 12, 2);
                u8g2.setDrawColor(0);
                u8g2.setFont(u8g2_font_helvB08_tf);
                const char* rstStr = ">> ZERO HARD RESET <<";
                int rW = u8g2.getStrWidth(rstStr);
                u8g2.drawStr((128 - rW) / 2, y, rstStr);
                u8g2.setDrawColor(1);
            } else {
                u8g2.setFont(u8g2_font_6x10_tf);
                const char* rstStr = "[ Hard Reset ]";
                int rW = u8g2.getStrWidth(rstStr);
                u8g2.drawStr((128 - rW) / 2, y, rstStr);
            }
        }
        y += 13;
    }

    u8g2.drawHLine(0, 52, 128);
    int dotCount = totalItems > 14 ? 14 : totalItems;
    int dotStartX = (128 - (dotCount * 7)) / 2;
    int activeDot = selected;
    if (totalItems > 14 && totalItems > 1) {
        activeDot = (selected * (dotCount - 1)) / (totalItems - 1);
    }
    for (int d = 0; d < dotCount; d++) {
        if (d == activeDot) {
            u8g2.drawDisc(dotStartX + (d * 7) + 3, 58, 2);
        } else {
            u8g2.drawCircle(dotStartX + (d * 7) + 3, 58, 2);
        }
    }

    u8g2.sendBuffer();
}

inline void renderSummaryScreen() {
    u8g2.clearBuffer();

    unsigned long totalSecs = tracker.getGlobalDeepWorkSecondsToday();
    int totalReps = tracker.getGlobalTotalTalliesToday();
    
    u8g2.setFont(u8g2_font_helvB08_tf);
    u8g2.drawStr(2, 8, "TOTAL");
    
    String totalStr = formatShortTime(totalSecs);
    u8g2.setFont(u8g2_font_6x10_tf);
    int tW = u8g2.getStrWidth(totalStr.c_str());
    u8g2.drawStr(126 - tW, 8, totalStr.c_str());
    u8g2.drawHLine(0, 10, 128);

    int totalClients = tracker.clients.size();
    int selected = tracker.summaryIndex;
    if (selected >= totalClients) selected = 0;

    int startIdx = selected - 1;
    if (startIdx < 0) startIdx = 0;
    if (startIdx + 2 >= totalClients && totalClients >= 3) startIdx = totalClients - 3;

    int y = 24;
    for (int i = startIdx; i < startIdx + 3 && i < totalClients; i++) {
        u8g2.setFont(u8g2_font_6x10_tf);
        String cName = fitStringToWidth(tracker.clients[i].name, 56);

        char statBuf[16];
        snprintf(statBuf, sizeof(statBuf), "%s", formatShortTime(tracker.clients[i].totalSecondsToday).c_str());
        
        char repBuf[10];
        snprintf(repBuf, sizeof(repBuf), "%02dR", tracker.clients[i].tallyCount);

        if (i == selected) {
            u8g2.drawRBox(0, y - 9, 128, 12, 2);
            u8g2.setDrawColor(0);
            u8g2.setFont(u8g2_font_helvB08_tf);
            u8g2.drawStr(4, y, cName.c_str());
            u8g2.setFont(u8g2_font_5x8_tf);
            u8g2.drawStr(64, y - 1, statBuf);
            u8g2.drawStr(104, y - 1, repBuf);
            u8g2.setDrawColor(1);
        } else {
            u8g2.setFont(u8g2_font_6x10_tf);
            u8g2.drawStr(4, y, cName.c_str());
            u8g2.setFont(u8g2_font_5x8_tf);
            u8g2.drawStr(64, y - 1, statBuf);
            u8g2.drawStr(104, y - 1, repBuf);
        }
        y += 13;
    }

    u8g2.drawHLine(0, 50, 128);
    
    char footBuf[20];
    snprintf(footBuf, sizeof(footBuf), "%02d REPS", totalReps);
    u8g2.setFont(u8g2_font_5x8_tf);

    if (tracker.state == STATE_TRACKING || tracker.state == STATE_PAUSED) {
        u8g2.drawCircle(6, 58, 2);
        u8g2.drawCircle(13, 58, 2);
        u8g2.drawDisc(20, 58, 2);
        u8g2.drawStr(32, 60, footBuf);
    } else {
        u8g2.drawStr(4, 60, footBuf);
    }

    char streakBuf[16];
    snprintf(streakBuf, sizeof(streakBuf), "%dd STREAK", tracker.currentStreakDays);
    u8g2.setFont(u8g2_font_5x8_tf);
    int sW = u8g2.getStrWidth(streakBuf);
    u8g2.drawStr(126 - sW, 60, streakBuf);

    u8g2.sendBuffer();
}

struct LogDisplayItem {
    String name;
    String dateOrTime;
    unsigned long seconds;
    int reps;
    bool isToday;
};

inline void renderSessionLogsScreen() {
    u8g2.clearBuffer();

    std::vector<LogDisplayItem> allLogs;
    for (size_t c = 0; c < tracker.clients.size(); c++) {
        const ClientInfo& client = tracker.clients[c];
        unsigned long secsToday = client.totalSecondsToday;
        bool isActiveSession = (tracker.state == STATE_TRACKING || tracker.state == STATE_PAUSED) && ((int)c == tracker.activeClientIndex);
        if (isActiveSession) {
            secsToday += tracker.currentSessionSeconds;
        }
        if (secsToday > 0 || client.tallyCount > 0 || isActiveSession) {
            LogDisplayItem item;
            item.name = client.name;
            item.dateOrTime = isActiveSession ? "Today (Live)" : "Today";
            item.seconds = secsToday;
            item.reps = client.tallyCount;
            item.isToday = true;
            allLogs.push_back(item);
        }
        for (size_t h = 0; h < client.history.size(); h++) {
            const DateRecord& rec = client.history[h];
            LogDisplayItem item;
            item.name = client.name;
            if (rec.timestamp.length() >= 16) {
                item.dateOrTime = rec.timestamp.substring(5, 16);
            } else {
                item.dateOrTime = rec.dateLabel;
            }
            item.seconds = rec.seconds;
            item.reps = rec.reps;
            item.isToday = false;
            allLogs.push_back(item);
        }
    }

    int totalLogs = allLogs.size();
    if (totalLogs == 0) {
        u8g2.setFont(u8g2_font_helvB08_tf);
        u8g2.drawStr(16, 28, "NO LOGS YET");
        u8g2.setFont(u8g2_font_5x8_tf);
        u8g2.drawStr(10, 44, "Start focus to log time!");
        u8g2.drawHLine(0, 52, 128);
        u8g2.drawStr(16, 61, "Click knob to return");
        u8g2.sendBuffer();
        return;
    }

    if (tracker.logScrollIndex >= totalLogs) tracker.logScrollIndex = totalLogs - 1;
    if (tracker.logScrollIndex < 0) tracker.logScrollIndex = 0;
    int cur = tracker.logScrollIndex;

    // Header bar
    u8g2.setFont(u8g2_font_helvB08_tf);
    u8g2.drawStr(2, 8, "SESSION LOGS");
    
    char countBuf[16];
    snprintf(countBuf, sizeof(countBuf), "%d of %d", cur + 1, totalLogs);
    u8g2.setFont(u8g2_font_5x8_tf);
    int cW = u8g2.getStrWidth(countBuf);
    u8g2.drawStr(126 - cW, 8, countBuf);
    u8g2.drawHLine(0, 10, 128);

    // Active log card
    const LogDisplayItem& log = allLogs[cur];
    
    // Section Name + Tag
    u8g2.setFont(u8g2_font_helvB08_tf);
    String nameStr = fitStringToWidth(log.name, 72);
    u8g2.drawStr(2, 21, nameStr.c_str());

    // Date/Time pill
    u8g2.setFont(u8g2_font_5x7_tf);
    int dW = u8g2.getStrWidth(log.dateOrTime.c_str());
    u8g2.drawStr(126 - dW, 20, log.dateOrTime.c_str());

    // Duration Large
    u8g2.setFont(u8g2_font_logisoso16_tn);
    String durStr = formatTime(log.seconds);
    u8g2.drawStr(2, 40, durStr.c_str());

    // Reps & Hours on right
    u8g2.setFont(u8g2_font_helvB08_tf);
    char durHrBuf[16];
    snprintf(durHrBuf, sizeof(durHrBuf), "%.1fh", (float)log.seconds / 3600.0f);
    u8g2.drawStr(86, 31, durHrBuf);

    char repsBuf[12];
    snprintf(repsBuf, sizeof(repsBuf), "%02d REPS", log.reps);
    u8g2.setFont(u8g2_font_5x8_tf);
    u8g2.drawStr(86, 42, repsBuf);

    u8g2.drawHLine(0, 48, 128);

    // Footer: Scroll hint
    u8g2.setFont(u8g2_font_4x6_tf);
    u8g2.drawStr(2, 56, "TURN KNOB: SCROLL SESSIONS");
    u8g2.drawStr(2, 63, "CLICK KNOB: BACK TO MENU");

    // Scrollbar indicator on right edge
    if (totalLogs > 1) {
        int barH = max(4, 14 / totalLogs);
        int barY = 49 + (cur * (14 - barH)) / (totalLogs - 1);
        u8g2.drawBox(124, barY, 3, barH);
    }

    u8g2.sendBuffer();
}

inline void renderTaskListScreen() {
    u8g2.clearBuffer();

    int totalTasks = tracker.tasks.size();
    if (totalTasks == 0) {
        u8g2.setFont(u8g2_font_helvB08_tf);
        u8g2.drawStr(20, 24, "NO TASKS YET");
        u8g2.setFont(u8g2_font_5x8_tf);
        u8g2.drawStr(8, 38, "Add via Phone or PC");
        u8g2.drawStr(8, 48, "IP: 192.168.0.210");
        u8g2.drawHLine(0, 52, 128);
        u8g2.setFont(u8g2_font_4x6_tf);
        u8g2.drawStr(12, 61, "CLICK KNOB / G20 TO RETURN");
        u8g2.sendBuffer();
        return;
    }

    if (tracker.taskScrollIndex >= totalTasks) tracker.taskScrollIndex = totalTasks - 1;
    if (tracker.taskScrollIndex < 0) tracker.taskScrollIndex = 0;
    int cur = tracker.taskScrollIndex;

    // Header bar
    u8g2.setFont(u8g2_font_helvB08_tf);
    u8g2.drawStr(2, 8, "TASKS");

    int doneCount = 0;
    for (const auto& t : tracker.tasks) {
        if (t.done) doneCount++;
    }
    char headBuf[20];
    snprintf(headBuf, sizeof(headBuf), "%d/%d DONE", doneCount, totalTasks);
    u8g2.setFont(u8g2_font_5x8_tf);
    int hW = u8g2.getStrWidth(headBuf);
    u8g2.drawStr(126 - hW, 8, headBuf);
    u8g2.drawHLine(0, 10, 128);

    // Visible 4-task window
    int startIdx = cur - 1;
    if (startIdx < 0) startIdx = 0;
    if (startIdx + 3 >= totalTasks && totalTasks >= 4) startIdx = totalTasks - 4;
    if (cur >= startIdx + 4) startIdx = cur - 3;

    int y = 22;
    for (int i = startIdx; i < startIdx + 4 && i < totalTasks; i++) {
        const TaskItem& task = tracker.tasks[i];
        bool isSel = (i == cur);

        // Stars string
        String starsStr = "";
        for (int s = 0; s < task.stars; s++) starsStr += "*";

        String tName = fitStringToWidth(task.text, 78);

        if (isSel) {
            u8g2.drawRBox(0, y - 9, 122, 12, 2);
            u8g2.setDrawColor(0);

            // Checkbox
            u8g2.drawFrame(3, y - 8, 8, 8);
            if (task.done) {
                u8g2.drawBox(5, y - 6, 4, 4);
            }

            // Stars
            u8g2.setFont(u8g2_font_5x8_tf);
            u8g2.drawStr(15, y - 1, starsStr.c_str());

            // Task text
            u8g2.setFont(u8g2_font_helvB08_tf);
            u8g2.drawStr(34, y, tName.c_str());

            // Strikethrough if done
            if (task.done) {
                int txtW = u8g2.getStrWidth(tName.c_str());
                u8g2.drawHLine(34, y - 4, txtW);
            }

            u8g2.setDrawColor(1);
        } else {
            // Checkbox
            u8g2.drawFrame(3, y - 8, 8, 8);
            if (task.done) {
                u8g2.drawBox(5, y - 6, 4, 4);
            }

            // Stars
            u8g2.setFont(u8g2_font_5x8_tf);
            u8g2.drawStr(15, y - 1, starsStr.c_str());

            // Task text
            u8g2.setFont(u8g2_font_6x10_tf);
            u8g2.drawStr(34, y, tName.c_str());

            // Strikethrough if done
            if (task.done) {
                int txtW = u8g2.getStrWidth(tName.c_str());
                u8g2.drawHLine(34, y - 4, txtW);
            }
        }
        y += 13;
    }

    // Scrollbar indicator
    if (totalTasks > 4) {
        int trackH = 50;
        int barH = max(4, trackH / totalTasks);
        int barY = 13 + (cur * (trackH - barH)) / (totalTasks - 1);
        u8g2.drawBox(125, barY, 2, barH);
    }

    u8g2.sendBuffer();
}

inline void renderChecklistScreen() {
    u8g2.clearBuffer();

    int totalItems = tracker.checklist.size();
    if (totalItems == 0) {
        u8g2.setFont(u8g2_font_helvB08_tf);
        u8g2.drawStr(10, 24, "NO CHECKLIST YET");
        u8g2.setFont(u8g2_font_5x8_tf);
        u8g2.drawStr(8, 38, "Add via Phone or PC");
        u8g2.drawHLine(0, 52, 128);
        u8g2.setFont(u8g2_font_4x6_tf);
        u8g2.drawStr(12, 61, "CLICK KNOB / G20 TO RETURN");
        u8g2.sendBuffer();
        return;
    }

    int totalRows = totalItems + 1; // +1 for RESET button
    if (tracker.checklistScrollIndex >= totalRows) tracker.checklistScrollIndex = totalRows - 1;
    if (tracker.checklistScrollIndex < 0) tracker.checklistScrollIndex = 0;
    int cur = tracker.checklistScrollIndex;

    // Header bar
    u8g2.setFont(u8g2_font_helvB08_tf);
    u8g2.drawStr(2, 8, "CHECKLIST");

    int doneCount = 0;
    for (const auto& c : tracker.checklist) {
        if (c.done) doneCount++;
    }
    char headBuf[20];
    snprintf(headBuf, sizeof(headBuf), "%d/%d", doneCount, totalItems);
    u8g2.setFont(u8g2_font_5x8_tf);
    int hW = u8g2.getStrWidth(headBuf);
    u8g2.drawStr(126 - hW, 8, headBuf);
    u8g2.drawHLine(0, 10, 128);

    // Visible 4-task window
    int startIdx = cur - 1;
    if (startIdx < 0) startIdx = 0;
    if (startIdx + 3 >= totalRows && totalRows >= 4) startIdx = totalRows - 4;
    if (cur >= startIdx + 4) startIdx = cur - 3;

    int y = 22;
    for (int i = startIdx; i < startIdx + 4 && i < totalRows; i++) {
        bool isSel = (i == cur);

        if (i == totalItems) {
            // Reset Button
            String tName = ">> RESET LIST <<";
            if (isSel) {
                u8g2.drawRBox(0, y - 9, 122, 12, 2);
                u8g2.setDrawColor(0);
                u8g2.setFont(u8g2_font_helvB08_tf);
                int txtW = u8g2.getStrWidth(tName.c_str());
                u8g2.drawStr((122 - txtW) / 2, y, tName.c_str());
                u8g2.setDrawColor(1);
            } else {
                u8g2.setFont(u8g2_font_6x10_tf);
                int txtW = u8g2.getStrWidth(tName.c_str());
                u8g2.drawStr((122 - txtW) / 2, y, tName.c_str());
            }
        } else {
            const ChecklistItem& item = tracker.checklist[i];
            String tName = fitStringToWidth(item.text, 100);

            if (isSel) {
                u8g2.drawRBox(0, y - 9, 122, 12, 2);
                u8g2.setDrawColor(0);

                // Checkbox
                u8g2.drawFrame(3, y - 8, 8, 8);
                if (item.done) {
                    u8g2.drawBox(5, y - 6, 4, 4);
                }

                // Text
                u8g2.setFont(u8g2_font_helvB08_tf);
                u8g2.drawStr(15, y, tName.c_str());

                // Strikethrough if done
                if (item.done) {
                    int txtW = u8g2.getStrWidth(tName.c_str());
                    u8g2.drawHLine(15, y - 4, txtW);
                }

                u8g2.setDrawColor(1);
            } else {
                // Checkbox
                u8g2.drawFrame(3, y - 8, 8, 8);
                if (item.done) {
                    u8g2.drawBox(5, y - 6, 4, 4);
                }

                // Text
                u8g2.setFont(u8g2_font_6x10_tf);
                u8g2.drawStr(15, y, tName.c_str());

                // Strikethrough if done
                if (item.done) {
                    int txtW = u8g2.getStrWidth(tName.c_str());
                    u8g2.drawHLine(15, y - 4, txtW);
                }
            }
        }
        y += 13;
    }

    // Scrollbar indicator
    if (totalRows > 4) {
        int trackH = 50;
        int barH = max(4, trackH / totalRows);
        int barY = 13 + (cur * (trackH - barH)) / (totalRows - 1);
        u8g2.drawBox(125, barY, 2, barH);
    }

    u8g2.sendBuffer();
}

inline void renderRemindersScreen() {
    u8g2.clearBuffer();

    int totalReminders = tracker.reminders.size();
    if (totalReminders == 0) {
        u8g2.setFont(u8g2_font_helvB08_tf);
        u8g2.drawStr(14, 24, "NO REMINDERS YET");
        u8g2.setFont(u8g2_font_5x8_tf);
        u8g2.drawStr(8, 38, "Add via Phone or Web");
        u8g2.drawStr(8, 48, "IP: 192.168.0.210");
        u8g2.drawHLine(0, 52, 128);
        u8g2.setFont(u8g2_font_4x6_tf);
        u8g2.drawStr(12, 61, "CLICK KNOB / G20 TO RETURN");
        u8g2.sendBuffer();
        return;
    }

    if (tracker.reminderScrollIndex >= totalReminders) tracker.reminderScrollIndex = totalReminders - 1;
    if (tracker.reminderScrollIndex < 0) tracker.reminderScrollIndex = 0;
    int cur = tracker.reminderScrollIndex;

    // Header bar
    u8g2.setFont(u8g2_font_helvB08_tf);
    u8g2.drawStr(2, 8, "DAILY NOTES");

    char headBuf[16];
    snprintf(headBuf, sizeof(headBuf), "%d/%d", cur + 1, totalReminders);
    u8g2.setFont(u8g2_font_5x8_tf);
    int hW = u8g2.getStrWidth(headBuf);
    u8g2.drawStr(126 - hW, 8, headBuf);
    u8g2.drawHLine(0, 10, 128);

    // Visible 4-item window (checklist without ticks)
    int startIdx = cur - 1;
    if (startIdx < 0) startIdx = 0;
    if (startIdx + 3 >= totalReminders && totalReminders >= 4) startIdx = totalReminders - 4;
    if (cur >= startIdx + 4) startIdx = cur - 3;

    int y = 22;
    for (int i = startIdx; i < startIdx + 4 && i < totalReminders; i++) {
        const ReminderItem& item = tracker.reminders[i];
        bool isSel = (i == cur);

        String rText = fitStringToWidth(item.text, 108);

        if (isSel) {
            u8g2.drawRBox(0, y - 9, 122, 12, 2);
            u8g2.setDrawColor(0);

            // Tactical solid bullet dot
            u8g2.drawDisc(5, y - 4, 2);

            // Reminder text
            u8g2.setFont(u8g2_font_helvB08_tf);
            u8g2.drawStr(12, y, rText.c_str());

            u8g2.setDrawColor(1);
        } else {
            // Unselected bullet dot outline
            u8g2.drawCircle(5, y - 4, 2);

            // Reminder text
            u8g2.setFont(u8g2_font_6x10_tf);
            u8g2.drawStr(12, y, rText.c_str());
        }
        y += 13;
    }

    // Scrollbar indicator
    if (totalReminders > 4) {
        int trackH = 50;
        int barH = max(4, trackH / totalReminders);
        int barY = 13 + (cur * (trackH - barH)) / (totalReminders - 1);
        u8g2.drawBox(125, barY, 2, barH);
    }

    u8g2.sendBuffer();
}

inline void renderBrightnessScreen() {
    u8g2.clearBuffer();

    // Header bar
    u8g2.setFont(u8g2_font_helvB08_tf);
    u8g2.drawStr(2, 8, "DISPLAY BRIGHTNESS");
    u8g2.drawHLine(0, 10, 128);

    // Large Percentage readout
    int pct = (tracker.activeBrightness * 100) / 255;
    char pctBuf[16];
    snprintf(pctBuf, sizeof(pctBuf), "%d%%", pct);

    u8g2.setFont(u8g2_font_logisoso18_tn);
    int pW = u8g2.getStrWidth(pctBuf);
    u8g2.drawStr((128 - pW) / 2, 33, pctBuf);

    // Horizontal segmented contrast gauge bar
    // Outer frame: x=14, y=38, w=100, h=8
    u8g2.drawFrame(14, 38, 100, 8);
    int fillW = ((tracker.activeBrightness - 10) * 96) / (255 - 10);
    if (fillW < 2) fillW = 2;
    if (fillW > 96) fillW = 96;
    u8g2.drawBox(16, 40, fillW, 4);

    u8g2.drawHLine(0, 50, 128);

    // Footer hints
    u8g2.setFont(u8g2_font_4x6_tf);
    u8g2.drawStr(2, 57, "TURN KNOB: ADJUST (10% - 100%)");
    u8g2.drawStr(2, 63, "CLICK KNOB: SAVE & RETURN");

    u8g2.sendBuffer();
}

inline void renderTrackingScreen() {
    u8g2.clearBuffer();
    renderGlobalDeepWorkHeader(true);

    ClientInfo& client = tracker.getActiveClient();

    u8g2.setFont(u8g2_font_helvB08_tf);
    String rawName = client.isNegative ? ("[!] " + client.name) : client.name;
    String cName = fitStringToWidth(rawName, 120);
    u8g2.drawStr(2 + slideOffset, 22, cName.c_str());

    u8g2.setFont(u8g2_font_logisoso18_tn);
    String timeStr = formatTime(tracker.currentSessionSeconds);
    int strWidth = u8g2.getStrWidth(timeStr.c_str());
    int xCenter = (128 - strWidth) / 2;
    u8g2.drawStr(xCenter + slideOffset, 44, timeStr.c_str());

    u8g2.drawHLine(0, 49, 128);
    
    // Left: Page indicator dots (● ○ ○)
    u8g2.drawDisc(6, 57, 2);
    u8g2.drawCircle(13, 57, 2);
    u8g2.drawCircle(20, 57, 2);

    float todayHrs = (float)(client.totalSecondsToday + tracker.currentSessionSeconds) / 3600.0f;
    char todayStr[16];
    if (client.isNegative) {
        snprintf(todayStr, sizeof(todayStr), "%.1fh SINK", todayHrs);
    } else {
        snprintf(todayStr, sizeof(todayStr), "%.1fh TODAY", todayHrs);
    }
    u8g2.setFont(u8g2_font_5x8_tf);
    int todayW = u8g2.getStrWidth(todayStr);
    u8g2.drawStr((128 - todayW) / 2, 60, todayStr);

    char repsText[16];
    snprintf(repsText, sizeof(repsText), "%02d REPS", client.tallyCount);
    int txtWidth = u8g2.getStrWidth(repsText);
    u8g2.drawStr(126 - txtWidth, 60, repsText);

    u8g2.sendBuffer();
}

inline void renderActivityHistoryScreen() {
    u8g2.clearBuffer();
    renderGlobalDeepWorkHeader(true);

    ClientInfo& client = tracker.getActiveClient();
    unsigned long allTimeSecs = tracker.getTotalAccumulatedSecondsForActiveClient();
    float allTimeHrs = (float)allTimeSecs / 3600.0f;
    float todayHrs = (float)(client.totalSecondsToday + tracker.currentSessionSeconds) / 3600.0f;

    const char* badge = client.isNegative ? "SINK" : "LVL 0";
    if (!client.isNegative) {
        if (allTimeHrs < 2.0f) badge = "LVL 0";
        else if (allTimeHrs < 5.0f) badge = "LVL 1";
        else if (allTimeHrs < 10.0f) badge = "LVL 2";
        else if (allTimeHrs < 15.0f) badge = "LVL 3";
        else if (allTimeHrs < 20.0f) badge = "LVL 4";
        else badge = "LVL 5";
    }

    u8g2.setFont(u8g2_font_helvB08_tf);
    String cName = fitStringToWidth(client.name, 80);
    u8g2.drawStr(2 + slideOffset, 21, cName.c_str());

    int badgeW = 36;
    u8g2.drawRBox(128 - badgeW - 2 + slideOffset, 12, badgeW, 10, 2);
    u8g2.setDrawColor(0);
    u8g2.setFont(u8g2_font_5x7_tf);
    u8g2.drawStr(128 - badgeW + 2 + slideOffset, 20, badge);
    u8g2.setDrawColor(1);

    // Hero Dual-Card (TODAY & ALL-TIME)
    u8g2.setFont(u8g2_font_5x7_tf);
    u8g2.drawStr(8 + slideOffset, 33, "TODAY");

    u8g2.setFont(u8g2_font_helvB10_tf);
    char todayBuf[16];
    snprintf(todayBuf, sizeof(todayBuf), "%.1fh", todayHrs);
    u8g2.drawStr(8 + slideOffset, 46, todayBuf);

    u8g2.drawVLine(63 + slideOffset, 26, 22);

    u8g2.setFont(u8g2_font_5x7_tf);
    u8g2.drawStr(72 + slideOffset, 33, "ALL-TIME");

    u8g2.setFont(u8g2_font_helvB10_tf);
    char allTimeBuf[16];
    snprintf(allTimeBuf, sizeof(allTimeBuf), "%.1fh", allTimeHrs);
    u8g2.drawStr(72 + slideOffset, 46, allTimeBuf);

    u8g2.drawHLine(0, 50, 128);
    
    // Page indicator dots (○ ● ○)
    u8g2.drawCircle(6, 58, 2);
    u8g2.drawDisc(13, 58, 2);
    u8g2.drawCircle(20, 58, 2);

    char repsStr[16];
    snprintf(repsStr, sizeof(repsStr), "%02d REPS", client.tallyCount);
    u8g2.setFont(u8g2_font_5x8_tf);
    u8g2.drawStr(32, 60, repsStr);

    char streakStr[16];
    snprintf(streakStr, sizeof(streakStr), "%dd STREAK", tracker.currentStreakDays);
    u8g2.setFont(u8g2_font_5x8_tf);
    int sW = u8g2.getStrWidth(streakStr);
    u8g2.drawStr(126 - sW, 60, streakStr);

    u8g2.sendBuffer();
}

// 6. Screen 3: Tactical 50 / 10 Focus Interval & Rest Cockpit
inline void renderIntervalSessionScreen() {
    u8g2.clearBuffer();
    renderGlobalDeepWorkHeader(true);

    ClientInfo& client = tracker.getActiveClient();

    // 50 / 10 Cycle Math (1 Hour = 3600 seconds)
    // 0 - 2999 seconds (50 mins) = FOCUS
    // 3000 - 3599 seconds (10 mins) = BREAK
    unsigned long totalSecs = tracker.currentSessionSeconds;
    unsigned long cycleSecs = totalSecs % 3600;
    int cycleNum = (totalSecs / 3600) + 1;
    bool isFocus = (cycleSecs < 3000);

    unsigned long stageSecs = isFocus ? cycleSecs : (cycleSecs - 3000);
    unsigned long stageTotal = isFocus ? 3000 : 600; // 50m = 3000s, 10m = 600s
    unsigned long stageRemaining = stageTotal > stageSecs ? (stageTotal - stageSecs) : 0;

    // Subheader: Label on left, Set Badge on right
    u8g2.setFont(u8g2_font_helvB08_tf);
    if (isFocus) {
        u8g2.drawStr(2 + slideOffset, 20, "50 / 10");
    } else {
        u8g2.drawStr(2 + slideOffset, 20, "10M BREAK");
    }

    int badgeW = 42;
    int badgeX = 128 - badgeW - 2 + slideOffset;
    if (isFocus) {
        u8g2.drawRBox(badgeX, 11, badgeW, 10, 2);
        u8g2.setDrawColor(0);
        u8g2.setFont(u8g2_font_5x7_tf);
        char setBuf[12];
        snprintf(setBuf, sizeof(setBuf), "SET #%d", cycleNum);
        int setW = u8g2.getStrWidth(setBuf);
        u8g2.drawStr(badgeX + (badgeW - setW) / 2, 19, setBuf);
        u8g2.setDrawColor(1);
    } else {
        // Blinking REST badge during 10m recovery
        if ((millis() / 500) % 2 == 0) {
            u8g2.drawRBox(badgeX, 11, badgeW, 10, 2);
            u8g2.setDrawColor(0);
            u8g2.setFont(u8g2_font_5x7_tf);
            u8g2.drawStr(badgeX + 9, 19, "REST");
            u8g2.setDrawColor(1);
        } else {
            u8g2.drawRFrame(badgeX, 11, badgeW, 10, 2);
            u8g2.setFont(u8g2_font_5x7_tf);
            u8g2.drawStr(badgeX + 9, 19, "REST");
        }
    }

    // Hero Countdown Timer: Large, Centered, Crisp (MM:SS)
    u8g2.setFont(u8g2_font_logisoso18_tn);
    String remStr = formatMMSS(stageRemaining);
    int tW = u8g2.getStrWidth(remStr.c_str());
    int xCenter = (128 - tW) / 2;
    u8g2.drawStr(xCenter + slideOffset, 41, remStr.c_str());

    // Tactical 5-Segment Progress Gauge (Each segment = 10 minutes)
    if (isFocus) {
        for (int b = 0; b < 5; b++) {
            int bx = 5 + (b * 24) + slideOffset;
            int bw = 21;
            int bh = 4;
            unsigned long bStart = b * 600;
            unsigned long bEnd = (b + 1) * 600;

            if (stageSecs >= bEnd) {
                // Completed 10-minute block: solid fill
                u8g2.drawBox(bx, 44, bw, bh);
            } else if (stageSecs > bStart) {
                // Active 10-minute block: frame + proportional inner fill
                u8g2.drawFrame(bx, 44, bw, bh);
                int innerFill = ((stageSecs - bStart) * (bw - 2)) / 600;
                if (innerFill > (bw - 2)) innerFill = (bw - 2);
                if (innerFill > 0) {
                    u8g2.drawBox(bx + 1, 45, innerFill, bh - 2);
                }
            } else {
                // Future block: clean 1px outline
                u8g2.drawFrame(bx, 44, bw, bh);
            }
        }
    } else {
        // Recovery Mode: Sleek unified break progress bar
        int barX = 5 + slideOffset;
        int barW = 117;
        u8g2.drawRFrame(barX, 44, barW, 4, 1);
        int fillW = (stageSecs * (barW - 2)) / 600;
        if (fillW > (barW - 2)) fillW = (barW - 2);
        if (fillW > 0) {
            u8g2.drawBox(barX + 1, 45, fillW, 2);
        }
    }

    // Footer
    u8g2.drawHLine(0, 50, 128);

    // Left: Page indicator dots (○ ○ ●)
    u8g2.drawCircle(6, 57, 2);
    u8g2.drawCircle(13, 57, 2);
    u8g2.drawDisc(20, 57, 2);

    // Right: Reps counter
    char repsStr[16];
    snprintf(repsStr, sizeof(repsStr), "%02d REPS", client.tallyCount);
    u8g2.setFont(u8g2_font_5x8_tf);
    int rW = u8g2.getStrWidth(repsStr);
    int repsX = 126 - rW;
    u8g2.drawStr(repsX, 60, repsStr);

    // Center: Status cue ("FOCUS" / "BREAK") mathematically centered between dots and reps
    const char* cue = isFocus ? "FOCUS" : "BREAK";
    u8g2.setFont(u8g2_font_5x7_tf);
    int cueW = u8g2.getStrWidth(cue);
    int dotsEnd = 24;
    int cueX = dotsEnd + (repsX - dotsEnd - cueW) / 2;
    u8g2.drawStr(cueX, 60, cue);

    u8g2.sendBuffer();
}

inline void renderStressBusterScreen(unsigned long elapsedMs) {
    u8g2.clearBuffer();

    const unsigned long totalDuration = 120000; // 2 minutes (120,000 ms)
    const unsigned long cycleLength  = 20000;   // 20s per cycle
    const int totalCycles = 6;

    float overallProgress = constrain((float)elapsedMs / (float)totalDuration, 0.0f, 1.0f);

    unsigned long cycleElapsed = elapsedMs % cycleLength;

    // --- Physiological Respiratory Curve (6s Inhale, 4s Hold, 10s Exhale) ---
    // Orbit radius D: from tight bud (4.5px) to full lotus bloom (11.5px)
    // Petal radius R: from 2.0px (bud seed) to 4.0px (open petal)
    // Opening twist: 0.0 to 22.5 deg (PI/8)
    float D = 4.5f;
    float R = 2.0f;
    float twist = 0.0f;
    const char* phaseTitle = "INHALE";

    if (cycleElapsed < 6000) {
        float t = (float)cycleElapsed / 6000.0f;
        float ease = 0.5f - 0.5f * cos(t * 3.14159265f); // Natural harmonic ease
        D = 4.5f + ease * 7.0f;          // 4.5px to 11.5px
        R = 2.0f + ease * 2.0f;          // 2.0px to 4.0px
        twist = ease * 0.392699f;        // Gentle 22.5° aperture twist
        phaseTitle = "INHALE";
    } else if (cycleElapsed < 10000) {
        float t = (float)(cycleElapsed - 6000) / 4000.0f;
        float wave = sin(t * 3.14159265f) * 0.4f; // Serene biological micro-pulse
        D = 11.5f + wave;
        R = 4.0f;
        twist = 0.392699f;               // Fully bloomed orientation
        phaseTitle = "HOLD";
    } else {
        float t = (float)(cycleElapsed - 10000) / 10000.0f;
        float ease = 0.5f - 0.5f * cos(t * 3.14159265f); // 10s parasympathetic release
        D = 11.5f - ease * 7.0f;         // 11.5px back to 4.5px
        R = 4.0f - ease * 2.0f;          // 4.0px back to 2.0px
        twist = (1.0f - ease) * 0.392699f; // Untwist smoothly back to origin
        phaseTitle = "EXHALE";
    }

    // =========================================================================
    // LEVEL 1: SERENE PHASE TITLE (Centered at x=64, Baseline at y=11)
    // =========================================================================
    u8g2.setFont(u8g2_font_helvB08_tf);
    int pw = u8g2.getStrWidth(phaseTitle);
    u8g2.drawStr((128 - pw) / 2, 11, phaseTitle);

    // =========================================================================
    // LEVEL 2: SACRED KINETIC LOTUS (True Optical Display Center cx=64, cy=32)
    // =========================================================================
    const int cx = 64;
    const int cy = 32;

    // Central focal anchor disc (drishti)
    u8g2.drawDisc(cx, cy, 1);

    // Inner sacred concentric ring when bloomed
    if (D > 6.0f) {
        int innerR = (int)round(D * 0.45f);
        if (innerR >= 2) {
            u8g2.drawCircle(cx, cy, innerR);
        }
    }

    // 8 Kinetic Petal Spheres arranged symmetrically from 12 o'clock (-PI/2)
    const float baseAngle = -1.5707963f; // -PI/2 aligns apex petal straight up
    int rInt = (int)round(R);
    for (int i = 0; i < 8; i++) {
        float angle = baseAngle + (i * 0.7853982f) + twist; // 45° step + aperture twist
        int px = (int)round(cx + cos(angle) * D);
        int py = (int)round(cy + sin(angle) * D);
        u8g2.drawCircle(px, py, rInt);
        if (rInt >= 3) {
            u8g2.drawPixel(px, py); // Nucleus node inside each open petal
        }
    }

    // Subtle celestial cardinal pips at full bloom
    if (D > 9.5f) {
        u8g2.drawPixel(cx, cy - 17);
        u8g2.drawPixel(cx, cy + 17);
        u8g2.drawPixel(cx - 17, cy);
        u8g2.drawPixel(cx + 17, cy);
    }

    // =========================================================================
    // LEVEL 3: PRECISION PROGRESS HORIZON (84px width, lifted to y=57 for 5px bottom margin)
    // =========================================================================
    const int barX = 22;
    const int barW = 84;
    const int barY = 57;
    u8g2.drawHLine(barX, barY, barW); // Hairline track

    // 6 subtle cycle divider ticks along the track (every 14px)
    for (int c = 1; c < totalCycles; c++) {
        u8g2.drawPixel(barX + c * 14, barY - 1);
    }

    int fillW = (int)(overallProgress * (float)barW);
    if (fillW > barW) fillW = barW;
    if (fillW > 0) {
        u8g2.drawBox(barX, barY, fillW, 1);
        // Precision cursor pip at current progress front
        int cursorX = barX + fillW - 1;
        if (cursorX > barX + barW - 1) cursorX = barX + barW - 1;
        u8g2.drawVLine(cursorX, barY - 1, 3);
    }

    u8g2.sendBuffer();
}

inline void renderWellnessConfigScreen() {
    u8g2.clearBuffer();

    // Header bar
    u8g2.setFont(u8g2_font_helvB08_tf);
    u8g2.drawStr(2, 9, "WELLNESS CONFIG");
    u8g2.drawHLine(0, 11, 128);

    uint8_t field = tracker.wellnessConfigField;

    // 3 evenly spaced rows without footer clutter
    const int yBoxes[3] = {14, 31, 48};
    const int yTexts[3] = {25, 42, 59};

    for (uint8_t i = 0; i < 3; i++) {
        const char* label = "";
        char valBuf[24];
        bool isSel = (field == i);

        if (i == 0) {
            label = "STATUS";
            if (isSel) {
                snprintf(valBuf, sizeof(valBuf), tracker.wellnessEnabled ? "< ON >" : "< OFF >");
            } else {
                snprintf(valBuf, sizeof(valBuf), tracker.wellnessEnabled ? "ON" : "OFF");
            }
        } else if (i == 1) {
            label = "INTERVAL";
            if (isSel) {
                snprintf(valBuf, sizeof(valBuf), "< %d MIN >", tracker.wellnessIntervalMinutes);
            } else {
                snprintf(valBuf, sizeof(valBuf), "%d MIN", tracker.wellnessIntervalMinutes);
            }
        } else {
            label = "MODE";
            const char* mStr = (tracker.wellnessMode == 0) ? "BOTH" :
                               (tracker.wellnessMode == 1) ? "WATER" : "STRETCH";
            if (isSel) {
                snprintf(valBuf, sizeof(valBuf), "< %s >", mStr);
            } else {
                snprintf(valBuf, sizeof(valBuf), "%s", mStr);
            }
        }

        if (isSel) {
            u8g2.drawRBox(2, yBoxes[i], 124, 15, 2);
            u8g2.setDrawColor(0);
            u8g2.setFont(u8g2_font_helvB08_tf);
            u8g2.drawStr(6, yTexts[i], label);
            int vW = u8g2.getStrWidth(valBuf);
            u8g2.drawStr(122 - vW, yTexts[i], valBuf);
            u8g2.setDrawColor(1);
        } else {
            u8g2.setFont(u8g2_font_6x10_tf);
            u8g2.drawStr(6, yTexts[i], label);
            int vW = u8g2.getStrWidth(valBuf);
            u8g2.drawStr(122 - vW, yTexts[i], valBuf);
        }
    }

    u8g2.sendBuffer();
}

inline void renderWellnessAlertScreen(uint8_t kind, unsigned long elapsedMs) {
    u8g2.clearBuffer();

    // 5-second countdown progress bar at bottom
    float remain = 1.0f - constrain((float)elapsedMs / 5000.0f, 0.0f, 1.0f);
    int barW = 124;
    int fillW = (int)(remain * (float)barW);
    u8g2.drawFrame(2, 58, 124, 4);
    if (fillW > 0) {
        u8g2.drawBox(2, 59, fillW, 2);
    }

    if (kind == 0) {
        // === HYDRATION / WATER ALERT ===
        // Droplet top cone + rounded belly on Left (cx=24, cy=28)
        u8g2.drawLine(24, 13, 18, 24);
        u8g2.drawLine(24, 13, 30, 24);
        u8g2.drawCircle(24, 25, 6);
        u8g2.drawPixel(22, 23); // highlight glint

        // Concentric ripple wave animations below droplet
        float wave = (float)(elapsedMs % 1200) / 1200.0f;
        int rx1 = 4 + (int)(wave * 14.0f);
        int ry1 = 1 + (int)(wave * 4.0f);
        if (rx1 > 0 && ry1 > 0) u8g2.drawEllipse(24, 43, rx1, ry1);

        float wave2 = fmod(wave + 0.5f, 1.0f);
        int rx2 = 4 + (int)(wave2 * 14.0f);
        int ry2 = 1 + (int)(wave2 * 4.0f);
        if (rx2 > 0 && ry2 > 0) u8g2.drawEllipse(24, 43, rx2, ry2);

        // Text & cues on Right
        u8g2.setFont(u8g2_font_helvB08_tf);
        u8g2.drawStr(48, 12, "TIME TO DRINK");

        u8g2.setFont(u8g2_font_6x10_tf);
        u8g2.drawStr(48, 25, "HYDRATE!");

        u8g2.setFont(u8g2_font_5x7_tf);
        u8g2.drawStr(48, 38, "Drink 250ml water");

        u8g2.setFont(u8g2_font_4x6_tf);
        u8g2.drawStr(48, 48, "Refuel mind & focus");
    } else {
        // === STAND & STRETCH ALERT ===
        // Kinetic posture figure with upward stretch motion
        u8g2.drawDisc(24, 14, 3);          // Head
        u8g2.drawLine(24, 17, 24, 32);     // Spine
        u8g2.drawLine(24, 32, 17, 46);     // Left leg
        u8g2.drawLine(24, 32, 31, 46);     // Right leg

        // Arms reach upwards with gentle rhythmic stretch
        int armY = 10 - (int)(sin((float)elapsedMs * 0.006f) * 4.0f);
        u8g2.drawLine(24, 20, 15, armY);   // Left arm
        u8g2.drawLine(24, 20, 33, armY);   // Right arm

        // Floating upward chevrons above hands
        int arrY = 8 - (int)((elapsedMs / 80) % 7);
        u8g2.drawLine(21, arrY + 2, 24, arrY);
        u8g2.drawLine(24, arrY, 27, arrY + 2);

        // Text & cues on Right
        u8g2.setFont(u8g2_font_helvB08_tf);
        u8g2.drawStr(48, 12, "STAND & STRETCH");

        u8g2.setFont(u8g2_font_6x10_tf);
        u8g2.drawStr(48, 25, "POSTURE CUE");

        u8g2.setFont(u8g2_font_5x7_tf);
        u8g2.drawStr(48, 38, "Roll back shoulders");

        u8g2.setFont(u8g2_font_4x6_tf);
        u8g2.drawStr(48, 48, "Deep breath & reset");
    }

    u8g2.sendBuffer();
}

} // namespace OledUI
