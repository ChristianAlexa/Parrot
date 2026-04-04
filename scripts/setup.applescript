-- Parrot Installer
-- Double-click to install Parrot to /Applications.

set dmgPath to (path to me as text)
set dmgFolder to (POSIX path of (text 1 thru -2 of (dmgPath & ":")))
-- Go up from Setup.app to the DMG root
set dmgRoot to do shell script "dirname " & quoted form of dmgFolder
set appSource to dmgRoot & "/Parrot.app"

-- Verify Parrot.app exists next to us
try
    do shell script "test -d " & quoted form of appSource
on error
    display alert "Parrot.app not found" message "Could not find Parrot.app in this disk image." as critical
    return
end try

-- Check if already installed
set alreadyInstalled to false
try
    do shell script "test -d /Applications/Parrot.app"
    set alreadyInstalled to true
end try

if alreadyInstalled then
    set userChoice to display dialog "Parrot is already installed. Replace it with this version?" buttons {"Cancel", "Replace"} default button "Replace" with icon caution
    if button returned of userChoice is "Cancel" then return
    do shell script "rm -rf /Applications/Parrot.app"
end if

-- Copy to /Applications and remove quarantine
do shell script "cp -R " & quoted form of appSource & " /Applications/"
try
    do shell script "xattr -dr com.apple.quarantine /Applications/Parrot.app"
on error
    display dialog "Parrot was installed, but quarantine removal failed. Open Terminal and run:" & return & return & "xattr -dr com.apple.quarantine /Applications/Parrot.app" buttons {"OK"} default button "OK" with icon caution
    return
end try

display dialog "Parrot has been installed! You can eject this disk image now." buttons {"OK"} default button "OK" with icon note
