# Background Refresh + Push Notifications

## Current state

- **Foreground timer** (`PeriodicSyncManager`): re-syncs all accounts every N minutes while the app is open. Works today, no setup needed.
- **Local notifications** (`NotificationManager`): posts a notification for new unread inbox mail and sync errors, whenever the app is running (foreground or briefly backgrounded). Works today, no setup needed beyond the user granting permission.
- **Remote push** (`PushRegistrar`, Cloud Function `onGmailPush`): wakes the app with a silent push even when it's fully closed, by relaying Gmail's own change notifications through Firebase Cloud Messaging. Code is done; **deploying it requires the manual steps below**, which need your Apple Developer, Google Cloud, and Firebase accounts.

## How the remote push pipeline works

```
Gmail mailbox changes
  -> Gmail's users.watch (called by PushRegistrar per connected account)
  -> Google Cloud Pub/Sub topic "gmail-inbox-updates"
  -> Cloud Function onGmailPush (server/functions/src/gmailPushRelay.ts)
  -> looks up this device's FCM token in Firestore (pushSubscriptions collection)
  -> sends a silent/content-available push via Firebase Cloud Messaging
  -> APNs delivers it to the device
  -> AppDelegate.didReceiveRemoteNotification -> PushRegistrar.handleRemoteNotification
  -> syncs just that one Gmail account
  -> MailSyncEngine's existing new-mail detection posts the actual local notification
```

Gmail's watch expires roughly every 7 days — `PushRegistrar.registerAllAccounts` renews it opportunistically on every periodic sync tick, so no separate schedule is needed.

## What's already done (code)

- `PushRegistrar.swift` — registers/unregisters each account's push subscription (Firestore) and Gmail watch; handles incoming silent pushes.
- `NotificationManager.swift` — also now the `UNUserNotificationCenterDelegate`, and requests remote-notification registration once local permission is granted.
- `AppDelegate.swift` — bridges APNs device-token callbacks and silent-push delivery into the app (SwiftUI's `App` protocol doesn't expose these directly).
- `MailAppApp.swift` — uses a single shared `ModelContainer` so the AppDelegate can reach SwiftData outside the view hierarchy.
- `GmailAPIClient.watchMailbox` / `.stopWatchingMailbox` — the Gmail API calls that start/stop push notifications for a mailbox.
- `AccountsManager` — registers push on connecting an account, unregisters (and stops the Gmail watch) on removal.
- `PeriodicSyncManager` — renews watches/subscriptions on every tick.
- `MailApp-Info.plist` — `UIBackgroundModes: [remote-notification]`, so iOS actually wakes the app for a silent push.
- `server/functions/src/gmailPushRelay.ts` — the Cloud Function, now sending real FCM pushes (previously just a stub).
- `server/firestore.rules` + `server/firebase.json` — security rules (new — none existed before) scoping `userConfigs` and `pushSubscriptions` to their owning user, and Functions deploy config.
- `scripts/setup_gmail_push.sh` — creates the Pub/Sub topic and grants Gmail's push service account publish rights.
- FirebaseMessaging added as a package dependency (same `firebase-ios-sdk` package already in the project).

## What you still need to do

1. **Xcode: add the Push Notifications capability.** Signing & Capabilities → your paid team already selected (Phase 6) → **+ Capability → Push Notifications**. This is the one piece that genuinely can't be done outside Xcode — it needs your App ID configured for push on the Developer Portal, which Xcode does automatically once you add the capability with a paid team selected.

2. **Upgrade Firebase to the Blaze (pay-as-you-go) plan.** Firebase Console → your project → gear icon → Usage and billing → Modify plan. Cloud Functions and Pub/Sub aren't available on the free Spark plan. Cost is usually small for an app at this scale, but it's real — your call on timing.

3. **Generate an APNs authentication key** so Firebase can actually deliver to Apple devices: Apple Developer → Certificates, IDs & Profiles → Keys → **+** → check "Apple Push Notifications service (APNs)" → download the `.p8` file (you only get one download, save it somewhere safe). Then Firebase Console → Project Settings → Cloud Messaging → Apple app configuration → upload that `.p8`, along with the Key ID and your Team ID.

4. **Create the Pub/Sub topic + grant Gmail permission:**
   ```
   cd ~/Workplace/mail-app
   ./scripts/setup_gmail_push.sh YOUR_GCP_PROJECT_ID
   ```
   If your project ID isn't `mail-app-1`, also update the `gmailWatchTopic` constant near the top of `MailApp/Features/MailEngine/PushRegistrar.swift` to match.

5. **Deploy the Firestore rules and Cloud Function:**
   ```
   cd server
   firebase deploy --only firestore:rules,functions
   ```
   (First time: `cd server/functions && npm install`, and make sure `firebase use YOUR_PROJECT_ID` points at the right project.)

6. **Test end-to-end:** build to a real device (push doesn't work in Simulator), connect a Gmail account, force-quit the app, then send that account a test email from another address. It should arrive as a notification within a few seconds to a minute.

## Notes

- If steps 2–5 aren't done yet, nothing breaks — `PushRegistrar` fails silently (best-effort) and the app falls back to local notifications while running plus the periodic timer, same as today.
- Multiple devices per account, and multiple accounts per device, both work — subscriptions are keyed per (Gmail address, device) pair.
