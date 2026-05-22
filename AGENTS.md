# AGENTS.md

This file gives AI coding agents project-specific context for working on Flickwall.
It applies to the entire repository.

このファイルは、AI コーディングエージェントが Flickwall を安全に開発するための
プロジェクト固有の指示です。リポジトリ全体に適用されます。

## Project Snapshot / プロジェクト概要

Flickwall is a native macOS wallpaper switcher built with SwiftUI and small AppKit
bridges. It imports image files or folders chosen by the user, stores metadata and
security-scoped bookmarks, then applies selected wallpapers through macOS APIs.

Flickwall は SwiftUI と最小限の AppKit ブリッジで作られたネイティブ macOS
壁紙切り替えアプリです。ユーザーが選択した画像ファイルやフォルダを読み込み、
メタデータとセキュリティスコープ付きブックマークを保存し、選択した壁紙を
macOS API 経由で適用します。

## Repository Layout / 構成

- `Flickwall/`: main app source
- `Flickwall/Models/`: value types such as shortcuts and wallpaper items
- `Flickwall/Services/`: file import, hot key, window, status bar, thumbnail, and wallpaper services
- `Flickwall/Stores/`: persistence and observable state
- `Flickwall/Views/`: SwiftUI views
- `FlickwallTests/`: unit tests
- `FlickwallUITests/`: UI tests
- `script/build_and_run.sh`: canonical local build/run entrypoint

## Development Rules / 開発ルール

- Keep the app native to macOS. Prefer SwiftUI first, with narrow AppKit bridges only
  where macOS window, status item, hot key, or wallpaper APIs require them.
- Keep file access sandbox-safe. Do not replace security-scoped bookmarks with raw path
  access for persisted user files.
- Do not copy imported wallpaper image files into the app. Flickwall should reference
  the user-selected files and store only metadata/bookmarks.
- Do not add analytics, telemetry, tracking, advertising, account login, or network
  behavior without an explicit project decision.
- Preserve the menu bar/status item behavior when changing window lifecycle code.
- Keep public documentation bilingual when changing README, contribution, security,
  code of conduct, changelog, or GitHub templates.
- Use public macOS APIs only. Do not use private APIs for wallpaper, Liquid Glass,
  window, or shortcut behavior.

## Local-Only Files / ローカル専用ファイル

- `Flickwall/docs/idea.md` is intentionally local-only and ignored by git.
- Do not commit `Flickwall/docs/`, Xcode user data, `build/`, `DerivedData/`, or `dist/`.
- The Xcode project excludes `Flickwall/docs/idea.md` from the app target so it is not
  copied into Release bundles. Preserve that exclusion.

## Build And Test / ビルドとテスト

Use Xcode 26.2 or later and macOS 26.2 SDK.

```bash
./script/build_and_run.sh --verify
```

```bash
xcodebuild test \
  -project Flickwall.xcodeproj \
  -scheme Flickwall \
  -configuration Debug \
  -derivedDataPath build/DerivedData \
  -only-testing:FlickwallTests
```

For Release artifact checks:

```bash
xcodebuild clean build \
  -project Flickwall.xcodeproj \
  -scheme Flickwall \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath build/ReleaseDerivedData \
  CODE_SIGNING_ALLOWED=NO
```

## Release Notes / リリース注意点

- GitHub Release artifacts are built locally from the Release configuration.
- Current public binaries are ad-hoc signed and not Developer ID signed or notarized.
  macOS may show a first-launch warning.
- A fully smooth public install requires Developer ID signing and notarization.
- Keep generated `.dmg` and checksum files under `dist/`; that directory is ignored and
  should not be committed.

## Review Checklist / 確認チェックリスト

- User-facing behavior still matches native macOS expectations.
- Importing files and folders remains sandbox-safe.
- Wallpaper metadata still lives under Application Support JSON.
- Shortcuts remain customizable and do not introduce obvious default conflicts.
- README/README.ja stay aligned when public behavior changes.
- CI build and tests pass before publishing changes.
