# Capture native app screenshots

This repository's Codex environment is Linux. It cannot run SwiftUI, Xcode or
iOS Simulator; no native screenshots have been captured here.

In Codemagic, select this repository/branch and run the **screenshots** workflow
from `codemagic.yaml`. No Apple signing, TestFlight or Firebase credentials are
needed. The root configuration excludes the unconfigured TestFlight workflow;
its release template is in `docs/testflight.codemagic.yaml`. The runner needs access to this repository and its included PNG assets.

The workflow builds the actual app on an iPhone Simulator and runs five XCUITest
app cases plus eight widget-preview cases, capturing fourteen screens:

- Connor: FED, HUNGRY, TIRED and GIFT
- Connor: native Eat / Later interaction
- Lydia: dashboard, last meal, food selector and gift status
- Widget layouts: FED, HUNGRY, TIRED and GIFT at both small and medium sizes

Both simulator workflows select arm64 explicitly on the M2 runner and build only
the active architecture, keeping the app and Firebase package modules aligned.
The build log is retained as `screenshots-build.log`, including on build failures.

Download `FEED-CONNOR-native-screenshots.zip` from the build artifacts. The result
bundle and exported attachments are also retained. Tests must find the expected
state label and controls before recording each screen; a launch/loading screen
cannot count as a successful capture.

Screenshots use sample data in the real app views, via Debug-only launch
arguments. They demonstrate the native visual layout; they do not verify Firebase,
APNs, real gift delivery or TestFlight installation. Release builds ignore the
fixture arguments. Widget captures show the native in-app preview gallery using
the exact shared layout from the extension. They are labeled previews, not
screenshots of widgets installed on the Home Screen.

In the app, tap **Widgets** at the top left to browse the two sizes and four
states. If Firebase is not configured, tap **Widget previews** on the setup
screen. Small and medium are the two installable options; mood states change
automatically. To install a widget, hold the Home Screen, choose Edit / Add
Widget, search FEED CONNOR, then select a size.

To run on an available Apple Silicon macOS machine manually:

```sh
xcodebuild test -project FeedConnor.xcodeproj -scheme FeedConnor \
  -configuration Debug -only-testing:FeedConnorUITests \
  -destination 'platform=iOS Simulator,name=YOUR_AVAILABLE_IPHONE,arch=arm64' \
  -parallel-testing-enabled NO -resultBundlePath build/Screenshots.xcresult \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO
xcrun xcresulttool export attachments --path build/Screenshots.xcresult \
  --output-path build/screenshots
```
