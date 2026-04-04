#!/bin/bash
# Parrot — first-time setup
# Removes the macOS quarantine flag and launches Parrot.

APP="/Applications/Parrot.app"

echo ""
echo "  Parrot Setup"
echo "  ============"
echo ""

if [ ! -d "$APP" ]; then
    echo "  Parrot.app not found in /Applications."
    echo "  Drag it there first, then run this again."
    echo ""
    read -n 1 -s -r -p "  Press any key to close..."
    exit 1
fi

echo "  Removing quarantine flag..."
xattr -cr "$APP"

echo "  Launching Parrot..."
open "$APP"

echo ""
echo "  Done! You can close this window."
echo ""
