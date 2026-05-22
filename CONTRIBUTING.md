# Contributing

Thanks for helping improve Flickwall.

## Development Setup

1. Install Xcode 26.2 or later.
2. Clone the repository.
3. Run `./script/build_and_run.sh --verify`.
4. Open `Flickwall.xcodeproj` if you prefer working in Xcode.

## Before Opening a Pull Request

Run:

```bash
xcodebuild test \
  -project Flickwall.xcodeproj \
  -scheme Flickwall \
  -configuration Debug \
  -derivedDataPath build/DerivedData \
  -only-testing:FlickwallTests
```

Also verify the app starts:

```bash
./script/build_and_run.sh --verify
```

## Code Style

- Prefer small, focused SwiftUI views and AppKit bridge types.
- Keep user-facing behavior native to macOS.
- Keep file access sandbox-safe.
- Do not add analytics, tracking, or network behavior without a clear project discussion.
- Do not commit generated build products, personal Xcode user data, or local signing files.

## Pull Request Guidelines

- Explain the user-visible change.
- Include screenshots or recordings for visible UI changes when practical.
- Mention any macOS permission, sandbox, or signing impact.
- Keep unrelated refactors out of feature or bug-fix pull requests.
