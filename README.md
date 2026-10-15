# AleTemizCache

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
- Accepts your own definitions in `~/Library/Application Support/AleTemizCache/targets.json` (Settings › Custom Locations).

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
./scripts/build-app.sh            # dist/AleTemizCache.app for your Mac
./scripts/build-app.sh universal  # arm64 + x86_64
./scripts/make-dmg.sh             # dist/AleTemizCache-<version>.dmg
open dist/AleTemizCache.app
```

GitHub Actions builds the DMG on every push to `main` (download it from the run's Artifacts). Pushing a tag such as `v2.1.0` also attaches the DMG to a GitHub Release.

The CI build uses an ad-hoc signature. On first launch macOS will refuse to open it; right-click the app and choose Open, or run `xattr -dr com.apple.quarantine /Applications/AleTemizCache.app`.

For development: `swift run AleTemizCache`, or `open Package.swift` in Xcode.

Run tests: `swift test`

To distribute to other Macs without a Gatekeeper warning, sign with a Developer ID and notarize:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/build-app.sh universal
ditto -c -k --keepParent dist/AleTemizCache.app dist/AleTemizCache.zip
xcrun notarytool submit dist/AleTemizCache.zip --keychain-profile <profile> --wait
xcrun stapler staple dist/AleTemizCache.app
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
Sources/AleTemizCache/    SwiftUI app: model, Finder bridge, views, branding
Tests/                    Unit tests for path rules, scanning, cleaning, Trash and history
Resources/                Info.plist, app icon
scripts/build-app.sh      Assembles and signs AleTemizCache.app
scripts/make-dmg.sh       Packages the app into a DMG
scripts/make-icon.swift   Renders the Ale logo app icon
.github/workflows/        CI: test, build universal app, package DMG
```

## Permissions

- Automation (Finder): asked the first time you empty the Trash.
- Full Disk Access (optional): lets AleTemizCache measure the Trash. Without it, emptying still works and Finder can count the items.

## Credits

- Brand: AleTemizCache (logo: Ale)
- Developed by: Mehmet Akif Cifci
- Developer identity: TheManOfTalent

---

## ☕ Sponsor or Buy Me a Coffee

If you find this project helpful, consider supporting it or reaching out for collaboration:

[![Buy Me A Coffee](https://img.shields.io/badge/BUY%20ME%20A%20COFFEE-SUPPORT%20PROJECT-green?style=for-the-badge&logo=buymeacoffee)](https://buymeacoffee.com/themanoftalent) [![GitHub Sponsors](https://img.shields.io/badge/SPONSOR-GITHUB%20SPONSORS-ea4aaa?style=for-the-badge&logo=githubsponsors)](https://github.com/sponsors/themanoftalent) [![Let's Connect](https://img.shields.io/badge/LET%27S%20CONNECT-EMAIL-blue?style=for-the-badge&logo=gmail)](mailto:cs.akifcifci@gmail.com)

---

## License

MIT License. Copyright (c) 2026 Mehmet Akif Cifci (TheManOfTalent). See [LICENSE](LICENSE).
