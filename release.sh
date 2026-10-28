#!/bin/bash
# Crea l'app universale, i pacchetti .zip e .dmg e (con --publish) la release su GitHub.
# Uso: ./release.sh 1.1.0 [--publish]
# La versione va aggiornata anche in Resources/Info.plist (CFBundleShortVersionString).
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:?Uso: ./release.sh <versione> [--publish]}"
PLIST_VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)"
if [ "$VERSION" != "$PLIST_VERSION" ]; then
  echo "Info.plist dice $PLIST_VERSION, non $VERSION: aggiorna CFBundleShortVersionString." >&2
  exit 1
fi

./test.sh > /dev/null
./build-app.sh --universal

APP="build/Canali WiFi.app"
ZIP="build/Canali-WiFi.zip"
DMG="build/Canali-WiFi.dmg"
rm -f "$ZIP" "$DMG"

ditto -c -k --keepParent "$APP" "$ZIP"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -quiet -volname "Canali WiFi" -srcfolder "$STAGE" -ov -format UDZO "$DMG"

echo "Pacchetti pronti: $ZIP, $DMG"

if [[ " $* " == *" --publish "* ]]; then
  gh release create "v$VERSION" "$ZIP" "$DMG" --title "Canali Wi‑Fi $VERSION" --notes-file - <<EOF
**Installazione rapida** (Terminale):

\`\`\`bash
curl -fsSL https://raw.githubusercontent.com/mattiafrac/wifi-canali/main/install.sh | bash
\`\`\`

Oppure scarica **Canali-WiFi.dmg** e trascina l'app in Applicazioni. Dato che l'app non è notarizzata da Apple,
la prima volta macOS la blocca: apri Impostazioni di Sistema → Privacy e sicurezza → **Apri comunque**.

Funziona su macOS 14 o successivo, sia Apple Silicon sia Intel.
EOF
fi
