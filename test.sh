#!/bin/bash
# I Command Line Tools (senza Xcode) richiedono questi percorsi per swift-testing.
set -euo pipefail
cd "$(dirname "$0")"
FW=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
LIB=/Library/Developer/CommandLineTools/Library/Developer/usr/lib
swift test -Xswiftc -F -Xswiftc "$FW" -Xlinker -F -Xlinker "$FW" -Xlinker -rpath -Xlinker "$FW" -Xlinker -rpath -Xlinker "$LIB" "$@"
