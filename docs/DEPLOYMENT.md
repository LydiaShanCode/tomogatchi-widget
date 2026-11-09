# Cloud build and private TestFlight deployment

No local Mac is required. Codex edits the repository on Linux; Codemagic supplies
macOS/Xcode, signing, Simulator and the App Store Connect upload. An account owner
must perform the service setup below. Do not paste credentials into chat or Git.

## 1. Supply the original art

Three five-frame body sprite sheets and three photographic head cutouts are integrated in
`Resources/Character/`. The revised expression mapping is smiling = FED,
unimpressed = HUNGRY, glasses = TIRED, as listed in the folder's README.
Do not generate replacements or alter faces. Run:

```sh
python3 scripts/validate_assets.py --require-assets
```

The validator prints dimensions and SHA256 hashes without rewriting files. Release
CI requires all six PNGs; five-frame atlas dimensions and neck anchors are
checked against animations.json rather than resizing images. Head canvas sizes must be consistent. Review all
four widget previews at small/medium sizes and Lydia's dashboard on macOS. If the
photo/body neck alignment needs tuning, change only layout constants, not PNG data.
Keep original files intact; obtain permission to distribute the photographs.

## 2. Apple Developer and App Store Connect

1. Enroll in the paid Apple Developer Program. Record the Team ID.
2. Choose your own unique app bundle ID (for example `com.yourteam.feedconnor`).
   Register that app ID with Push Notifications and App Groups enabled.
3. Register the extension ID `<app bundle ID>.widget`. Enable App Groups.
4. Register `group.<app bundle ID>.shared`, assign it to BOTH identifiers, and
   regenerate provisioning profiles after enabling capabilities.
5. Create the iOS app record in App Store Connect using the app bundle ID.
6. Create an App Store Connect API key with the permissions Codemagic requires
   to manage signing and upload builds (typically App Manager). Retain its issuer
   ID, key ID, and private .p8 securely. Add it to Codemagic's Apple integrations
   under the exact name **Feed Connor ASC**. Do not commit the key.
7. Add distribution signing credentials in Codemagic and enable automatic signing
   for BOTH app and extension. The `ios_signing` wildcard matching behavior should
   fetch the extension profile too; confirm both profiles appear in build logs.
   If your Codemagic account requires explicit profile references, set those in
   its UI for the two IDs before building. Profiles must share the App Group.

The project defaults to `com.feedconnor.app` for unsigned validation only. Production
CI writes ignored `Config/Local.xcconfig` with your IDs, team and production APNs.
For interactive Xcode use, create the same local file with `APS_ENVIRONMENT =
development`. The checked-in Base.xcconfig provides documented defaults.

## 3. Firebase

1. Create a Firebase project; enable the Blaze plan for deployed Cloud Functions
   and Eventarc. Choose Firestore Native mode and suitable region (functions use
   `us-central1`). Check billing limits for a small private app.
2. In Authentication enable **Anonymous** and **Email/Password** providers.
   Configure email templates, password policy and authorized domains in console.
3. Create a Firebase iOS app whose bundle ID matches your production app ID.
   Download `GoogleService-Info.plist`; place it in `Resources/Firebase/` locally
   (Git ignores it). Never place a service-account private key in the iOS app.
4. In Firebase Cloud Messaging upload an Apple APNs authentication key, with its
   Key ID and Apple Team ID. Enable Push Notifications on the app identifier.
5. On a trusted CLI session, authenticate to Firebase, then deploy:

```sh
cd backend/functions
npm ci
npm test
cd ..
npx firebase-tools@14.27.0 login
npx firebase-tools@14.27.0 deploy --project YOUR_FIREBASE_PROJECT_ID --only firestore,functions
```

Use Node 22 and Java 21. `GoogleService-Info.plist` identifies the project; the
client calls its deployed functions in `us-central1`. Ensure all callable functions
and both Firestore triggers deploy successfully. No privileged admin credentials
are needed by the app. A CI service account, if used, belongs in the CI secret
store with least privilege, never in this repository.

Use Firebase App Check as a further production abuse control after registering
App Attest and testing physical devices. It is not enforced in this initial
implementation; authorization and pairing still run on every request. Do not
switch `enforceAppCheck` on without adding the iOS App Check provider first.
For old invite cleanup, configure Firestore TTL for `invites.expiresAt`; expiration
is enforced by code even before TTL deletes the documents.

## 4. Codemagic

1. Connect this GitHub repository to Codemagic and use `codemagic.yaml`.
2. The root configuration contains **ios-validation** and **screenshots** only,
   so configuration discovery works without any signing integrations or secrets.
   Run **screenshots** for app captures or **ios-validation** first. It resolves Firebase iOS SDK 11.15.0, builds the
   app and extension, and runs state/animation XCTest cases on an available iPhone
   Simulator. Missing Firebase config intentionally shows setup instructions;
   missing heads show a dashed outline above the supplied bodies. No signing is needed for this workflow.
3. Create the `feed_connor` environment-variable group with:

| Variable | Value | Secret? |
| --- | --- | --- |
| `APP_BUNDLE_ID` | Your registered app ID | No |
| `APPLE_TEAM_ID` | Your Apple Developer Team ID | No |
| `FIREBASE_IOS_PLIST_BASE64` | Base64 of your downloaded Firebase plist | Yes |

Use Codemagic's secure variable UI. The plist is decoded only during the build;
it must match APP_BUNDLE_ID. The App Store Connect .p8 stays in the integration.
Do not add these credentials as proxy-backed chat secrets: Codemagic needs them
in its own build machine, and signing keys are files, not HTTP request tokens.

4. After the `feed_connor` variable group and **Feed Connor ASC** integration
   are configured, copy the `testflight` entry from `docs/testflight.codemagic.yaml`
   into the root `codemagic.yaml` under its existing `workflows` key. Preserve
   the other workflows; do not introduce a second `workflows` key. Commit/push
   the change, then check the configuration in Codemagic again. The template
   intentionally uses `$APP_BUNDLE_ID` from the now-configured variable group.
   In App Store Connect create a TestFlight tester group named **Lydia and Connor**.
5. Run **testflight** after all character assets and Firebase config are present.
   It checks assets/config, selects provisioning profiles, assigns BUILD_NUMBER,
   archives both targets, exports an IPA and uploads it. Make sure BUILD_NUMBER
   exceeds any already uploaded version. Adjust it in Codemagic if needed.
6. Inspect signing logs for the extension, shared App Group and production APNs.
   Resolve any App Store validation errors before inviting testers. The workflows
   select Codemagic’s latest stable Xcode so uploads use a current SDK. Confirm
   Apple’s current minimum SDK requirement in App Store Connect and run
   ios-validation on that same Xcode before release.

A configured YAML is not an executed build. No TestFlight upload has occurred in
Codex Cloud. Publishing the Codex environment does not publish an iOS app.

## 5. TestFlight review and installation

Internal testers need App Store Connect access with an eligible role. If Lydia
and Connor are external testers, submit the first build for Beta App Review.
Complete beta description, contact/review information, privacy policy URL,
export-compliance questions and any requested demo/reviewer access. Give reviewers
fresh paired test accounts or a documented test flow; do not send them the private
pairing code used by Lydia and Connor. Builds expire after 90 days.

Disclose collection of user identifiers, optional email, push tokens and meal
history. The privacy manifest declares meal history as health data for review;
verify the App Privacy questionnaire against actual service configuration and
Firebase SDK disclosures. No tracking or analytics SDK is included. Account
removal is available in Settings and removes shared pair history. Use a real
privacy policy describing retention and shared-data deletion.

Install TestFlight on both iPhones, accept their private invitations and install
the app. Lydia selects Parent and creates the pair; Connor enters the code and
receives Child. Keep the code private. Enable notifications on both devices.
Link each account to email/password in Settings before reinstalling the app.

To install the widget: touch and hold the Home Screen, tap Edit / Add Widget,
search FEED CONNOR, select small or medium and add it. Open the app once to sync
and populate the App Group. Both devices can install the widget. On Connor's
phone, tap GIFT to open Eat/Later. Follow the two-device checklist in VALIDATION.md.
