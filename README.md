# TemizCache

A native macOS app that shows how much space developer, browser and app caches take, cleans the ones you pick, and empties the Trash.

Developed by Mehmet Akif Cifci | TheManOfTalent

## Features

- Dashboard with reclaimable space, disk usage, Trash size and lifetime space freed.
- Sidebar navigation by category, search across all locations, sort by size or name.
- Trash section: measures the Trash (with Full Disk Access) and empties it through Finder, always after confirmation.
- Cleaning history, toasts with undo-friendly guidance, keyboard shortcuts (⌘R rescan, ⌘⌫ clean, ⇧⌘⌫ empty Trash, ⌘1-3 navigation).
- Measures 24 built-in cache locations in parallel: Xcode, simulators, Swift PM, Homebrew, CocoaPods, Carthage, npm, Yarn, pnpm, pip, Gradle, Go, Cargo, JetBrains, VS Code, Chrome, Firefox, Edge, Brave, Spotify, Slack, crash reports and logs.
- Moves contents to the Trash by default. Settings can switch to permanent deletion.
- Empties folders instead of removing them, so apps that expect the folder keep working.
- Shows each location in Finder.
- Remembers which items you unchecked.
- Accepts your own definitions in `~/Library/Application Support/TemizCache/targets.json` (Settings › Custom Locations).

## Safety rules

Every path, built-in or custom, passes `PathPolicy` before the app measures or touches it:

- It must sit strictly below `~/Library/Caches`, `~/Library/Logs`, `~/Library/Developer`, `~/Library/Application Support`, `~/.npm`, `~/.gradle`, `~/.cargo` or `~/.cache`.
- Under `~/Library/Application Support` it must be at least two levels deep (`Slack/Cache` passes, `Google` alone fails).
- Paths with `..` are refused.
- A cache folder that is itself a symbolic link is skipped. Links inside a cache folder are removed as links; their targets stay.
- Browser entries cover only cache folders. Profile folders that hold bookmarks, passwords and history are never listed.

## Build

Requirements: macOS 14 or later, Xcode 15 or later (or the Swift 5.9+ toolchain).

```bash
./scripts/build-app.sh            # dist/TemizCache.app for your Mac
./scripts/build-app.sh universal  # arm64 + x86_64
./scripts/make-dmg.sh             # dist/TemizCache-<version>.dmg
open dist/TemizCache.app
```

GitHub Actions builds the DMG on every push to `main` (download it from the run's Artifacts). Pushing a tag such as `v2.0.0` also attaches the DMG to a GitHub Release.

The CI build uses an ad-hoc signature. On first launch macOS will refuse to open it; right-click the app and choose Open, or run `xattr -dr com.apple.quarantine /Applications/TemizCache.app`.

For development: `swift run TemizCache`, or `open Package.swift` in Xcode.

Run tests: `swift test`

To distribute to other Macs without a Gatekeeper warning, sign with a Developer ID and notarize:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/build-app.sh universal
ditto -c -k --keepParent dist/TemizCache.app dist/TemizCache.zip
xcrun notarytool submit dist/TemizCache.zip --keychain-profile <profile> --wait
xcrun stapler staple dist/TemizCache.app
```

## Custom definitions

```json
[
  {
    "id": "figma",
    "title": "Figma",
    "summary": "Font and file cache.",
    "kind": "app",
    "paths": ["~/Library/Application Support/Figma/DesktopProfile/Cache"],
    "caution": "Quit Figma first."
  }
]
```

`kind` is one of `developer`, `packageManager`, `browser`, `app`, `logs`, `custom`. An entry with the same `id` as a built-in replaces it. Invalid paths are skipped and listed under Settings › Custom Locations.

## Project layout

```
Sources/TemizCacheCore/   Catalog, PathPolicy, SizeScanner, Cleaner, TrashInspector, DiskSpace, CleanHistory (Foundation only, testable)
Sources/TemizCache/       SwiftUI app: model, Finder bridge, views, branding
Tests/                    Unit tests for path rules, scanning, cleaning, Trash and history
Resources/                Info.plist, app icon
scripts/build-app.sh      Assembles and signs TemizCache.app
scripts/make-dmg.sh       Packages the app into a DMG
scripts/make-icon.swift   Renders the app icon
.github/workflows/        CI: test, build universal app, package DMG
```

## Permissions

- Automation (Finder): asked the first time you empty the Trash.
- Full Disk Access (optional): lets TemizCache measure the Trash. Without it, emptying still works and Finder can count the items.

## Credits

- Developed by: Mehmet Akif Cifci
- Developer identity: TheManOfTalent
- Brand: TheManOfTalent

## License

MIT License. Copyright (c) 2026 Mehmet Akif Cifci (TheManOfTalent). See [LICENSE](LICENSE).
