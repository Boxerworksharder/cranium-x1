#!/usr/bin/env bash
# TITIKSHA X1 · One-Click Firmware Flasher (v1.0.0)
set -e

PORT="${1:-/dev/ttyACM0}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "======================================================="
echo "   TITIKSHA X1 · Flashing Production Firmware v1.0.0   "
echo "   Target Port: $PORT                                  "
echo "======================================================="

esptool.py --chip esp32c3 --port "$PORT" --baud 921600 \
    --before default_reset --after hard_reset write_flash \
    -z --flash_mode dio --flash_freq 80m --flash_size 4MB \
    0x0 "$SCRIPT_DIR/bootloader.bin" \
    0x8000 "$SCRIPT_DIR/partitions.bin" \
    0x10000 "$SCRIPT_DIR/titiksha_x1_v1.0.0.bin"

echo "✅ Flashing complete! Rebooting TITIKSHA X1..."
