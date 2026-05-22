# Flickwall

[![CI](https://github.com/tamo2918/Flickwall/actions/workflows/ci.yml/badge.svg)](https://github.com/tamo2918/Flickwall/actions/workflows/ci.yml)

English | [日本語](README.ja.md)

Flickwall is a native macOS wallpaper switcher built around a Command-Tab-style overlay.
Register image files or folders, open the switcher with a global shortcut, move through
wallpaper previews, and apply the selected wallpaper without opening System Settings.

## Features

- Global wallpaper switcher shortcut, defaulting to `Option + Command + W`
- Customizable shortcut recorder in Settings
- Horizontal wallpaper preview overlay with keyboard navigation
- Menu bar status item for opening the library, switcher, and import actions
- Image file and folder import
- Favorites and recent wallpapers
- Sandboxed file access using security-scoped bookmarks
- Asynchronous thumbnail generation with in-memory caching
- Same-wallpaper application across all connected displays

## Requirements

- macOS 26.2 or later
- Xcode 26.2 or later

The project currently targets the macOS 26.2 SDK because it uses modern macOS SwiftUI
APIs, including Liquid Glass effects.

## Build From Source

Clone the repository and run:

```bash
./script/build_and_run.sh --verify
```

You can also open `Flickwall.xcodeproj` in Xcode and run the `Flickwall` scheme.

For local development, Xcode can sign the app for running on your machine. For public
binary distribution outside the Mac App Store, use your own Apple Developer Program
account, Developer ID signing, and notarization.

## Tests

```bash
xcodebuild test \
  -project Flickwall.xcodeproj \
  -scheme Flickwall \
  -configuration Debug \
  -derivedDataPath build/DerivedData \
  -only-testing:FlickwallTests
```

## How File Access Works

Flickwall does not copy your wallpaper image files into the app. It stores metadata and
security-scoped bookmarks so the sandboxed app can access the files you explicitly chose.

Stored data includes:

- display name
- original file path
- security-scoped bookmark data
- favorite state
- added date
- last applied date

Library metadata is stored at:

```text
~/Library/Application Support/Flickwall/wallpapers.json
```

Thumbnails are generated from the original files and cached in memory only.

## Privacy

Flickwall is a local-only app. It does not include analytics, telemetry, tracking,
advertising, account login, or network features. The app reads only image files and
folders that the user selects through the macOS file picker.

## Known Limitations

- The selected wallpaper is applied to all connected displays.
- If the original image file is deleted, moved, or renamed, Flickwall may no longer be
  able to resolve that wallpaper.
- Prebuilt notarized binaries are not published yet; build from source for now.

## Development Notes

- Main app source lives in `Flickwall/`.
- Unit tests live in `FlickwallTests/`.
- UI tests live in `FlickwallUITests/`.
- `script/build_and_run.sh` is the canonical local build/run entrypoint.

## License

Flickwall is released under the MIT License. See [LICENSE](LICENSE).
