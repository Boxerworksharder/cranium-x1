#include "power_manager.h"

bool PowerManager::keepAliveEnabled = true;
unsigned long PowerManager::lastPulseMillis = 0;
bool PowerManager::isPulsing = false;
unsigned long PowerManager::pulseStartMillis = 0;
WiFiUDP PowerManager::keepAliveUdp;
