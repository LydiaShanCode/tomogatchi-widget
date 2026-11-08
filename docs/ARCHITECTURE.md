# Architecture and behavior

## Shared state and visual contract

`Shared/Models.swift` is Foundation-only and compiled into the app, extension and
unit tests. `Shared/CharacterView.swift` composes separate original head and body
PNG views without changing image data. The six supplied body files have different
canvas dimensions; layout.json records each source size and neck anchor. A common
pixel scale keeps body proportions stable. The low-energy viewports exclude the
source sheet captions below the complete body. The shared on-screen neck anchor
is fixed; all three photographic head cutouts are present. Inspect native
previews before accepting photo alignment. The revised expression mapping is
FED = smiling, HUNGRY = unimpressed without glasses, TIRED = glasses.

The app advances body frames every 0.35 seconds with TimelineView. WidgetKit uses
frame 1 and 15-minute static entries over six hours; iOS decides refresh timing.
The character is horizontally centered in a reserved illustration area, with the
word beneath it. The optional food sits beside the character. No photo is cropped.
Small and medium default widgets display one word only: FED, HUNGRY, TIRED, GIFT.
A pending gift takes precedence over the label but preserves the current pose.
Tapping GIFT opens Eat/Later in the app through an App Intent and deep link.
Lydia sees the same pet widget if she installs it; there is no verbose parent
widget layout.

All backgrounds use white, including the WidgetKit container background. Text
uses regular black Arial Mono when available, otherwise regular system monospaced.
The supplied app icon is an original monochrome typographic icon, not a Connor asset.
Native system sheets and notification presentation are ultimately controlled by iOS.

## Hunger and real meals

No confirmed meal starts HUNGRY, without inventing a meal event. A confirmed real
meal sets the server timestamp. Default elapsed thresholds are 4 hours for HUNGRY
and 7 hours for TIRED. Tired takes precedence. A scheduled meal overdue by at least
30 minutes also produces HUNGRY if no meal has been confirmed after that schedule.
Connor can change thresholds, four meal schedules and quiet hours. Lunch defaults
to 12:30 PM. Quiet hours suppress reminders, not hunger. At most four repeating
local reminders are registered; there is no repeated overdue nagging.

Consuming a virtual gift sets `virtualFedUntil` for 30 minutes. It changes the head
and pose immediately after the successful server mutation, with a brief in-app
animation, and notifies Lydia. It does not change `lastMealAt` or create a meal.
Later only dismisses the native interaction screen. The gift remains pending.

## Backend contract

Collections:
- `users/{uid}`: immutable, server-created pair membership and role.
- `pairs/{id}`: parentID, childID, preferences, lastMealAt, virtualFedUntil, counters.
- `pairs/{id}/gifts/{requestID}`: food, pending/consumed, server timestamps, sender.
- `pairs/{id}/meals/{requestID}`: actual meal kind, server timestamp, confirmer.
- `invites/{sha256(code)}`: 48-bit random code digest, vacant role, 15-minute expiry.
- `joinAttempts/{uid}`: ten join attempts per 15 minutes per authenticated account.
- `devices/{uid}`: one active FCM token per account, server-only.

Anonymous Firebase Auth starts each device. Users can link email/password without
changing UID, then recover through the pairing screen after reinstalling. Enable
both providers. Link before reinstalling. Roles are assigned once during pairing;
clients cannot write profiles, pair documents, gifts, meals, invites or tokens.
Every callable checks authentication and pair membership, and role where needed.
Only parent sends, only child consumes/logs meals/changes schedules. Exactly four
food values are accepted. Callable request IDs make successful retries idempotent.
UI controls serialize actions; 30-second send throttling and 20 pending gifts bound
notification spam. Pairing transactions prevent double claims and reused codes.
An account can only belong to one pair.

Deleting an account removes both profiles, shared pair history, invitations and
push tokens, then deletes the caller's Auth user. The partner's Auth login survives
but becomes unpaired. Both devices clear cached widget state when their profile
is removed. The deletion confirmation explains the shared-data impact.

Deploy the rules before using the client. The Admin SDK used by Cloud Functions
bypasses rules intentionally; authorization is implemented in each callable.
The project does not expose a client-write fallback.

## Push and widget refresh limits

Firestore listeners update the foreground app, which writes a Codable snapshot
into its signed App Group and calls WidgetCenter.reloadAllTimelines(). FCM gift
and consumption events include an APNs background flag. When iOS grants background
execution, the app fetches the current pair/gifts and updates the widget cache.
Alerts are omitted during Connor's configured quiet hours; state still synchronizes.
The same quiet-hour window is applied to Lydia's acceptance push.

Push delivery and WidgetKit refresh are not guaranteed instantaneous. Force-quitting
the app can suppress background execution. Opening the app restores synchronization.
Firestore event handlers can be delivered more than once; APNs collapse identifiers
bound queued duplicate alerts, but do not guarantee exactly-once notifications.
There is no continuously animated Home Screen widget or arbitrary background polling.
Use two physical iPhones for the notification acceptance test.
