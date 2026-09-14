#pragma once
#include <Arduino.h>
#include "pin_config.h"

// =========================================================================
// Haptic Vibration Motor Controller
// Non-blocking, millisecond-accurate pulse & burst pattern scheduler.
// =========================================================================

class HapticManager {
public:
    static void init() {
        pinMode(PIN_HAPTIC_MOTOR, OUTPUT);
        digitalWrite(PIN_HAPTIC_MOTOR, LOW);
    }

    struct State {
        unsigned long offTime;
        int burstCount;
        unsigned long nextBurstTime;
        int burstDuration;
        int burstGap;
    };

    static State& getState() {
        static State s = {0, 0, 0, 0, 0};
        return s;
    }

    // Direct single pulse (Hardware-protected duration: 5ms to 400ms)
    static void trigger(int durationMs = 35) {
        durationMs = constrain(durationMs, 5, 400);
        digitalWrite(PIN_HAPTIC_MOTOR, HIGH);
        getState().offTime = millis() + durationMs;
    }

    // Multi-pulse burst pattern
    static void triggerPattern(int pulses, int onMs = 60, int gapMs = 80) {
        if (pulses <= 0) return;
        pulses = constrain(pulses, 1, 6); // Safety cap on max pulses
        onMs = constrain(onMs, 5, 400);
        gapMs = constrain(gapMs, 20, 1000);
        trigger(onMs);
        State& s = getState();
        s.burstCount = pulses - 1;
        s.burstDuration = onMs;
        s.burstGap = gapMs;
        s.nextBurstTime = millis() + onMs + gapMs;
    }

    // Emergency Failsafe Killswitch
    static void emergencyStop() {
        digitalWrite(PIN_HAPTIC_MOTOR, LOW);
        State& s = getState();
        s.offTime = 0;
        s.burstCount = 0;
    }

    // ---------------------------------------------------------------------
    // Semantic Tactile Event Profiles
    // ---------------------------------------------------------------------
    static void pulseTap() { trigger(25); }                       // Subtle 25ms micro-tap (UI clicks / knob select)
    static void pulseTally() { trigger(40); }                     // Crisp 40ms mechanical pop (Tally +1 rep)
    static void pulseTallyMinus() { triggerPattern(2, 25, 35); }  // Quick double-tap (Tally -1 rep)
    static void pulseStart() { triggerPattern(2, 60, 60); }       // Dual energizing buzz (Focus session start)
    static void pulsePause() { trigger(30); }                     // Single descending tap (Focus paused)
    static void pulseResume() { triggerPattern(2, 30, 40); }      // Quick double tap (Focus resumed)
    static void pulseStop() { triggerPattern(2, 90, 70); }        // Firm confirmation buzz (Session saved to flash)
    static void pulseBreakAlert() { triggerPattern(3, 150, 100); }// 3 rhythmic alert pulses (50m Focus done, take 10m break!)
    static void pulseFocusAlert() { triggerPattern(2, 120, 80); } // 2 solid pulses (10m Break done, back to Deep Work!)
    static void pulseGoalAchieved() { triggerPattern(4, 90, 70); }// 4-pulse celebration fanfare (10 Hours Daily Goal Reached!)
    static void pulseBoot() { triggerPattern(2, 80, 80); }        // 2-pulse handshake on system boot
    static void pulseStressBusterInhale() { trigger(25); }        // Gentle rising breath pulse
    static void pulseStressBusterExhale() { trigger(20); }        // Soft releasing exhale pulse
    static void pulseStressBusterComplete() { triggerPattern(3, 40, 50); } // Harmonic 3-tap tranquility chime
    static void pulseWellness() { triggerPattern(3, 45, 60); }    // 3 gentle tactile reminder pulses (Drink Water / Stand & Stretch)

    // Non-blocking loop update (Call every loop tick) with Hardware Safety Watchdog
    static void update() {
        unsigned long now = millis();
        State& s = getState();

        // Turn off when pulse finishes or on safety timeout
        if (s.offTime > 0 && (now >= s.offTime || (now + 5000 < s.offTime))) {
            digitalWrite(PIN_HAPTIC_MOTOR, LOW);
            s.offTime = 0;
        }

        // Schedule next burst
        if (s.burstCount > 0 && now >= s.nextBurstTime) {
            trigger(s.burstDuration);
            s.burstCount--;
            s.nextBurstTime = now + s.burstDuration + s.burstGap;
        }
    }
};
