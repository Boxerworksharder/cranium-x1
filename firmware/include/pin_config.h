#pragma once

// =========================================================================
// Hardware Pinout Configuration
// =========================================================================

#if defined(CONFIG_IDF_TARGET_ESP32C3)
  // --- ESP32-C3 SuperMini / Mini ---
  #define PIN_OLED_SDA      4
  #define PIN_OLED_SCL      5
  #define PIN_ENCODER_CLK   0
  #define PIN_ENCODER_DT    1
  #define PIN_ENCODER_SW    2     // Rotary Encoder Knob Button (Start / Pause / Stop)
  #define PIN_TALLY_BUTTON  21    // Dedicated Tally Counter Button on Pin 21 (Click = +1, Hold = -1)
  #define PIN_SESSIONS_BUTTON 20  // Dedicated Quick-Glance Sessions Button on Pin 20 (Click = View Logs, Hold = View Summary)
  #define PIN_BOARD_LED     8
  #define PIN_LED_RED       6     // External SMD RED LED: Focus / Deep Work "On Air"
  #define PIN_LED_BLUE      10    // External SMD BLUE LED: Bluetooth Link / Break / Tally Flash
  #define PIN_LED_FOCUS     PIN_LED_RED
  #define PIN_LED_STATUS    PIN_LED_BLUE
  #define PIN_HAPTIC_MOTOR  8     // Haptic Vibration Motor Driver (GPIO 8 via NPN Transistor)

#elif defined(CONFIG_IDF_TARGET_ESP32S3)
  // --- ESP32-S3 ---
  #define PIN_OLED_SDA      4
  #define PIN_OLED_SCL      5
  #define PIN_ENCODER_CLK   12
  #define PIN_ENCODER_DT    13
  #define PIN_ENCODER_SW    14
  #define PIN_TALLY_BUTTON  15
  #define PIN_BOARD_LED     21

#else
  // --- Standard ESP32 WROOM DevKit ---
  #define PIN_OLED_SDA      21
  #define PIN_OLED_SCL      22
  #define PIN_ENCODER_CLK   18
  #define PIN_ENCODER_DT    19
  #define PIN_ENCODER_SW    23
  #define PIN_TALLY_BUTTON  15
  #define PIN_BOARD_LED     2
#endif
