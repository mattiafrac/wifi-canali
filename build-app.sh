#!/bin/bash
# Compila e crea "build/Canali WiFi.app". Uso: ./build-app.sh [--universal] [--install]
#   --universal  binario per Apple Silicon e Intel (per le release)
#   --install    copia l'app in ~/Applications
set -euo pipefail
cd "$(dirname "$0")"

if [[ " $* " == *" --universal "* ]]; then
  swift build -c release --triple arm64-apple-macosx14.0
  swift build -c release --triple x86_64-apple-macosx14.0
  BIN=.build/WiFiCanali-universal
  lipo -create -output "$BIN" \
    .build/arm64-apple-macosx/release/WiFiCanali \
    .build/x86_64-apple-macosx/release/WiFiCanali
else
  swift build -c release
  BIN="$(swift build -c release --show-bin-path)/WiFiCanali"
fi

[ -f Resources/AppIcon.icns ] || swift Resources/make-icon.swift

APP="build/Canali WiFi.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/WiFiCanali"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Firma ad-hoc: basta per usarla su questo Mac (e su altri, se scaricata con install.sh).
codesign --force --sign - "$APP"
echo "Creata: $PWD/$APP"

if [[ " $* " == *" --install "* ]]; then
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/Canali WiFi.app"
  cp -R "$APP" "$HOME/Applications/"
  echo "Installata in ~/Applications/Canali WiFi.app"
fi
