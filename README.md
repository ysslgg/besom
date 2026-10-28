<div align="center">

**English · [Français](README.fr.md)**

<img src="Resources/AppIcon-1024.png" width="128" alt="Besom icon">

# Besom

**Sweep your Mac clean.**

Temp files, caches, logs, orphaned app data, old installers, the Trash: Besom finds what can go, shows you exactly what it is, and removes it in one click.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-444?logo=apple&logoColor=white)
![Apple Silicon and Intel](https://img.shields.io/badge/Apple%20Silicon%20%2B%20Intel-444)
![Swift](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white)

</div>

## Features

### 🧹 What it finds

| Family | What | Removal |
|---|---|---|
| **App caches** | `~/Library/Caches` (Apple's and running apps' are left alone) | Deleted |
| **Logs & crash reports** | `~/Library/Logs`, diagnostic reports | Deleted |
| **Temporary files** | your temp folder, untouched for 3+ days | Deleted |
| **Developer leftovers** | Xcode DerivedData and DeviceSupport, simulator caches, npm cache | Deleted |
| **Orphaned app data** | support files, preferences, saved state and launch agents left behind by uninstalled apps | **Trash** |
| **Old installers** | DMG / PKG / ISO in Downloads (14+ days), unfinished downloads | **Trash** |
| **Old device backups** | iPhone and iPad backups | **Trash** |
| **Trash** | everything in the Trash | Emptied for good |

### 🛡️ Built to be safe
- **Nothing is removed without your confirmation.** The dialog says how much is deleted for good and how much goes to the Trash.
- **Only regenerable data is ticked by default** (caches, logs, temp, developer caches). Orphans, installers, backups and the Trash are always your call.
- **Anything that isn't regenerable goes through the Trash first**, so you can still get it back.
- **Every item is inspectable**: untick it, or reveal it in Finder, before cleaning.
- **A guard re-checks each path right before removal.** It must sit strictly inside the allowed folders of its family. Symbolic links are resolved, so a link can't lead outside.
- **Orphan detection is conservative.** Anything modified in the last 30 days, Apple's own data, and anything matching an installed app, a running app, a Homebrew tool or a system binary is left alone.
- **Dry run from the terminal**: `Besom --scan` prints what would be cleaned and exits, deleting nothing.

### And also
- **Native and light**: SwiftUI, a sidebar of families with their sizes, a detail list per family, live scanning.
- **Automatic scan** at launch and every few hours while the app stays open.
- **English or French**: follows the system language, switchable in Settings (⌘,).
- **Launch at login** and haptic feedback, both optional.

## Installation

There is no download yet: build it from source.

```bash
git clone https://github.com/ysslgg/besom.git
cd besom
./build.sh                # dist/Besom.app  (UNIVERSAL=1 for arm64 + x86_64)
open dist/Besom.app
```

macOS 14 or later and the Xcode command line tools are required. The app is signed ad hoc, so on first launch macOS may ask you to open it from **System Settings → Privacy & Security → Open Anyway**.

### Full Disk Access

macOS keeps the Trash and device backups private. To see them, allow Besom in **System Settings → Privacy & Security → Full Disk Access**. The app tells you when a family needs it and opens the right pane for you. Everything else works without it.

## Limitations

- Only the current user's data is scanned: nothing in `/Library` or `/System`.
- Orphan detection is a heuristic. It is why those items are never ticked by default and always go through the Trash.
- Items in use by a running app can fail to delete; Besom reports how many were skipped.
- The Trash on external volumes is not scanned.
- Personal use only, see the [license](LICENSE).
