#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

DEVICE_ID="2D2E4073-03E1-4EA2-A59A-848677D572EA"
BUNDLE_ID="org.56f2af7217aed177.Telegram"
DERIVED_DATA_PATH="$PWD/.derived-data/Telegram-iPhone17"

xcrun simctl boot "$DEVICE_ID" >/dev/null 2>&1 || true
open -a Simulator --args -CurrentDeviceUDID "$DEVICE_ID"

xcodebuild \
  -project Telegram/Telegram.xcodeproj \
  -scheme Telegram \
  -configuration Debug \
  -destination "id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

APP_PATH="$(find "$DERIVED_DATA_PATH/Build/Products" -path "*/Debug-iphonesimulator/*/Telegram.app" -type d | head -n 1)"

if [[ -z "$APP_PATH" ]]; then
  echo "Telegram.app was not found under $DERIVED_DATA_PATH/Build/Products" >&2
  exit 1
fi

xcrun simctl install "$DEVICE_ID" "$APP_PATH"
xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID"
