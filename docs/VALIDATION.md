# Validation and outstanding acceptance

## Executed in Codex Cloud

- TypeScript compilation passed using Node 22.
- Five backend domain tests passed (food/role allowlists, pending-gift transitions,
  preference validation, cross-midnight quiet hours/time zones and safe IDs).
- All eleven Swift files passed tree-sitter syntax parsing (not type checking).
- Plists, entitlements, privacy manifest, scheme XML and CI YAML parsed.
- Project regeneration was verified deterministic.
- Generated Xcode project parsed with the `xcode` OpenStep parser: app, widget and
  test targets, embedded extension, Firebase package products, shared scheme.
- All six supplied body PNGs were decoded and verified as transparent RGBA,
  and their installed bytes were compared with the original ZIP.
- The three supplied photographs were prepared as transparent head cutouts,
  visually inspected and integrated: FED smiling, HUNGRY unimpressed, TIRED glasses.
- All nine PNGs pass the required release asset check. Head files decode as
  matching 1254×1254 transparent RGBA images. Original body bytes still match the ZIP.
- Low-energy source captions are excluded by display viewports without rewriting
  the PNGs; native visual acceptance with photographic heads remains pending.

Firebase emulator startup was attempted. The Firestore emulator JAR download
from `storage.googleapis.com` was denied by the current network allowlist (403).
That domain addition was saved in the environment draft. Rules and callable
integration tests have **not run** here. After saving the network change, run:

```sh
cd backend
npx firebase-tools@14.27.0 emulators:exec --project demo-feed-connor \
  --only auth,firestore,functions \
  'npm --prefix functions run test:rules && cd functions && node --test test/callables.integration.js'
```

Rules tests exercise partner reads, outsider denial, role forgery, forbidden
client mutations and secret/token isolation. Callable tests create real emulated
Auth identities and exercise pairing, one-use codes, authorization, send retries,
consume retries, virtual/real meal separation and idempotent real meal logging.
No production project or credential is needed. Use the demo project name.

## macOS checks not executed in Linux

Run Codemagic `ios-validation` before accepting the native build. It builds both
native targets and executes six XCTest cases for elapsed thresholds, missing meals,
GIFT pose preservation, virtual-food separation, schedule grace and persistence.
SwiftUI/WidgetKit compilation, Simulator rendering and XCTest require macOS.
Xcode previews live in Widget/ConnorWidget.swift and App/Views.swift; rendering
those previews has not occurred here. Source previews are not acceptance screenshots.

## Physical two-device acceptance before sharing a build

1. With original art supplied, inspect FED/HUNGRY/TIRED/GIFT at small and medium
   widget sizes and the parent dashboard. Confirm exact white/black palette,
   centered unmodified photos, consistent neck alignment, no clipping/overlap,
   regular monospaced text, and exactly one word in each default widget.
2. Create a private pair, join from the second device, and confirm the two roles
   cannot be exchanged or a third person added. Reuse/expire a pairing code.
3. Send each of four foods as Lydia (wait 30 seconds between sends). Confirm
   Connor receives a push and Lydia sees pending. Tap Later and confirm pending
   survives app relaunch. Tap Eat and confirm animation/happy head and consumed
   status on both phones, plus acceptance push to Lydia.
4. Verify consuming a gift leaves last confirmed meal and meal history unchanged.
   Confirm a real meal as Connor and see the server time on Lydia's dashboard.
5. Change meal schedule and thresholds. Check hunger after the schedule grace and
   elapsed thresholds. Set a near-future meal reminder, allow notifications, then
   test quiet-hour suppression and notification denial without excessive prompts.
6. Sync, background the app, send a gift and verify widget update when iOS grants
   background execution. Test foreground, background, offline/reconnect and app
   relaunch. Do not promise immediate widget updates after force-quit.
7. Link/recover both accounts; test account deletion on a disposable pair. Confirm
   the remaining partner becomes unpaired and shared history/cache disappears.
8. Complete a signed archive, TestFlight processing, beta review if external,
   and fresh installation from TestFlight. Check production APNs on real devices.

A signed build, successful cloud sync, APNs delivery, original-asset design
acceptance and private TestFlight installation remain unverified until these
service prerequisites and physical-device checks are completed.

## Native screenshot automation

A fourth Xcode target, FeedConnorUITests, and the Codemagic `screenshots` workflow
now capture the five state/dashboard screens plus Eat/Later using Debug sample
data in the actual app views. This workflow and these UI tests have not run in
Linux. See SCREENSHOTS.md for execution and artifact retrieval. No screenshots
have been produced or native compilation claimed by this setup.

## First Codemagic screenshot run

The supplied artifact bundle contained no screenshots or completed tests. Its
Xcode result reported a build failure in Widget/ConnorWidget.swift:
`OpenURLIntent` requires iOS 18, while the deployment target is iOS 17.
The App Intent and its widget button are now gated to iOS 18+. On iOS 17 the
existing widgetURL opens the same native gift screen. The fix passed local
Swift syntax checks; a new macOS screenshot build is still required to verify it.

## Firebase simulator architecture failure

The next supplied Codemagic log showed Firebase products linking for arm64,
while the app's Swift driver failed for x86_64 with missing FirebaseAuth,
FirebaseFirestore and FirebaseFunctions module dependencies. Both M2 simulator
workflows now explicitly select arm64 and pass ARCHS=arm64 plus ONLY_ACTIVE_ARCH=YES
to every target, including packages. Generated Debug configurations also build
only the active architecture. Release configurations retain normal multi-architecture
settings. Full build logs are exported; pipefail preserves xcodebuild failures.
Structural checks passed locally; the corrected native build still needs to run
in Codemagic before screenshot capture can be confirmed.
