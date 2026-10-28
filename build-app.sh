#!/bin/bash
# Compila e crea "build/Canali WiFi.app". Uso: ./build-app.sh [--install]
#   --install  copia l'app in ~/Applications
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/WiFiCanali"

[ -f Resources/AppIcon.icns ] || swift Resources/make-icon.swift

APP="build/Canali WiFi.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/WiFiCanali"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Firma ad-hoc: basta per usarla su questo Mac.
codesign --force --sign - "$APP"
echo "Creata: $PWD/$APP"

if [ "${1:-}" = "--install" ]; then
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/Canali WiFi.app"
  cp -R "$APP" "$HOME/Applications/"
  echo "Installata in ~/Applications/Canali WiFi.app"
fi
