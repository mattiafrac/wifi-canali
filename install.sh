#!/bin/bash
# Installa l'ultima versione di Canali Wi‑Fi:
#   curl -fsSL https://raw.githubusercontent.com/mattiafrac/wifi-canali/main/install.sh | bash
# Cartella diversa: INSTALL_DIR=~/Applications bash install.sh
set -euo pipefail

REPO="mattiafrac/wifi-canali"
APP_NAME="Canali WiFi.app"
URL="https://github.com/$REPO/releases/latest/download/Canali-WiFi.zip"

if [ "$(uname)" != "Darwin" ]; then
  echo "Canali Wi‑Fi funziona solo su macOS." >&2
  exit 1
fi
MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
if [ "$MAJOR" -lt 14 ]; then
  echo "Serve macOS 14 (Sonoma) o successivo: qui c'è $(sw_vers -productVersion)." >&2
  exit 1
fi

if [ -n "${INSTALL_DIR:-}" ]; then
  DEST="$INSTALL_DIR"
elif [ -w /Applications ]; then
  DEST="/Applications"
else
  DEST="$HOME/Applications"
fi
mkdir -p "$DEST"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Scarico Canali Wi‑Fi…"
curl -fsSL "$URL" -o "$TMP/app.zip"
ditto -x -k "$TMP/app.zip" "$TMP"

# Se l'app è aperta, la chiudiamo prima di sostituirla.
pkill -f "$APP_NAME/Contents/MacOS/WiFiCanali" 2>/dev/null || true
rm -rf "$DEST/$APP_NAME"
ditto "$TMP/$APP_NAME" "$DEST/$APP_NAME"
# L'app non è notarizzata da Apple: togliamo l'attributo di quarantena, se presente,
# così macOS non la blocca all'apertura.
xattr -dr com.apple.quarantine "$DEST/$APP_NAME" 2>/dev/null || true

echo "Installata in $DEST/$APP_NAME"
open "$DEST/$APP_NAME"
