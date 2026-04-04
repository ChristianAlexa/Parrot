Parrot - Local Speech-to-Text

INSTALL
  1. Drag Parrot.app to the Applications folder.
  2. Open Parrot — macOS will block it since it's not notarized.
  3. Open System Settings → Privacy & Security, scroll down,
     and click "Open Anyway" next to the Parrot message.

  Alternative: run this in Terminal before launching:
    xattr -cr /Applications/Parrot.app

UNINSTALL
  Delete Parrot.app from /Applications.
  Parrot stores its data in ~/Library/Application Support/Parrot/ —
  delete that folder to remove all models and settings.
