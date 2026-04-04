#!/bin/bash
# Creates a styled DMG with icon layout and an installer app.
# Usage: scripts/create-dmg.sh <app-bundle> <version> <output-dmg>

set -e

APP_BUNDLE="$1"
VERSION="$2"
OUTPUT_DMG="$3"
VOL_NAME="Parrot $VERSION"
STAGING="$(dirname "$OUTPUT_DMG")/dmg-staging"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_BUNDLE" "$STAGING/"

# Add README
cp "$SCRIPT_DIR/README.txt" "$STAGING/README.txt"

# Create a read-write DMG so we can set Finder view options
TEMP_DMG="$(dirname "$OUTPUT_DMG")/temp.dmg"
rm -f "$TEMP_DMG"
hdiutil create -volname "$VOL_NAME" \
    -srcfolder "$STAGING" \
    -ov -format UDRW \
    "$TEMP_DMG"

# Mount and configure Finder window
MOUNT_DIR=$(hdiutil attach -readwrite -noverify "$TEMP_DMG" | grep '/Volumes/' | sed 's/.*\/Volumes/\/Volumes/')
ACTUAL_VOL_NAME=$(basename "$MOUNT_DIR")

# Set the volume icon
cp "$APP_BUNDLE/Contents/Resources/AppIcon.icns" "$MOUNT_DIR/.VolumeIcon.icns"
SetFile -a C "$MOUNT_DIR" 2>/dev/null || true

# Add Applications alias for drag-to-install (Finder alias preserves folder icon)
osascript -e 'tell application "Finder" to make alias file to POSIX file "/Applications" at POSIX file "'"$MOUNT_DIR"'"'
sleep 2

# Kill any cached .DS_Store
rm -f "$MOUNT_DIR/.DS_Store"

# Set window view and icon positions via AppleScript
/usr/bin/osascript <<EOF
tell application "Finder"
    tell disk "$ACTUAL_VOL_NAME"
        open
        delay 1
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {200, 200, 680, 440}
        set theViewOptions to icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 80
        delay 1
        -- position items: README (left), Parrot (center), Applications (right)
        repeat with f in (get every item of container window)
            set n to name of f
            if n is "README.txt" then
                set position of f to {120, 120}
            else if n starts with "Parrot" then
                set position of f to {260, 120}
            else if n is "Applications" then
                set position of f to {400, 120}
            end if
        end repeat
        close
        delay 1
        open
        delay 1
        close
    end tell
end tell
EOF

# Let Finder write the .DS_Store
sync
sleep 2

# Unmount
hdiutil detach "$MOUNT_DIR" -quiet

# Convert to compressed read-only
rm -f "$OUTPUT_DMG"
hdiutil convert "$TEMP_DMG" -format UDZO -o "$OUTPUT_DMG"

# Cleanup
rm -f "$TEMP_DMG"
rm -rf "$STAGING"

echo "DMG created: $OUTPUT_DMG"
