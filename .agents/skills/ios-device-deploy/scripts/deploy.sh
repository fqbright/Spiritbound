#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$DIR"

echo "=== Checking Physical iOS Devices ==="
DEVICE_LINE=$(xcrun devicectl list devices 2>/dev/null | grep -E "iPhone|iPad" | head -n 1 || true)

if [ -z "$DEVICE_LINE" ]; then
  echo "⚠️  No iOS device found in devicectl."
  echo "Please connect your iPhone via USB or ensure it is paired over Wi-Fi."
  exit 1
fi

echo "$DEVICE_LINE"
DEVICE_ID=$(echo "$DEVICE_LINE" | awk '{print $3}')
DEVICE_STATE=$(echo "$DEVICE_LINE" | awk '{print $4}')

if [ "$DEVICE_STATE" != "connected" ]; then
  echo "⚠️  Device state is '$DEVICE_STATE' (not 'connected')."
  echo "1. Unlock your iPhone screen."
  echo "2. Tap 'Trust This Computer' if prompted."
  echo "3. Ensure Developer Mode is enabled under Settings > Privacy & Security."
  exit 1
fi

echo "=== Exporting and Building Spiritbound iOS Project ==="
./deploy_ios.sh

echo "=== Launching on Device ($DEVICE_ID) ==="
xcrun devicectl device process launch --device "$DEVICE_ID" com.jiacong.spiritbound

echo "=== Spiritbound successfully launched! ==="
