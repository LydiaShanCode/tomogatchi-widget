# FEED CONNOR

A native iOS 17+ SwiftUI app and WidgetKit extension for Lydia and Connor.
White backgrounds, regular black monospaced text, original photographic heads,
and two-frame pixel bodies. No web wrapper.

## What is implemented

- Private, expiring, one-use pairing codes and permanent parent/child roles.
- Lydia's food picker (apple, bread, steak, bok choy), Send, and gift status history.
- Connor's Eat/Later flow. Eating sets a 30-minute happy pose; it never logs a meal.
- Timestamped real meal confirmations, schedule-aware hunger, configurable daily
  reminders, quiet hours, meal history, account linking/recovery and deletion.
- Firestore live sync, FCM gift/acceptance pushes, background refresh, App Group
  widget snapshots, static WidgetKit timelines, and an App Intent gift button.
- App, widget, unit-test and UI-test Xcode targets; widget previews in both sizes
  and an in-app Widgets gallery covering all four states.
- Firebase callable functions, deny-by-default rules, backend tests, Codemagic
  simulator validation and screenshot workflows, plus a signed TestFlight template
  enabled after account configuration.

## Current delivery limits

The initial repository contained only `read.me`. **All nine character assets are now integrated.** The six body PNGs remain
byte-for-byte as supplied. The three uploaded photographs have transparent head
cutouts: smiling for FED, unimpressed for HUNGRY, and glasses for TIRED, per the
user's revised mapping. The complete release asset check passes. Per-frame body
anchors handle different canvas sizes; viewports hide stray sheet captions.
Final photo-to-body alignment still needs native preview/device acceptance.

Firebase, Apple Developer, App Store Connect, and Codemagic must be configured by
the account owner. No credentials are committed. No signed app has been produced
or uploaded. Linux cannot compile SwiftUI/WidgetKit or run iOS Simulator.
For native screenshot capture on Codemagic, see [screenshots](docs/SCREENSHOTS.md).

See [deployment](docs/DEPLOYMENT.md), [architecture](docs/ARCHITECTURE.md), and
[validation](docs/VALIDATION.md) for exact setup and checks.

## Develop in Codex Cloud

Use this existing checkout; tasks already have isolated environments, so do not
create a worktree unless requested. The Xcode project is checked in and can also
be regenerated using `python3 scripts/generate_project.py` without XcodeGen.

```sh
cd backend/functions
npm ci
npm test
cd ../..
python3 scripts/validate_assets.py
```

Use Node 22 for Firebase Functions and Java 21 for the emulator. Once the cloud
tooling and emulator network access are set up, run `scripts/check_backend.sh`
for unit, rules and callable lifecycle checks. Backend CI runs
rules and callable lifecycle tests with emulators; macOS Codemagic runs native
builds and XCTest. See deployment instructions to enable both workflows.

Arial Mono Regular is used only when installed. The app does not bundle a
proprietary font; the normal iOS fallback is regular system monospaced.
