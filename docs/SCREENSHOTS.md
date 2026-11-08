# Capture native app screenshots

This repository's Codex environment is Linux. It cannot run SwiftUI, Xcode or
iOS Simulator; no native screenshots have been captured here.

In Codemagic, select this repository/branch and run the **screenshots** workflow
from `codemagic.yaml`. No Apple signing, TestFlight or Firebase credentials are
needed. The root configuration excludes the unconfigured TestFlight workflow;
its release template is in `docs/testflight.codemagic.yaml`. The runner needs access to this repository and its included PNG assets.

The workflow builds the actual app on an iPhone Simulator and runs five XCUITest
cases, capturing six screens:

- Connor: FED, HUNGRY, TIRED and GIFT
- Connor: native Eat / Later interaction
- Lydia: dashboard, last meal, food selector and gift status

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
fixture arguments. This workflow does not capture Home Screen widgets.

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
