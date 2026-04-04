Parrot - Local Speech-to-Text

QUICK INSTALL
  Double-click "Setup" to install Parrot to your Applications folder.
  That's it!

MANUAL INSTALL
  1. Drag Parrot.app to /Applications (or wherever you like).
  2. Open Terminal and run:
       xattr -dr com.apple.quarantine /Applications/Parrot.app
     This removes the macOS quarantine flag since Parrot is not notarized.
  3. Launch Parrot from your Applications folder.

UNINSTALL
  Delete Parrot.app from /Applications.
  Parrot stores its data in ~/Library/Application Support/Parrot/ —
  delete that folder to remove all models and settings.
